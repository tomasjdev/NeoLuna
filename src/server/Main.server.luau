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

Economy.OnChanged = function(player, state)
	stateRemote:FireClient(player, state)
end

buyRemote.OnServerEvent:Connect(function(player, kind)
	if Economy.Purchase(player, kind) and kind == "Drone" then
		DroneService.Spawn(player)
	end
end)

requestRemote.OnServerEvent:Connect(function(player)
	local state = Economy.Get(player)
	if state then
		stateRemote:FireClient(player, state)
	end
end)

DroneService.BuildWorld()

local function onPlayerAdded(player)
	Economy.Init(player)
	DroneService.Spawn(player) -- dron inicial
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(Economy.Remove)
