-- Datos del jugador (dinero, mejoras, inventario), guardado y reglas de compra/venta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(script.Parent.ProfileStore)

local Economy = {}

local store = ProfileStore.New("MinerosLunares_v1", {
	Money = Config.StartingMoney,
	Speed = 0,
	Strength = 0,
	Pickaxe = 0,
	Inventory = {}, -- lista de ids de minerales (máx. Config.InventorySize)
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
