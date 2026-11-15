-- Configuración y fórmulas compartidas (servidor y cliente).
-- Todos los números de balance viven aquí para ajustarlos en la fase de balance.

local Config = {}

Config.MaxPlayers = 5 -- jugadores por servidor (cada uno con su base)
-- SOLO EN STUDIO (pruebas): el primer jugador recibe esta base, la del centro, que queda
-- mas cerca de todo. En el juego publicado las bases se reparten en orden: 1, 2, 3...
Config.DevPreferredBase = 3
Config.NodeRespawn = 10 -- segundos hasta que vuelve a aparecer, para ti, un cristal que rompiste
Config.StartingMoney = 20
Config.InventorySize = 10 -- espacios de la mochila
Config.HotbarSize = 5 -- espacios visibles en el HUD normal

----------------------------------------------------------------------
-- Rarezas y minerales
----------------------------------------------------------------------

-- RequiredPickaxe: nivel mínimo de pico para poder sacar esa rareza.
Config.Rarities = {
	{ Id = "Common", Name = "Común", Color = Color3.fromRGB(190, 190, 205), Income = 0.02, RequiredPickaxe = 0 },
	{ Id = "Uncommon", Name = "Poco común", Color = Color3.fromRGB(120, 200, 255), Income = 0.08, RequiredPickaxe = 0 },
	{ Id = "Rare", Name = "Raro", Color = Color3.fromRGB(110, 215, 120), Income = 0.3, RequiredPickaxe = 1 },
	{ Id = "Epic", Name = "Épico", Color = Color3.fromRGB(185, 130, 255), Income = 1.2, RequiredPickaxe = 2 },
	{ Id = "Exotic", Name = "Exótico", Color = Color3.fromRGB(255, 120, 190), Income = 5, RequiredPickaxe = 3 },
	{ Id = "Legendary", Name = "Legendario", Color = Color3.fromRGB(255, 205, 70), Income = 20, RequiredPickaxe = 4 },
}

Config.RaritiesById = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesById[rarity.Id] = rarity
end

-- Value = créditos al vender en la tienda.
Config.Minerals = {
	{ Id = "LunarRock", Name = "Roca lunar", Rarity = "Common", Family = "Normal", Value = 2 },
	{ Id = "Iron", Name = "Hierro", Rarity = "Common", Family = "Normal", Value = 3 },
	{ Id = "Copper", Name = "Cobre", Rarity = "Common", Family = "Normal", Value = 4 },
	{ Id = "LunarQuartz", Name = "Cuarzo lunar", Rarity = "Uncommon", Family = "Normal", Value = 8 },
	{ Id = "IceCrystal", Name = "Cristal helado", Rarity = "Uncommon", Family = "Normal", Value = 10 },
	{ Id = "Uranium", Name = "Uranio brillante", Rarity = "Rare", Family = "Radiactivo", Value = 30 },
	{ Id = "RadioCrystal", Name = "Cristal radiactivo", Rarity = "Rare", Family = "Radiactivo", Value = 40 },
	{ Id = "Meteorite", Name = "Fragmento de meteorito", Rarity = "Epic", Family = "Extraterrestre", Value = 120 },
	{ Id = "AlienCrystal", Name = "Cristal alienígena", Rarity = "Epic", Family = "Extraterrestre", Value = 150 },
	{ Id = "MutantSpores", Name = "Esporas mutantes", Rarity = "Exotic", Family = "Mutante", Value = 450 },
	{ Id = "MutantCore", Name = "Núcleo mutante", Rarity = "Exotic", Family = "Mutante", Value = 600 },
	{ Id = "MoonHeart", Name = "Corazón de la Luna", Rarity = "Legendary", Family = "Especial", Value = 2000 },
	{ Id = "UfoPiece", Name = "Pieza de ovni", Rarity = "Legendary", Family = "Especial", Value = 2500 },
}

Config.MineralsById = {}
Config.MineralsByRarity = {}
for _, mineral in Config.Minerals do
	Config.MineralsById[mineral.Id] = mineral
	Config.MineralsByRarity[mineral.Rarity] = Config.MineralsByRarity[mineral.Rarity] or {}
	table.insert(Config.MineralsByRarity[mineral.Rarity], mineral)
end

