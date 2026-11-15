-- Datos del jugador (dinero, mejoras, inventario), guardado y reglas de compra/venta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(script.Parent.ProfileStore)

local Economy = {}

local function emptyStands()
	local stands = {}
	for index = 1, Config.StandsPerFloor do
		stands[index] = ""
	end
	return stands
end

local function zeroTimes()
	local times = {}
	for index = 1, Config.StandsPerFloor do
		times[index] = 0
	end
	return times
end

local store = ProfileStore.New("MinerosLunares_v1", {
	Money = Config.StartingMoney,
	Speed = 0,
	Strength = 0,
	Pickaxe = 0,
	Inventory = {}, -- lista de ids de minerales (máx. Config.InventorySize)
	Stands = emptyStands(), -- mineral en cada estante ("" = vacío)
	StandSince = zeroTimes(), -- os.time() desde que se empezó a juntar en cada estante
})

local datas = {} -- player -> profile.Data
local profiles = {}

-- Se asigna desde Main para avisar al cliente de cambios.
Economy.OnChanged = function(_player, _data) end

local function notify(player)
	Economy.OnChanged(player, datas[player])
end

-- Carga el perfil (yield). Devuelve true si el jugador quedó listo.
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
		return false
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		datas[player] = nil
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Tu sesión de datos terminó. Vuelve a entrar.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return false
	end

	datas[player] = profile.Data
	profiles[player] = profile
	notify(player)
	return true
end

function Economy.Get(player)
	return datas[player]
end

function Economy.Remove(player)
	local profile = profiles[player]
	datas[player] = nil
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
end

-- Suma dinero (solo para pruebas en Studio).
function Economy.AddMoney(player, amount)
	local data = datas[player]
	if data then
		data.Money += amount
		notify(player)
	end
end

-- Guarda un mineral en la mochila. Devuelve false si no hay espacio o no existe.
function Economy.AddMineral(player, mineralId)
	local data = datas[player]
	if not data or not Config.MineralsById[mineralId] or #data.Inventory >= Config.InventorySize then
		return false
	end
	table.insert(data.Inventory, mineralId)
	notify(player)
	return true
end

-- Vende el mineral del espacio `index`. Devuelve los créditos ganados, o nil.
function Economy.Sell(player, index)
	local data = datas[player]
	if not data or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #data.Inventory then
		return nil
	end
	local mineral = Config.MineralsById[data.Inventory[index]]
	table.remove(data.Inventory, index)
	local value = mineral and mineral.Value or 0
	data.Money += value
	notify(player)
	return value
end

local function isIndex(value, max)
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= max
end

-- Deja el mineral del espacio `inventoryIndex` en un estante vacío. Devuelve ok, mensaje.
function Economy.PlaceMineral(player, standIndex, inventoryIndex)
	local data = datas[player]
	if not data or not isIndex(standIndex, #data.Stands) or not isIndex(inventoryIndex, #data.Inventory) then
		return false
	end
	if data.Stands[standIndex] ~= "" then
		return false, "Ese estante ya tiene un mineral."
	end
	data.Stands[standIndex] = data.Inventory[inventoryIndex]
	data.StandSince[standIndex] = os.time()
	table.remove(data.Inventory, inventoryIndex)
	notify(player)
	return true
end

-- Cobra lo que juntó un estante. Devuelve los créditos cobrados.
function Economy.CollectStand(player, standIndex)
	local data = datas[player]
	if not data or not isIndex(standIndex, #data.Stands) then
		return 0
	end
	local mineralId = data.Stands[standIndex]
	if mineralId == "" then
		return 0
	end
	local pending = Config.GetStandPending(mineralId, data.StandSince[standIndex], os.time())
	if pending <= 0 then
		return 0
	end
	data.Money += pending
	data.StandSince[standIndex] = os.time()
	notify(player)
	return pending
end

-- Devuelve el mineral del estante a la mochila (y cobra lo que había juntado).
function Economy.RemoveMineral(player, standIndex)
	local data = datas[player]
	if not data or not isIndex(standIndex, #data.Stands) then
		return false
	end
	local mineralId = data.Stands[standIndex]
	if mineralId == "" then
		return false
	end
	if #data.Inventory >= Config.InventorySize then
		return false, "¡Mochila llena! Vende algo primero."
	end
	Economy.CollectStand(player, standIndex)
	table.insert(data.Inventory, mineralId)
	data.Stands[standIndex] = ""
	data.StandSince[standIndex] = 0
	notify(player)
	return true
end

-- Compra el siguiente nivel de una mejora. Devuelve true si se hizo.
function Economy.PurchaseUpgrade(player, kind)
	local data = datas[player]
	if not data or type(kind) ~= "string" or not Config.Upgrades[kind] then
		return false
	end
	local level = data[kind]
	if level >= Config.Upgrades[kind].MaxLevel then
		return false
	end
	local cost = Config.GetUpgradeCost(kind, level)
	if data.Money < cost then
		return false
	end
	data.Money -= cost
	data[kind] = level + 1
	notify(player)
	return true
end

return Economy
