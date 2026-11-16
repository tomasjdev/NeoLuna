-- Asigna una base a cada jugador (hasta Config.MaxPlayers), la libera al salir y mantiene
-- su cartel, sus pisos y sus estantes al día. En el juego publicado se reparte en orden
-- (1, 2, 3...). En Studio, para probar, el primer jugador recibe Config.DevPreferredBase.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Bases = {}

local list = {} -- { Spawn, Label, Center, Index, Plate, Stands, Floors, Terminal } por cada base
local owners = {} -- índice de base -> player
local assigned = {} -- player -> índice de base

local LOCKED_PEDESTAL = Color3.fromRGB(110, 114, 126)
local LOCKED_TOP = Color3.fromRGB(80, 84, 96)
local OPEN_PEDESTAL = Color3.fromRGB(205, 208, 216)

local function defaultFloorStands()
	local floors = {}
	for floor = 1, Config.MaxFloors do
		floors[floor] = if floor == 1 then Config.StandsOpenPerFloor else 0
	end
	return floors
end

-- Pone la base como la ve su dueño: pisos comprados, estantes (ocultos, bloqueados o
-- abiertos) y terminal. `stands` = data.Stands (mineral por estante).
local function refresh(base, floorStands, stands)
	local floorsOwned = Config.CountFloors(floorStands)
	base.FloorsOwned = floorsOwned
	-- El cartel va sobre el último piso comprado.
	local labelPosition = base.LabelAnchor.Position
	base.LabelAnchor.Position = Vector3.new(labelPosition.X, 40 + (math.max(floorsOwned, 1) - 1) * Config.FloorHeight, labelPosition.Z)

	for floorIndex, floor in base.Floors do
		local visible = floorIndex == 1 or (floorStands[floorIndex] or 0) > 0
		for _, entry in floor.Parts do
			entry.Part.Transparency = if visible then entry.Transparency else 1
			entry.Part.CanCollide = visible and entry.CanCollide
		end
	end

	for _, stand in base.Stands do
		local unlockedCount = floorStands[stand.Floor] or 0
		local owned = unlockedCount > 0
		local unlocked = Config.IsStandUnlocked(floorStands, stand.Index)
		local locked = owned and not unlocked
		local isNext = locked and stand.Slot == unlockedCount + 1

		stand.Pedestal.Transparency = if owned then 0 else 1
		stand.Pedestal.CanCollide = owned
		stand.Pedestal.Color = if locked then LOCKED_PEDESTAL else OPEN_PEDESTAL
		stand.Top.Transparency = if owned then 0 else 1
		stand.Top.Color = if locked then LOCKED_TOP else stand.Accent
		stand.Pad.Transparency = if unlocked then 0 else 1
		stand.Pad.CanTouch = unlocked
		stand.PadGui.Enabled = unlocked
		stand.Pedestal:SetAttribute("Locked", not unlocked)

		stand.SignGui.Enabled = locked
		stand.UnlockPrompt.Enabled = isNext
		if isNext then
			local cost = Config.FormatMoney(Config.GetStandUnlockCost(stand.Floor, stand.Slot))
			stand.UnlockPrompt.ObjectText = ("Piso %d · Estante %d"):format(stand.Floor, stand.Slot)
			stand.UnlockPrompt.ActionText = "Desbloquear " .. cost
			stand.SignLabel.Text = cost
		else
			stand.SignLabel.Text = "BLOQUEADO"
		end

		local mineralId = stands[stand.Index]
		local mineral = unlocked and mineralId ~= "" and Config.MineralsById[mineralId]
		if mineral then
			stand.Crystal.Color = Config.GetRarityColor(mineralId)
			stand.Crystal.Transparency = 0.1
		else
			stand.Crystal.Transparency = 1
		end
	end

	local nextFloor = floorsOwned + 1
	if nextFloor > Config.MaxFloors then
		base.Terminal.Prompt.Enabled = false
		base.Terminal.Label.Text = "TODOS LOS PISOS"
	else
		local cost = Config.FormatMoney(Config.FloorCosts[nextFloor])
		base.Terminal.Prompt.Enabled = true
		base.Terminal.Prompt.ObjectText = ("Piso %d"):format(nextFloor)
		base.Terminal.Prompt.ActionText = "Comprar " .. cost
		base.Terminal.Label.Text = ("PISO %d\n%s"):format(nextFloor, cost)
	end
end

local function emptyStandsData()
	local stands = {}
	for index = 1, Config.TotalStands do
		stands[index] = ""
	end
	return stands
end

-- actions = { Collect(player, standIndex), Unlock(player, floor), BuyFloor(player) }; solo se
-- llaman cuando el jugador es el dueño de esa base.
function Bases.Init(basesList, actions)
	list = basesList
	for baseIndex, base in list do
		local function isOwner(player)
			return assigned[player] == baseIndex
		end

		for _, stand in base.Stands do
			local busy = false
			stand.Pad.Touched:Connect(function(hit)
				if busy then
					return
				end
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player and isOwner(player) then
					busy = true
					actions.Collect(player, stand.Index)
					task.delay(0.6, function()
						busy = false
					end)
				end
			end)
			stand.UnlockPrompt.Triggered:Connect(function(player)
				if isOwner(player) then
					actions.Unlock(player, stand.Floor)
				end
			end)
		end

		base.Terminal.Prompt.Triggered:Connect(function(player)
			if isOwner(player) then
				actions.BuyFloor(player)
			end
		end)

		refresh(base, defaultFloorStands(), emptyStandsData())
	end
end

-- Devuelve el índice de la base asignada, o nil si ya no quedan libres.
-- Debe llamarse antes de que aparezca el personaje (RespawnLocation).
function Bases.Assign(player)
	if assigned[player] then
		return assigned[player]
	end

	local index
	local preferred = RunService:IsStudio() and Config.DevPreferredBase or nil
	if preferred and list[preferred] and not owners[preferred] then
		index = preferred
	else
		for i = 1, #list do
			if not owners[i] then
				index = i
				break
			end
		end
	end
	if not index then
		return nil
	end

	owners[index] = player
	assigned[player] = index
	player.RespawnLocation = list[index].Spawn
	list[index].Plate:SetAttribute("OwnerUserId", player.UserId)
	list[index].Label.Text = ("%s\n$0"):format(player.DisplayName)
	list[index].Label.Parent.Enabled = true
	return index
end

function Bases.GetIndex(player)
	return assigned[player]
end

-- Posición del pedestal de un estante de la base del jugador (nil si no tiene base).
function Bases.GetStandPosition(player, standIndex)
	local index = assigned[player]
	local stand = index and list[index].Stands[standIndex]
	return stand and stand.Pedestal.Position
end

-- Actualiza el cartel de la base (nombre y dinero), los pisos y los estantes.
function Bases.Update(player, data)
	local index = assigned[player]
	if not index or not data then
		return
	end
	local base = list[index]
	local stars = if (data.Rebirths or 0) > 0 then " ★" .. data.Rebirths else ""
	base.Label.Text = ("%s%s\n%s"):format(player.DisplayName, stars, Config.FormatMoney(data.Money))
	base.Label.Parent.Enabled = true
	refresh(base, data.FloorStands, data.Stands)
end

function Bases.Release(player)
	local index = assigned[player]
	if not index then
		return
	end
	assigned[player] = nil
	owners[index] = nil
	list[index].Plate:SetAttribute("OwnerUserId", nil)
	list[index].Label.Text = ""
	list[index].Label.Parent.Enabled = false
	refresh(list[index], defaultFloorStands(), emptyStandsData())
end

return Bases
