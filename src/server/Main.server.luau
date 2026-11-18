local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Admin = require(script.Parent.Admin)
local ArtLibrary = require(script.Parent.ArtLibrary)
local Bases = require(script.Parent.Bases)
local Economy = require(script.Parent.Economy)
local Gifts = require(script.Parent.Gifts)
local HeldMineral = require(script.Parent.HeldMineral)
local MineService = require(script.Parent.MineService)
local Robux = require(script.Parent.Robux)
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
local adminStatusRemote = newRemote("AdminStatus") -- le dice al cliente si es admin
newRemote("Selected") -- espacio de la barra que llevas en la mano (0 = ninguno)
newRemote("Carry")
newRemote("NodeBroken")
newRemote("UfoAlert") -- servidor -> cliente: aparecen ovnis (cuántos, cuántos habrá en total)
local openShopRemote = newRemote("OpenShop")
-- cliente -> servidor
local requestRemote = newRemote("RequestState")
newRemote("MineStart")
newRemote("SelectSlot") -- elegir qué mineral de la barra llevar en la mano
newRemote("MineCancel")
newRemote("AdminCommand") -- órdenes del panel de administrador (el servidor comprueba el permiso)
local buyUpgradeRemote = newRemote("BuyUpgrade")
local sellRemote = newRemote("SellMineral")
local sellAllRemote = newRemote("SellAll")
newRemote("BuyRobux") -- cliente -> servidor: comprar un pase o producto de Robux
local placeRemote = newRemote("PlaceMineral")
local removeRemote = newRemote("RemoveMineral")
local fuseRemote = newRemote("FuseMinerals")
local rebirthRemote = newRemote("RebirthRequest")
newRemote("GiftOffer") -- servidor -> cliente: alguien te quiere regalar un mineral
newRemote("GiftClose") -- servidor -> cliente: la oferta terminó
newRemote("GiftRequest") -- cliente -> servidor: regalar un mineral de la mochila
newRemote("GiftAnswer") -- cliente -> servidor: aceptar o rechazar

-- Modelos 3D de Blender: se cargan antes de construir (si fallan, se usan los de código).
ArtLibrary.Preload()

local world = WorldBuilder.Build()
Bases.Init(world.Bases, {
	Collect = function(player, standIndex)
		local amount = Economy.CollectStand(player, standIndex)
		if amount >= 1 then
			remotes.Notice:FireClient(player, "+" .. Config.FormatMoney(amount))
		end
	end,
	Unlock = function(player, floor)
		local _, message = Economy.UnlockStand(player, floor)
		if message then
			remotes.Notice:FireClient(player, message)
		end
	end,
	BuyFloor = function(player)
		local _, message = Economy.BuyFloor(player)
		if message then
			remotes.Notice:FireClient(player, message)
		end
	end,
})
MineService.Init(remotes)
HeldMineral.Init(remotes)
Admin.Init(remotes)
Gifts.Init(remotes)
Robux.Init(remotes)

local function applyWalkSpeed(player)
	local data = Economy.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		-- Llevar varios minerales frena un poco (5 % por cada mineral extra).
		local extra = math.max(0, MineService.GetCarryCount(player) - 1)
		local slow = if MineService.IsSlowed(player) then Config.Ufo.SlowAmount else 0
		humanoid.WalkSpeed = Config.GetWalkSpeed(data.Speed, data.Passes.Boots == true) * (1 - Config.CarrySlowPerExtra * extra) * (1 - slow)
	end
end

MineService.OnCarryChanged = function(player)
	applyWalkSpeed(player)
end

Economy.OnChanged = function(player, data)
	stateRemote:FireClient(player, data)
	applyWalkSpeed(player)
	Bases.Update(player, data)
	HeldMineral.Refresh(player, data)
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

-- Horno de fusion: uno solo en la plaza; lo usa cualquiera con sus propios minerales.
local function nearFuser(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - world.Fuse.Position).Magnitude <= SHOP_USE_DISTANCE
end

