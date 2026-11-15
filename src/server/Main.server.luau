local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Economy = require(script.Parent.Economy)
local MineService = require(script.Parent.MineService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local SHOP_USE_DISTANCE = 35 -- a qué distancia de la tienda se puede vender y mejorar
local STAND_USE_DISTANCE = 20 -- a qué distancia de un estante se puede dejar o retirar un mineral

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
newRemote("NodeBroken")
local openShopRemote = newRemote("OpenShop")
-- cliente -> servidor
local requestRemote = newRemote("RequestState")
newRemote("MineStart")
newRemote("MineCancel")
local devRemote = newRemote("DevCommand") -- atajos de prueba, solo funcionan en Studio
local buyUpgradeRemote = newRemote("BuyUpgrade")
local sellRemote = newRemote("SellMineral")
local placeRemote = newRemote("PlaceMineral")
local removeRemote = newRemote("RemoveMineral")

local world = WorldBuilder.Build()
Bases.Init(world.Bases, function(player, standIndex)
	local amount = Economy.CollectStand(player, standIndex)
	if amount >= 1 then
		remotes.Notice:FireClient(player, ("+%d cr"):format(math.floor(amount)))
	end
end)
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
	Bases.Update(player, data)
end

-- Solo se vende y mejora cerca de alguna tienda de mejoras.
local function nearUpgradeShop(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	for _, shop in world.Shops do
		if shop.Kind == "Upgrade" and (hrp.Position - shop.Position).Magnitude <= SHOP_USE_DISTANCE then
			return true
		end
	end
	return false
end

-- Cada tienda abre su panel en el cliente de quien pulsa el prompt.
for _, shop in world.Shops do
	shop.Prompt.Triggered:Connect(function(player)
		openShopRemote:FireClient(player, shop.Kind, shop.Id, shop.Position)
	end)
end

buyUpgradeRemote.OnServerEvent:Connect(function(player, kind)
	if nearUpgradeShop(player) then
		Economy.PurchaseUpgrade(player, kind)
	end
end)

sellRemote.OnServerEvent:Connect(function(player, index)
	if nearUpgradeShop(player) then
		Economy.Sell(player, index)
	end
end)

-- Atajos para probar en Studio: teletransportarse a una zona y ganar dinero.
devRemote.OnServerEvent:Connect(function(player, command, value)
	if not RunService:IsStudio() then
		return
	end
	if command == "Zone" and type(value) == "number" then
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local zone = math.clamp(math.floor(value), 1, Config.ZoneCount)
			hrp.CFrame = CFrame.new((zone - 1) * Config.ZoneLength + 25, 5, 0)
			remotes.Notice:FireClient(player, ("[Prueba] Zona %d"):format(zone))
		end
	elseif command == "Money" then
		Economy.AddMoney(player, 10000)
		remotes.Notice:FireClient(player, "[Prueba] +10.000 créditos")
	elseif command == "Mineral" then
		local ok = Economy.AddMineral(player, "AlienCrystal")
		remotes.Notice:FireClient(player, if ok then "[Prueba] +1 Cristal alienígena" else "[Prueba] Mochila llena")
	end
end)

-- Solo se usa un estante de TU base y estando cerca de él.
local function nearOwnStand(player, standIndex)
	local position = Bases.GetStandPosition(player, standIndex)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return position ~= nil and hrp ~= nil and (hrp.Position - position).Magnitude <= STAND_USE_DISTANCE
end

placeRemote.OnServerEvent:Connect(function(player, standIndex, inventoryIndex)
	if nearOwnStand(player, standIndex) then
		local ok, message = Economy.PlaceMineral(player, standIndex, inventoryIndex)
		if not ok and message then
			remotes.Notice:FireClient(player, message)
		end
	end
end)

removeRemote.OnServerEvent:Connect(function(player, standIndex)
	if nearOwnStand(player, standIndex) then
		local ok, message = Economy.RemoveMineral(player, standIndex)
		if not ok and message then
			remotes.Notice:FireClient(player, message)
		end
	end
end)

-- Cada segundo se refresca lo que han juntado los estantes (cartel y estantes de cada base).
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			Bases.Update(player, Economy.Get(player))
		end
	end
end)

requestRemote.OnServerEvent:Connect(function(player)
	local data = Economy.Get(player)
	if data then
		stateRemote:FireClient(player, data)
	end
end)

local function onPlayerAdded(player)
	Bases.Assign(player) -- antes de que aparezca el personaje
	player.CharacterAdded:Connect(function()
		applyWalkSpeed(player)
	end)
	Economy.Load(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Bases.Release(player)
	Economy.Remove(player)
end)
