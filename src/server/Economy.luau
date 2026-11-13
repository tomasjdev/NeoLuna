-- Estado y reglas de economía por jugador (solo servidor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Economy = {}

local states = {}

-- Se asigna desde Main para avisar al cliente de cambios.
Economy.OnChanged = function(_player, _state) end

local function notify(player)
	Economy.OnChanged(player, states[player])
end

function Economy.Init(player)
	states[player] = {
		Credits = Config.StartingCredits,
		Drones = 1,
		Capacity = 0,
		Speed = 0,
	}
	notify(player)
	return states[player]
end

function Economy.Get(player)
	return states[player]
end

function Economy.Remove(player)
	states[player] = nil
end

function Economy.Deliver(player, units)
	local state = states[player]
	if not state then
		return
	end
	state.Credits += units * Config.RegolithValue
	notify(player)
end

-- Devuelve true si la compra se hizo.
function Economy.Purchase(player, kind)
	local state = states[player]
	if not state or typeof(kind) ~= "string" or not Config.Upgrades[kind] then
		return false
	end
	if kind == "Drone" and state.Drones >= Config.MaxDrones then
		return false
	end
	local cost = Config.GetCost(kind, state)
	if state.Credits < cost then
		return false
	end
	state.Credits -= cost
	if kind == "Drone" then
		state.Drones += 1
	else
		state[kind] += 1
	end
	notify(player)
	return true
end

return Economy
