-- Datos del jugador (dinero, mejoras, inventario), guardado y reglas de compra/venta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(script.Parent.ProfileStore)

local Economy = {}

local function emptyStands()
	local stands = {}
	for index = 1, Config.TotalStands do
		stands[index] = ""
	end
	return stands
end

local function zeroTimes()
	local times = {}
	for index = 1, Config.TotalStands do
		times[index] = 0
	end
	return times
end

-- Estantes desbloqueados por piso: solo el piso 1 y con 4 abiertos.
local function startFloors()
	local floors = {}
	for floor = 1, Config.MaxFloors do
		floors[floor] = if floor == 1 then Config.StandsOpenPerFloor else 0
	end
	return floors
end

local store = ProfileStore.New("MinerosLunares_v1", {
	Money = Config.StartingMoney,
	Speed = 0,
	Strength = 0,
	Pickaxe = 0,
	Inventory = {}, -- lista de ids de minerales (máx. Config.InventorySize)
	Stands = emptyStands(), -- mineral en cada estante ("" = vacío)
	StandSince = zeroTimes(), -- os.time() desde que se empezó a juntar en cada estante
	FloorStands = startFloors(), -- estantes desbloqueados en cada piso (0 = piso sin comprar)
	Rebirths = 0, -- renacimientos hechos
	PeakIncome = 0, -- lo máximo que han generado sus estantes por segundo (sin multiplicador)
	Passes = {}, -- pases de Robux que tiene: { X2 = true, Boots = true }
	Shields = 0, -- escudos anti-Alien que le quedan
})

-- Perfiles guardados antes de los pisos: amplía los estantes y no deja un mineral en un
-- estante bloqueado.
local function migrate(data)
	for index = 1, Config.TotalStands do
		data.Stands[index] = data.Stands[index] or ""
		data.StandSince[index] = data.StandSince[index] or 0
		if data.Stands[index] ~= "" then
			local floor = Config.StandFloor(index)
			data.FloorStands[floor] = math.max(data.FloorStands[floor], Config.StandSlot(index), Config.StandsOpenPerFloor)
		end
	end
end

local datas = {} -- player -> profile.Data
local reserved = {} -- player -> espacios de la mochila apartados (regalos pendientes)
local profiles = {}

-- Se asigna desde Main para avisar al cliente de cambios.
Economy.OnChanged = function(_player, _data) end

local function notify(player)
	local data = datas[player]
	if data then
		data.PeakIncome = math.max(data.PeakIncome or 0, Config.GetTotalIncome(data))
	end
	Economy.OnChanged(player, data)
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

	migrate(profile.Data)
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
	reserved[player] = nil
	datas[player] = nil
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
end

-- Suma dinero (o resta, si es negativo; nunca baja de 0). Lo usa el panel de administrador.
function Economy.AddMoney(player, amount)
	local data = datas[player]
	if data then
		data.Money = math.max(0, data.Money + amount)
		notify(player)
	end
end

-- Sube o baja el nivel de una mejora, entre 0 y su máximo. Devuelve el nivel nuevo.
-- Lo usa el panel de administrador.
function Economy.AdjustUpgrade(player, kind, delta)
	local data = datas[player]
	if not data or type(kind) ~= "string" or not Config.Upgrades[kind] or type(delta) ~= "number" then
		return nil
	end
	local level = math.clamp(data[kind] + math.floor(delta), 0, Config.Upgrades[kind].MaxLevel)
	data[kind] = level
	notify(player)
	return level
end

-- Espacios libres de la mochila (sin contar los apartados por regalos pendientes).
function Economy.FreeSlots(player)
	local data = datas[player]
	if not data then
		return 0
	end
	return Config.InventorySize - #data.Inventory - (reserved[player] or 0)
end

-- Aparta (o libera, con un número negativo) espacios de la mochila.
function Economy.Reserve(player, amount)
	reserved[player] = math.max(0, (reserved[player] or 0) + amount)
end

-- Saca el mineral del espacio `index` (para un regalo). Devuelve su id, o nil.
function Economy.TakeMineral(player, index)
	local data = datas[player]
	if not data or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #data.Inventory then
		return nil
	end
	local mineralId = table.remove(data.Inventory, index)
	notify(player)
	return mineralId
end

