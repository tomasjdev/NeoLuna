local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local MineService = require(script.Parent.MineService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local SHOP_USE_DISTANCE = 35 -- a qué distancia de la tienda se puede vender y mejorar

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

-- servidor -> cliente
local stateRemote = newRemote("StateChanged")
newRemote("Notice")
newRemote("Carry")
local openShopRemote = newRemote("OpenShop")
-- cliente -> servidor
local requestRemote = newRemote("RequestState")
newRemote("Throw")
local buyUpgradeRemote = newRemote("BuyUpgrade")
local sellRemote = newRemote("SellMineral")

local world = WorldBuilder.Build()
MineService.Init(remotes)

local function applyWalkSpeed(player)
	local data = Economy.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Config.GetWalkSpeed(data.Speed)
	end
end

Economy.OnChanged = function(player, data)
	stateRemote:FireClient(player, data)
	applyWalkSpeed(player)
end

local function nearShop(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - world.ShopPosition).Magnitude <= SHOP_USE_DISTANCE
end

world.ShopPrompt.Triggered:Connect(function(player)
	openShopRemote:FireClient(player, world.ShopPosition)
end)

buyUpgradeRemote.OnServerEvent:Connect(function(player, kind)
	if nearShop(player) then
		Economy.PurchaseUpgrade(player, kind)
	end
end)

sellRemote.OnServerEvent:Connect(function(player, index)
	if nearShop(player) then
		Economy.Sell(player, index)
	end
end)

requestRemote.OnServerEvent:Connect(function(player)
	local data = Economy.Get(player)
	if data then
		stateRemote:FireClient(player, data)
	end
end)

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		applyWalkSpeed(player)
	end)
	Economy.Load(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(Economy.Remove)