world.Fuse.Prompt.Triggered:Connect(function(player)
	openShopRemote:FireClient(player, "Fusion", "Fusion", world.Fuse.Position)
end)

-- Altar de renacimiento (plaza).
world.Fuse.Rebirth.Prompt.Triggered:Connect(function(player)
	openShopRemote:FireClient(player, "Rebirth", "Rebirth", world.Fuse.Rebirth.Position)
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - world.Fuse.Rebirth.Position).Magnitude > SHOP_USE_DISTANCE then
		return
	end
	local _, message = Economy.Rebirth(player)
	if message then
		remotes.Notice:FireClient(player, message)
	end
end)

fuseRemote.OnServerEvent:Connect(function(player, rarityId)
	if not nearFuser(player) then
		return
	end
	local ok, result = Economy.Fuse(player, rarityId)
	if ok then
		remotes.Notice:FireClient(player, ("¡Fusión! Obtuviste: %s"):format(result.Name))
	elseif result then
		remotes.Notice:FireClient(player, result)
	end
end)

buyUpgradeRemote.OnServerEvent:Connect(function(player, kind)
	if nearUpgradeShop(player) then
		Economy.PurchaseUpgrade(player, kind)
	end
end)

sellAllRemote.OnServerEvent:Connect(function(player)
	if nearUpgradeShop(player) then
		local total, count = Economy.SellAll(player)
		if count > 0 then
			remotes.Notice:FireClient(player, ("Vendiste %d minerales por %s"):format(count, Config.FormatMoney(total)))
		end
	end
end)

sellRemote.OnServerEvent:Connect(function(player, index)
	if nearUpgradeShop(player) then
		Economy.Sell(player, index)
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
		local richest, richestMoney = nil, -1
		for _, player in Players:GetPlayers() do
			local data = Economy.Get(player)
			Bases.Update(player, data)
			if data and data.Money > richestMoney then
				richest, richestMoney = player, data.Money
			end
		end

		-- Cartel del jugador con mas dinero (foto de perfil y nombre).
		local top = world.Fuse.Top
		if richest then
			top.Image.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(richest.UserId)
			top.Name.Text = richest.DisplayName
		end
		top.Gui.Enabled = richest ~= nil
	end
end)

requestRemote.OnServerEvent:Connect(function(player)
	adminStatusRemote:FireClient(player, Admin.IsAdmin(player))
	local data = Economy.Get(player)
	if data then
		stateRemote:FireClient(player, data)
	end
end)

local function onPlayerAdded(player)
	Bases.Assign(player) -- antes de que aparezca el personaje

	-- Siempre se aparece en la propia base (también si el personaje ya había aparecido en otro
	-- lado antes de que se le asignara la base).
	local function sendToBase(character)
		local spawn = Bases.GetSpawn(player)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if spawn and root then
			task.wait()
			root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		end
	end
	player.CharacterAdded:Connect(function(character)
		HeldMineral.Clear(player)
		applyWalkSpeed(player)
		task.spawn(sendToBase, character)
	end)
	if player.Character then
		task.spawn(sendToBase, player.Character)
	end
	if Economy.Load(player) then
		Robux.CheckPasses(player)
		-- Lo que juntaron los estantes mientras no estaba (se cobra pisando las placas verdes).
		task.delay(6, function()
			local data = Economy.Get(player)
			if not data then
				return
			end
			local now = os.time()
			local multiplier = Config.GetRebirthMultiplier(data.Rebirths) * Config.GetMoneyMultiplier(data)
			local pending = 0
			for index, mineralId in data.Stands do
				if mineralId ~= "" then
					pending += Config.GetStandPending(mineralId, data.StandSince[index], now, multiplier)
				end
			end
			if pending >= 100 then
				remotes.Notice:FireClient(player, ("¡Bienvenido de vuelta! Tus estantes juntaron %s. ¡Cóbralos en las placas verdes!"):format(Config.FormatMoney(pending)))
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Gifts.PlayerLeaving(player)
	Bases.Release(player)
	Economy.Remove(player)
end)
