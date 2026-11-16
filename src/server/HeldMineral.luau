-- El mineral que el jugador lleva en la mano. Al elegir un espacio de la barra (1 a 5) el
-- personaje sostiene ese mineral (una Tool con una gema); desde ahí se deja en un estante.
-- El servidor decide qué se sostiene; el cliente solo pide elegir y recibe qué quedó.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local Props = require(script.Parent.Props)

local HeldMineral = {}

local held = {} -- player -> { Slot, MineralId, Tool }
local selectedRemote

local function destroyHeld(player)
	local info = held[player]
	if info then
		held[player] = nil
		info.Tool:Destroy()
	end
end

-- Suelta lo que lleva en la mano (si llevaba algo) y avisa al cliente.
function HeldMineral.Clear(player)
	if held[player] then
		destroyHeld(player)
		if player.Parent then
			selectedRemote:FireClient(player, 0)
		end
	end
end

-- slot = espacio de la barra (1 a Config.HotbarSize); 0 = no llevar nada.
function HeldMineral.Set(player, slot)
	destroyHeld(player)

	local data = Economy.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local valid = data
		and humanoid
		and humanoid.Health > 0
		and type(slot) == "number"
		and slot % 1 == 0
		and slot >= 1
		and slot <= Config.HotbarSize
		and slot <= #data.Inventory
	if not valid then
		selectedRemote:FireClient(player, 0)
		return
	end

	local mineralId = data.Inventory[slot]
	local tool = Props.MineralTool(mineralId)
	tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	humanoid:EquipTool(tool)
	held[player] = { Slot = slot, MineralId = mineralId, Tool = tool }
	selectedRemote:FireClient(player, slot)
end

-- Se llama cada vez que cambian los datos: si el mineral de la mano ya no está en ese
-- espacio (se dejó, se vendió...), se suelta.
function HeldMineral.Refresh(player, data)
	local info = held[player]
	if info and (not data or data.Inventory[info.Slot] ~= info.MineralId) then
		HeldMineral.Clear(player)
	end
end

function HeldMineral.Init(remotes)
	selectedRemote = remotes.Selected
	remotes.SelectSlot.OnServerEvent:Connect(function(player, slot)
		HeldMineral.Set(player, slot)
	end)
	Players.PlayerRemoving:Connect(function(player)
		destroyHeld(player)
	end)
end

return HeldMineral