function Config.GetRarityColor(mineralId)
	local mineral = Config.MineralsById[mineralId]
	return mineral and Config.RaritiesById[mineral.Rarity].Color or Color3.fromRGB(190, 190, 205)
end

----------------------------------------------------------------------
-- Estantes de la fabrica: cada mineral que dejas en un estante genera creditos solo.
-- Income (por rareza) es creditos por segundo; cada rareza genera 4 veces mas que la anterior.
----------------------------------------------------------------------

Config.StandsPerFloor = 8
Config.StandCapacitySeconds = 2 * 60 * 60 -- un estante junta como maximo 2 horas de ingresos

function Config.GetMineralIncome(mineralId)
	local mineral = Config.MineralsById[mineralId]
	return if mineral then Config.RaritiesById[mineral.Rarity].Income else 0
end

-- Creditos acumulados en un estante desde `since` (os.time) hasta `now`.
function Config.GetStandPending(mineralId, since, now)
	local seconds = math.clamp(now - since, 0, Config.StandCapacitySeconds)
	return seconds * Config.GetMineralIncome(mineralId)
end

-- Creditos por segundo de todos los estantes ocupados. data.Stands = { [i] = mineralId | "" }.
function Config.GetTotalIncome(data)
	local total = 0
	for _, mineralId in data.Stands or {} do
		if mineralId ~= "" then
			total += Config.GetMineralIncome(mineralId)
		end
	end
	return total
end

----------------------------------------------------------------------
-- Mina y zonas
----------------------------------------------------------------------

-- La profundidad es la distancia (en studs) a la línea de inicio, sobre el eje X.
Config.ZoneLength = 200
Config.ZoneCount = 5
Config.MineHalfWidth = 150

-- Weights: probabilidad relativa por rareza, en el orden de Config.Rarities.
Config.Zones = {
	{ Name = "Zona 1", Color = Color3.fromRGB(172, 170, 166), GemColor = Color3.fromRGB(120, 210, 140), Weights = { 80, 18, 2, 0, 0, 0 } },
	{ Name = "Zona 2", Color = Color3.fromRGB(158, 156, 156), GemColor = Color3.fromRGB(100, 175, 255), Weights = { 55, 30, 13, 2, 0, 0 } },
	{ Name = "Zona 3", Color = Color3.fromRGB(144, 142, 148), GemColor = Color3.fromRGB(165, 125, 255), Weights = { 30, 30, 28, 10, 2, 0 } },
	{ Name = "Zona 4", Color = Color3.fromRGB(130, 128, 136), GemColor = Color3.fromRGB(255, 120, 190), Weights = { 15, 20, 30, 24, 10, 1 } },
	{ Name = "Zona 5", Color = Color3.fromRGB(116, 112, 124), GemColor = Color3.fromRGB(255, 190, 60), Weights = { 5, 10, 25, 30, 25, 5 } },
}

function Config.GetZone(depth)
	return math.clamp(math.floor(math.max(depth, 0) / Config.ZoneLength) + 1, 1, Config.ZoneCount)
end