-- Devuelve a la mochila un mineral que se había apartado (su espacio estaba reservado).
function Economy.ReturnMineral(player, mineralId)
	local data = datas[player]
	if data and Config.MineralsById[mineralId] then
		table.insert(data.Inventory, mineralId)
		notify(player)
	end
end

-- Guarda un mineral en la mochila. Devuelve false si no hay espacio o no existe.
function Economy.AddMineral(player, mineralId)
	local data = datas[player]
	if not data or not Config.MineralsById[mineralId] or Economy.FreeSlots(player) <= 0 then
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
	local value = (mineral and mineral.Value or 0) * Config.GetMoneyMultiplier(data)
	data.Money += value
	notify(player)
	return value
end

-- Vende todos los minerales de la mochila. Devuelve el dinero ganado y cuántos vendió.
function Economy.SellAll(player)
	local data = datas[player]
	if not data or #data.Inventory == 0 then
		return 0, 0
	end
	local multiplier = Config.GetMoneyMultiplier(data)
	local total, count = 0, #data.Inventory
	for _, mineralId in data.Inventory do
		local mineral = Config.MineralsById[mineralId]
		total += (mineral and mineral.Value or 0) * multiplier
	end
	table.clear(data.Inventory)
	data.Money += total
	notify(player)
	return total, count
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
	if not Config.IsStandUnlocked(data.FloorStands, standIndex) then
		return false, "Ese estante está bloqueado."
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
	local pending = Config.GetStandPending(mineralId, data.StandSince[standIndex], os.time(), Config.GetRebirthMultiplier(data.Rebirths) * Config.GetMoneyMultiplier(data))
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
	if Economy.FreeSlots(player) <= 0 then
		return false, "¡Mochila llena! Vende algo primero."
	end
	Economy.CollectStand(player, standIndex)
	table.insert(data.Inventory, mineralId)
	data.Stands[standIndex] = ""
	data.StandSince[standIndex] = 0
	notify(player)
	return true
end

