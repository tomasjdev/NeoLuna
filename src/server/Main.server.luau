local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)
local DroneService = require(script.Parent.DroneService)

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function newRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local buyRemote = newRemote("Buy") -- cliente -> servidor
local stateRemote = newRemote("StateChanged") -- servidor -> cliente
local requestRemote = newRemote("RequestState") -- cliente -> servidor
local offlineRemote = newRemote("OfflineEarnings") -- servidor -> cliente

Economy.OnChanged = function(player, state)
	stateRemote:FireClient(player, state)
end

-- El estado y las ganancias offline se envían cuando el perfil ya cargó
-- Y el cliente avisó de que está listo, sea cual sea el que llegue primero.
local clientReady = {}
local pendingOffline = {}

local function flush(player)
	local state = Economy.Get(player)
	if not (clientReady[player] and state) then
		return
	end
	stateRemote:FireClient(player, state)
	local earned = pendingOffline[player]
	if earned and earned > 0 then
		offlineRemote:FireClient(player, earned)
	end
	pendingOffline[player] = nil
end

buyRemote.OnServerEvent:Connect(function(player, kind)
	if Economy.Purchase(player, kind) and kind == "Drone" then
		DroneService.Spawn(player)
	end
end)

requestRemote.OnServerEvent:Connect(function(player)
	clientReady[player] = true
	flush(player)
end)

DroneService.BuildWorld()

local function onPlayerAdded(player)
	local earned = Economy.Load(player)
	if not earned then
		return
	end
	-- Un dron por cada uno que el jugador ya tenía guardado.
	for _ = 1, Economy.Get(player).Drones do
		DroneService.Spawn(player)
	end
	pendingOffline[player] = earned
	flush(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	clientReady[player] = nil
	pendingOffline[player] = nil
	Economy.Remove(player)
end)
