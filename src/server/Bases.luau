-- Asigna una base a cada jugador (hasta Config.MaxPlayers), la libera al salir y mantiene
-- su cartel y sus estantes al día. En el juego publicado se reparte en orden (1, 2, 3...).
-- En Studio, para probar, el primer jugador recibe Config.DevPreferredBase.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Bases = {}

local list = {} -- { Spawn, Label, Center, Index, Plate, Stands } por cada base
local owners = {} -- índice de base -> player
local assigned = {} -- player -> índice de base

local function formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function formatRate(rate)
	if rate >= 10 then
		return ("%.0f"):format(rate)
	elseif rate >= 1 then
		return ("%.1f"):format(rate)
	end
	return ("%.2f"):format(rate)
end

-- onCollect(player, standIndex) se llama cuando el dueño pisa la placa de cobro de un estante.
function Bases.Init(basesList, onCollect)
	list = basesList
	for baseIndex, base in list do
		for _, stand in base.Stands do
			local busy = false
			stand.Pad.Touched:Connect(function(hit)
				if busy then
					return
				end
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player and assigned[player] == baseIndex then
					busy = true
					onCollect(player, stand.Index)
					task.delay(0.6, function()
						busy = false
					end)
				end
			end)
		end
	end
end

local function resetStands(base)
	for _, stand in base.Stands do
		stand.Crystal.Transparency = 1
		stand.Label.Visible = false
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
	list[index].Label.Text = ("Base %d · %s\n0 cr"):format(index, player.DisplayName)
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

-- Actualiza el cartel de la base (nombre, dinero, créditos por segundo) y los estantes
-- (cristal + cuánto han juntado).
function Bases.Update(player, data)
	local index = assigned[player]
	if not index or not data then
		return
	end
	local base = list[index]
	local income = Config.GetTotalIncome(data)
	base.Label.Text = ("Base %d · %s\n%s cr · +%s/s"):format(index, player.DisplayName, formatNumber(data.Money), formatRate(income))

	local now = os.time()
	for _, stand in base.Stands do
		local mineralId = data.Stands[stand.Index]
		local mineral = mineralId ~= "" and Config.MineralsById[mineralId]
		if mineral then
			local pending = Config.GetStandPending(mineralId, data.StandSince[stand.Index], now)
			stand.Crystal.Color = Config.GetRarityColor(mineralId)
			stand.Crystal.Transparency = 0.1
			stand.Label.Text = ("%s\n+%s/s · %s cr"):format(mineral.Name, formatRate(Config.GetMineralIncome(mineralId)), formatNumber(pending))
			stand.Label.Visible = true
		else
			stand.Crystal.Transparency = 1
			stand.Label.Visible = false
		end
	end
end

function Bases.Release(player)
	local index = assigned[player]
	if not index then
		return
	end
	assigned[player] = nil
	owners[index] = nil
	list[index].Plate:SetAttribute("OwnerUserId", nil)
	list[index].Label.Text = ("Base %d · libre"):format(index)
	resetStands(list[index])
end

return Bases
