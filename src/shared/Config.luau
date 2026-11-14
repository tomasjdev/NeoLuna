-- Configuración y fórmulas compartidas (servidor y cliente).
-- Todos los números de balance viven aquí para ajustarlos en la fase de balance.

local Config = {}

Config.StartingMoney = 20
Config.InventorySize = 10 -- espacios de la mochila
Config.HotbarSize = 5 -- espacios visibles en el HUD normal

----------------------------------------------------------------------
-- Rarezas y minerales
----------------------------------------------------------------------

-- RequiredPickaxe: nivel mínimo de pico para poder sacar esa rareza.
Config.Rarities = {
	{ Id = "Common", Name = "Común", Color = Color3.fromRGB(190, 190, 205), RequiredPickaxe = 0 },
	{ Id = "Uncommon", Name = "Poco común", Color = Color3.fromRGB(120, 200, 255), RequiredPickaxe = 0 },
	{ Id = "Rare", Name = "Raro", Color = Color3.fromRGB(110, 215, 120), RequiredPickaxe = 1 },
	{ Id = "Epic", Name = "Épico", Color = Color3.fromRGB(185, 130, 255), RequiredPickaxe = 2 },
	{ Id = "Exotic", Name = "Exótico", Color = Color3.fromRGB(255, 120, 190), RequiredPickaxe = 3 },
	{ Id = "Legendary", Name = "Legendario", Color = Color3.fromRGB(255, 205, 70), RequiredPickaxe = 4 },
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
-- Mina y zonas
----------------------------------------------------------------------

-- La profundidad es la distancia (en studs) a la línea de inicio, sobre el eje X.
Config.ZoneLength = 200
Config.ZoneCount = 5
Config.MineHalfWidth = 150

-- Weights: probabilidad relativa por rareza, en el orden de Config.Rarities.
Config.Zones = {
	{ Name = "Zona 1", Color = Color3.fromRGB(190, 235, 190), GemColor = Color3.fromRGB(120, 210, 140), Weights = { 80, 18, 2, 0, 0, 0 } },
	{ Name = "Zona 2", Color = Color3.fromRGB(170, 220, 255), GemColor = Color3.fromRGB(100, 175, 255), Weights = { 55, 30, 13, 2, 0, 0 } },
	{ Name = "Zona 3", Color = Color3.fromRGB(210, 190, 255), GemColor = Color3.fromRGB(165, 125, 255), Weights = { 30, 30, 28, 10, 2, 0 } },
	{ Name = "Zona 4", Color = Color3.fromRGB(255, 200, 230), GemColor = Color3.fromRGB(255, 120, 190), Weights = { 15, 20, 30, 24, 10, 1 } },
	{ Name = "Zona 5", Color = Color3.fromRGB(255, 225, 150), GemColor = Color3.fromRGB(255, 190, 60), Weights = { 5, 10, 25, 30, 25, 5 } },
}

Config.PickaxeLuck = 0.2 -- cada nivel de pico sube el peso de las rarezas altas

function Config.GetZone(depth)
	return math.clamp(math.floor(math.max(depth, 0) / Config.ZoneLength) + 1, 1, Config.ZoneCount)
end

-- Sortea un mineral según la profundidad y el nivel del pico. `rng` es un Random.
function Config.RollMineral(depth, pickaxeLevel, rng)
	local zone = Config.Zones[Config.GetZone(depth)]
	local weights, total = {}, 0
	for index, rarity in Config.Rarities do
		local weight = zone.Weights[index]
		if pickaxeLevel < rarity.RequiredPickaxe then
			weight = 0
		else
			weight *= 1 + Config.PickaxeLuck * pickaxeLevel * (index - 1)
		end
		weights[index] = weight
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

----------------------------------------------------------------------
-- Mejoras (se compran con dinero en la tienda)
----------------------------------------------------------------------

-- Coste = BaseCost * Growth ^ nivel actual.
Config.Upgrades = {
	Speed = { Label = "Velocidad", BaseCost = 50, Growth = 1.45, MaxLevel = 20 },
	Strength = { Label = "Fuerza", BaseCost = 60, Growth = 1.5, MaxLevel = 15 },
	Pickaxe = { Label = "Pico", BaseCost = 100, Growth = 1.9, MaxLevel = 6 },
}
Config.UpgradeOrder = { "Speed", "Strength", "Pickaxe" }

function Config.GetUpgradeCost(kind, level)
	local upgrade = Config.Upgrades[kind]
	return math.ceil(upgrade.BaseCost * upgrade.Growth ^ level)
end

function Config.GetWalkSpeed(level)
	return 16 + 1.2 * level
end

-- Alcance del lanzamiento del pico, en studs.
function Config.GetThrowRange(level)
	return 40 + 8 * level
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