-- Funde Config.FusionCount minerales de una rareza en 1 de la rareza siguiente.
-- Devuelve true y el mineral nuevo, o false y un mensaje.
function Economy.Fuse(player, rarityId)
	local data = datas[player]
	local rarity = type(rarityId) == "string" and Config.RaritiesById[rarityId]
	if not data or not rarity then
		return false
	end
	local target = Config.GetFusionTarget(rarity.Id)
	if not target then
		return false, "Ese mineral no se puede fusionar."
	end
	local indices = {} -- de mayor a menor, para poder quitarlos sin desordenar
	for index = #data.Inventory, 1, -1 do
		local mineral = Config.MineralsById[data.Inventory[index]]
		if mineral and mineral.Rarity == rarity.Id then
			table.insert(indices, index)
			if #indices == Config.FusionCount then
				break
			end
		end
	end
	if #indices < Config.FusionCount then
		return false, ("Necesitas %d minerales %s."):format(Config.FusionCount, rarity.Name)
	end
	for _, index in indices do
		table.remove(data.Inventory, index)
	end
	local pool = Config.MineralsByRarity[target.Id]
	local result = pool[math.random(#pool)]
	table.insert(data.Inventory, result.Id)
	notify(player)
	return true, result
end

-- Panel de administrador: deja al jugador con `floors` pisos. `allOpen` abre todos los
-- estantes de esos pisos. Al quitar pisos no se tocan los que tengan minerales.
function Economy.AdminSetFloors(player, floors, allOpen)
	local data = datas[player]
	if not data then
		return false
	end
	floors = math.clamp(math.floor(floors), 1, Config.MaxFloors)
	for floor = Config.MaxFloors, floors + 1, -1 do
		for slot = 1, Config.StandsPerFloor do
			if data.Stands[(floor - 1) * Config.StandsPerFloor + slot] ~= "" then
				return false, ("El piso %d tiene minerales; retíralos primero."):format(floor)
			end
		end
	end
	for floor = 1, Config.MaxFloors do
		if floor > floors then
			data.FloorStands[floor] = 0
		elseif allOpen then
			data.FloorStands[floor] = Config.StandsPerFloor
		elseif data.FloorStands[floor] == 0 then
			data.FloorStands[floor] = Config.StandsOpenPerFloor
		end
	end
	notify(player)
	return true
end

-- Pases, escudos y paquetes de dinero (Robux).
function Economy.GrantPass(player, kind, owned)
	local data = datas[player]
	if not data or (kind ~= "X2" and kind ~= "Boots") then
		return false
	end
	data.Passes[kind] = if owned == false then nil else true
	notify(player)
	return true
end

function Economy.AddShield(player, amount)
	local data = datas[player]
	if not data then
		return false
	end
	data.Shields = math.max(0, data.Shields + amount)
	notify(player)
	return true
end

-- Gasta un escudo si tiene. Devuelve true si lo usó.
function Economy.UseShield(player)
	local data = datas[player]
	if not data or data.Shields <= 0 then
		return false
	end
	data.Shields -= 1
	notify(player)
	return true
end

-- Paquete de dinero: Hours horas de lo que generan sus estantes (mínimo Min). Devuelve lo dado.
function Economy.GrantCredits(player)
	local data = datas[player]
	if not data then
		return 0
	end
	local pack = Config.CreditsPack
	-- Lo que generan AHORA sus estantes (no el máximo histórico, que es solo para el renacimiento).
	local income = Config.GetTotalIncome(data) * Config.GetRebirthMultiplier(data.Rebirths)
	local amount = math.max(pack.Min, math.floor(income * pack.Hours * 3600))
	data.Money += amount
	notify(player)
	return amount
end

-- Renacer: cobra lo que juntaron los estantes y, si alcanza el dinero, lo pierde todo (solo el
-- dinero) a cambio de un multiplicador permanente. Devuelve ok, mensaje.
function Economy.Rebirth(player)
	local data = datas[player]
	if not data then
		return false
	end
	local cost = Config.GetRebirthCost(data)
	if not cost then
		return false, "¡Ya hiciste todos los renacimientos!"
	end
	for index = 1, Config.TotalStands do
		if data.Stands[index] ~= "" then
			Economy.CollectStand(player, index)
		end
	end
	if data.Money < cost then
		return false, ("Te faltan %s para renacer."):format(Config.FormatMoney(cost - data.Money))
	end
	data.Money = 0
	data.Rebirths += 1
	notify(player)
	return true, ("¡Renacimiento %d! Tus estantes ganan x%s."):format(data.Rebirths, tostring(Config.GetRebirthMultiplier(data.Rebirths)))
end

-- Panel de administrador: reinicia lo máximo que han generado sus estantes (para pruebas).
function Economy.AdminResetPeak(player)
	local data = datas[player]
	if not data then
		return false
	end
	data.PeakIncome = 0
	notify(player)
	return true
end

-- Panel de administrador: suma o resta renacimientos (entre 0 y el máximo).
function Economy.AdminAdjustRebirths(player, delta)
	local data = datas[player]
	if not data or type(delta) ~= "number" then
		return nil
	end
	data.Rebirths = math.clamp(data.Rebirths + math.floor(delta), 0, Config.Rebirth.Max)
	notify(player)
	return data.Rebirths
end

-- Compra el siguiente piso (viene con 4 estantes desbloqueados). Devuelve ok, mensaje.
function Economy.BuyFloor(player)
	local data = datas[player]
	if not data then
		return false
	end
	local floor = Config.CountFloors(data.FloorStands) + 1
	if floor > Config.MaxFloors then
		return false, "Ya tienes todos los pisos."
	end
	local cost = Config.FloorCosts[floor]
	if data.Money < cost then
		return false, ("Te faltan %s para el piso %d."):format(Config.FormatMoney(cost - data.Money), floor)
	end
	data.Money -= cost
	data.FloorStands[floor] = Config.StandsOpenPerFloor
	notify(player)
	return true, ("¡Piso %d desbloqueado!"):format(floor)
end

-- Desbloquea el siguiente estante de un piso (de a uno). Devuelve ok, mensaje.
function Economy.UnlockStand(player, floor)
	local data = datas[player]
	if not data or not isIndex(floor, Config.MaxFloors) then
		return false
	end
	local unlocked = data.FloorStands[floor]
	if unlocked <= 0 or unlocked >= Config.StandsPerFloor then
		return false
	end
	local cost = Config.GetStandUnlockCost(floor, unlocked + 1)
	if data.Money < cost then
		return false, ("Te faltan %s."):format(Config.FormatMoney(cost - data.Money))
	end
	data.Money -= cost
	data.FloorStands[floor] = unlocked + 1
	notify(player)
	return true, "¡Estante desbloqueado!"
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