-- Sortea el mineral de un nodo al aparecer, según los pesos de su zona. `rng` es un Random.
-- El pico no cambia el sorteo: decide qué nodos puede romper (RequiredPickaxe).
function Config.RollNodeMineral(zone, rng)
	local weights = Config.Zones[zone].Weights
	local total = 0
	for _, weight in weights do
		total += weight
	end

	local roll = rng:NextNumber() * total
	local chosen = 1
	for index = 1, #Config.Rarities do
		roll -= weights[index]
		if roll <= 0 and weights[index] > 0 then
			chosen = index
			break
		end
	end

	local options = Config.MineralsByRarity[Config.Rarities[chosen].Id]
	return options[rng:NextInteger(1, #options)]
end

-- Mineral de un cristal para UN jugador. Es determinista: servidor y cliente obtienen
-- lo mismo con la misma semilla del cristal, el id del jugador y cuántas veces lo rompió.
function Config.GetNodeMineral(seed, userId, count, zone)
	local mixed = (seed * 73856093 + (userId % 1000003) * 19349663 + count * 83492791) % 2147483647
	return Config.RollNodeMineral(zone, Random.new(mixed))
end

-- Tiempo que hay que mantener la tecla para picar: más profundo y más raro = más largo.
Config.MineTime = {
	ZoneBase = { 1.0, 1.4, 1.8, 2.2, 2.6 }, -- segundos por zona
	RarityFactor = { 1, 1.2, 1.6, 2.2, 3, 4 }, -- multiplicador por rareza (orden de Config.Rarities)
	StrengthReduction = 0.04, -- cada nivel de fuerza lo acorta un 4 %
	MinStrengthFactor = 0.4, -- como mínimo queda el 40 % del tiempo
	MissingPickaxePenalty = 0.5, -- +50 % de tiempo por cada nivel de pico que te falta
}

function Config.GetStrengthFactor(level)
	return math.max(Config.MineTime.MinStrengthFactor, 1 - Config.MineTime.StrengthReduction * level)
end

-- Niveles de pico que le faltan al jugador para este mineral (0 si ya basta).
function Config.GetMissingPickaxe(pickaxeLevel, rarityId)
	return math.max(0, Config.RaritiesById[rarityId].RequiredPickaxe - pickaxeLevel)
end

-- Sin el pico adecuado se puede picar igual, pero tarda mucho más.
function Config.GetMineTime(strengthLevel, pickaxeLevel, zone, rarityId)
	local mineTime = Config.MineTime
	local rarityIndex = Config.RaritiesById[rarityId].Index
	local penalty = 1 + mineTime.MissingPickaxePenalty * Config.GetMissingPickaxe(pickaxeLevel, rarityId)
	return mineTime.ZoneBase[zone]
		* mineTime.RarityFactor[rarityIndex]
		* Config.GetStrengthFactor(strengthLevel)
		* penalty
end

----------------------------------------------------------------------
-- Mejoras (se compran con dinero en la tienda)
----------------------------------------------------------------------

-- Coste = BaseCost * Growth ^ nivel actual.
Config.Upgrades = {
	Speed = { Label = "Velocidad", BaseCost = 50, Growth = 1.45, MaxLevel = 20 },
	Strength = { Label = "Fuerza", BaseCost = 60, Growth = 1.5, MaxLevel = 15 },
	Pickaxe = { Label = "Pico", BaseCost = 100, Growth = 1.9, MaxLevel = 6 },
}
-- Productos de Robux (tiendas del lado derecho). Id = 0 significa "aun no configurado":
-- se muestra "Proximamente". Cuando se creen los pases / productos en Roblox, se pone su Id.
Config.RobuxProducts = {
	X2 = {
		Name = "Doble de créditos",
		Description = "Ganas el doble de créditos al vender cada mineral. ¡Para siempre!",
		Kind = "Pass",
		Id = 0,
	},
	Boots = {
		Name = "Botas lunares VIP",
		Description = "Corres un 25 % más rápido, para siempre. ¡Escapa mejor del Alien!",
		Kind = "Pass",
		Id = 0,
	},
	Shield = {
		Name = "Escudo anti-Alien",
		Description = "Si el Alien te atrapa, conservas tu mineral. Se gasta al usarlo.",
		Kind = "Product",
		Id = 0,
	},
	Credits = {
		Name = "Paquetes de créditos",
		Description = "Créditos para comprar mejoras al instante.",
		Kind = "Product",
		Id = 0,
	},
}

Config.UpgradeOrder = { "Speed", "Strength", "Pickaxe" }

function Config.GetUpgradeCost(kind, level)
	local upgrade = Config.Upgrades[kind]
	return math.ceil(upgrade.BaseCost * upgrade.Growth ^ level)
end

function Config.GetWalkSpeed(level)
	return 16 + 1.2 * level
end

----------------------------------------------------------------------
-- Ovni
----------------------------------------------------------------------

Config.Ufo = {
	BaseSpeed = 12, -- studs/s en la línea de inicio
	DepthFactor = 0.0125, -- studs/s extra por stud de profundidad
	SpawnDelay = 2, -- segundos entre sacar el mineral y que aparezca
	SpawnDistance = 90, -- studs detrás del jugador (hacia el fondo de la mina)
	HoverHeight = 8, -- altura sobre el jugador
	CatchDistance = 4, -- distancia horizontal a la que atrapa
}

function Config.GetUfoSpeed(depth)
	return Config.Ufo.BaseSpeed + Config.Ufo.DepthFactor * math.max(depth, 0)
end

return Config
