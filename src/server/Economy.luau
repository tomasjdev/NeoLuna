-- Estado, guardado y reglas de economía por jugador (solo servidor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(script.Parent.ProfileStore)

local Economy = {}

local store = ProfileStore.New("PlayerData", {
	Credits = Config.StartingCredits,
	Drones = 1,
	Capacity = 0,
	Speed = 0,
	LastSeen = 0, -- os.time() del último guardado; 0 = jugador nuevo
})

local states = {} -- player -> profile.Data
local profiles = {}

-- Se asigna desde Main para avisar al cliente de cambios.
Economy.OnChanged = function(_player, _state) end

local function notify(player)
	Economy.OnChanged(player, states[player])
end

-- Carga el perfil (yield). Devuelve las ganancias offline, o nil si falló.
function Economy.Load(player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("No se pudieron cargar tus datos. Vuelve a entrar.")
		end
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		states[player] = nil
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Tu sesión de datos terminó. Vuelve a entrar.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	local state = profile.Data
	local now = os.time()

	local earned = 0
	if state.LastSeen > 0 then
		local elapsed = math.clamp(now - state.LastSeen, 0, Config.Offline.MaxSeconds)
		earned = math.floor(elapsed * Config.GetIncomePerSecond(state) * Config.Offline.Rate)
	end
	state.Credits += earned
	state.LastSeen = now

	local function stamp()
		state.LastSeen = os.time()
	end
	profile.OnSave:Connect(stamp)
	profile.OnLastSave:Connect(stamp)

	states[player] = state
	profiles[player] = profile
	notify(player)
	return earned
end

function Economy.Get(player)
	return states[player]
end

function Economy.Remove(player)
	local profile = profiles[player]
	states[player] = nil
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
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
