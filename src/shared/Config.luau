-- Configuración y fórmulas compartidas (servidor y cliente).
-- Todos los números de balance viven aquí para ajustarlos en la fase de balance.

local Config = {}

Config.MaxPlayers = 5 -- jugadores por servidor (cada uno con su base)
-- Administradores del juego (UserIds de Roblox). Pueden usar el panel de administrador.
-- Quien pruebe en Studio y el dueño del juego publicado también cuentan como admin.
Config.AdminUserIds = {
	3282659647, -- el dueño
}
-- SOLO EN STUDIO (pruebas): el primer jugador recibe esta base, la del centro, que queda
-- mas cerca de todo. En el juego publicado las bases se reparten en orden: 1, 2, 3...
Config.DevPreferredBase = 3
Config.NodeRespawn = 10 -- segundos hasta que vuelve a aparecer, para ti, un cristal que rompiste
-- Dinero para mostrar: signo de peso y número entero con comas (ej. $1,250).
function Config.FormatMoney(amount)
	local digits = tostring(math.floor(math.abs(amount) + 0.5))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	formatted = formatted:gsub("^,", "")
	return (if amount < 0 then "-$" else "$") .. formatted
end

Config.StartingMoney = 100
Config.InventorySize = 10 -- espacios de la mochila
Config.HotbarSize = 5 -- espacios visibles en el HUD normal

----------------------------------------------------------------------
-- Rarezas y minerales
----------------------------------------------------------------------

-- RequiredPickaxe: nivel mínimo de pico para poder sacar esa rareza.
Config.Rarities = {
	{ Id = "Common", Name = "Común", Color = Color3.fromRGB(190, 190, 205), Income = 3, RequiredPickaxe = 0 },
	{ Id = "Uncommon", Name = "Poco común", Color = Color3.fromRGB(120, 200, 255), Income = 9, RequiredPickaxe = 0 },
	{ Id = "Rare", Name = "Raro", Color = Color3.fromRGB(110, 215, 120), Income = 27, RequiredPickaxe = 1 },
	{ Id = "Epic", Name = "Épico", Color = Color3.fromRGB(185, 130, 255), Income = 81, RequiredPickaxe = 2 },
	{ Id = "Exotic", Name = "Exótico", Color = Color3.fromRGB(255, 120, 190), Income = 243, RequiredPickaxe = 3 },
	{ Id = "Legendary", Name = "Legendario", Color = Color3.fromRGB(255, 205, 70), Income = 729, RequiredPickaxe = 4 },
}

Config.RaritiesById = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesById[rarity.Id] = rarity
end

-- Value = créditos al vender en la tienda: más o menos 1 minuto de lo que el mineral
-- genera en un estante (3 veces más por cada rareza).
-- MinZone: primera zona donde puede aparecer. Dentro de cada rareza, mientras más profundo
-- vas, más variedad (y los minerales nuevos son un poco más valiosos).
Config.Minerals = {
	{ Id = "LunarRock", Name = "Roca lunar", Rarity = "Common", Family = "Normal", Value = 150, MinZone = 1 },
	{ Id = "Iron", Name = "Hierro", Rarity = "Common", Family = "Normal", Value = 180, MinZone = 1 },
	{ Id = "Copper", Name = "Cobre", Rarity = "Common", Family = "Normal", Value = 220, MinZone = 1 },
	{ Id = "Aluminium", Name = "Aluminio", Rarity = "Common", Family = "Normal", Value = 240, MinZone = 3 },
	{ Id = "LunarQuartz", Name = "Cuarzo lunar", Rarity = "Uncommon", Family = "Normal", Value = 480, MinZone = 1 },
	{ Id = "IceCrystal", Name = "Cristal helado", Rarity = "Uncommon", Family = "Normal", Value = 600, MinZone = 1 },
	{ Id = "MoonSapphire", Name = "Zafiro lunar", Rarity = "Uncommon", Family = "Normal", Value = 540, MinZone = 3 },
	{ Id = "SpaceAmber", Name = "Ámbar espacial", Rarity = "Uncommon", Family = "Normal", Value = 660, MinZone = 5 },
	{ Id = "Uranium", Name = "Uranio brillante", Rarity = "Rare", Family = "Radiactivo", Value = 1400, MinZone = 1 },
	{ Id = "RadioCrystal", Name = "Cristal radiactivo", Rarity = "Rare", Family = "Radiactivo", Value = 1850, MinZone = 2 },
	{ Id = "Thorium", Name = "Torio", Rarity = "Rare", Family = "Radiactivo", Value = 1600, MinZone = 5 },
	{ Id = "BlueIsotope", Name = "Isótopo azul", Rarity = "Rare", Family = "Radiactivo", Value = 2000, MinZone = 7 },
	{ Id = "Meteorite", Name = "Fragmento de meteorito", Rarity = "Epic", Family = "Extraterrestre", Value = 4200, MinZone = 4 },
	{ Id = "AlienCrystal", Name = "Cristal alienígena", Rarity = "Epic", Family = "Extraterrestre", Value = 5400, MinZone = 4 },
	{ Id = "CometShard", Name = "Fragmento de cometa", Rarity = "Epic", Family = "Extraterrestre", Value = 4700, MinZone = 7 },
	{ Id = "AlienOrb", Name = "Esfera alienígena", Rarity = "Epic", Family = "Extraterrestre", Value = 5800, MinZone = 9 },
	{ Id = "MutantSpores", Name = "Esporas mutantes", Rarity = "Exotic", Family = "Mutante", Value = 12500, MinZone = 7 },
	{ Id = "MutantCore", Name = "Núcleo mutante", Rarity = "Exotic", Family = "Mutante", Value = 16500, MinZone = 7 },
	{ Id = "MutantMold", Name = "Moho mutante", Rarity = "Exotic", Family = "Mutante", Value = 14000, MinZone = 9 },
	{ Id = "ChimeraGem", Name = "Gema quimera", Rarity = "Exotic", Family = "Mutante", Value = 17500, MinZone = 11 },
	{ Id = "MoonHeart", Name = "Corazón de la Luna", Rarity = "Legendary", Family = "Especial", Value = 38000, MinZone = 11 },
	{ Id = "UfoPiece", Name = "Pieza de ovni", Rarity = "Legendary", Family = "Especial", Value = 48000, MinZone = 11 },
	{ Id = "FallenStar", Name = "Estrella caída", Rarity = "Legendary", Family = "Especial", Value = 42000, MinZone = 12 },
	{ Id = "BlackHoleCore", Name = "Núcleo de agujero negro", Rarity = "Legendary", Family = "Especial", Value = 52000, MinZone = 13 },
	{ Id = "OriginCrystal", Name = "Cristal del origen", Rarity = "Legendary", Family = "Especial", Value = 56000, MinZone = 14 },
}

Config.MineralsById = {}
Config.MineralsByRarity = {}
for _, mineral in Config.Minerals do
	Config.MineralsById[mineral.Id] = mineral
	Config.MineralsByRarity[mineral.Rarity] = Config.MineralsByRarity[mineral.Rarity] or {}
	table.insert(Config.MineralsByRarity[mineral.Rarity], mineral)
end

-- Fusion: 3 minerales de la misma rareza (Raro o superior) dan 1 de la rareza siguiente.
Config.FusionCount = 3
Config.FusionMinRarity = 3 -- indice de "Raro" en Config.Rarities
function Config.GetFusionTarget(rarityId)
	local rarity = Config.RaritiesById[rarityId]
	if not rarity or rarity.Index < Config.FusionMinRarity then
		return nil
	end
	return Config.Rarities[rarity.Index + 1]
end

function Config.GetRarityColor(mineralId)
	local mineral = Config.MineralsById[mineralId]
	return mineral and Config.RaritiesById[mineral.Rarity].Color or Color3.fromRGB(190, 190, 205)
end

----------------------------------------------------------------------
-- Estantes de la fabrica: cada mineral que dejas en un estante genera creditos solo.
-- Income (por rareza) es creditos por segundo: el comun genera 3 por segundo y cada rareza
-- genera 3 veces mas que la anterior.
----------------------------------------------------------------------

Config.StandsPerFloor = 8
Config.MaxFloors = 5
Config.StandsOpenPerFloor = 4 -- cada piso comprado viene con 4 estantes ya desbloqueados
Config.FloorHeight = 30 -- altura entre pisos (studs)
Config.TotalStands = Config.MaxFloors * Config.StandsPerFloor

-- Costo de comprar cada piso (el piso 1 viene con la base). Valores a ajustar en el balance.
Config.FloorCosts = { 0, 200000, 1200000, 7000000, 40000000 }

-- Costo de desbloquear el estante `nth` (5 a 8) de un piso: se duplica con cada estante.
local STAND_UNLOCK_BASE = { 15000, 60000, 250000, 1000000, 4000000 }
function Config.GetStandUnlockCost(floor, nth)
	return STAND_UNLOCK_BASE[floor] * 2 ^ (nth - Config.StandsOpenPerFloor - 1)
end

-- Piso (1..) y puesto dentro del piso (1..8) de un estante, y a la inversa.
function Config.StandFloor(index)
	return (index - 1) // Config.StandsPerFloor + 1
end
function Config.StandSlot(index)
	return (index - 1) % Config.StandsPerFloor + 1
end

-- floorStands[f] = cuántos estantes tiene desbloqueados el piso f (0 = piso sin comprar).
function Config.IsStandUnlocked(floorStands, index)
	return (floorStands[Config.StandFloor(index)] or 0) >= Config.StandSlot(index)
end

function Config.CountFloors(floorStands)
	local count = 0
	for _, unlocked in floorStands do
		if unlocked > 0 then
			count += 1
		end
	end
	return count
end

Config.StandCapacitySeconds = 2 * 60 * 60 -- un estante junta como maximo 2 horas de ingresos

function Config.GetMineralIncome(mineralId)
	local mineral = Config.MineralsById[mineralId]
	return if mineral then Config.RaritiesById[mineral.Rarity].Income else 0
end

-- Renacimiento: solo se pierde el dinero. Cada renacimiento sube de forma permanente lo que
-- generan los estantes (BonusPerRebirth) y el siguiente cuesta más (Growth).
Config.Rebirth = {
	Max = 10,
	-- El costo es proporcional a lo que gana el jugador: "horas de su ingreso". El primero
	-- cuesta BaseHours horas de lo que generan sus estantes y cada renacimiento cuesta
	-- HoursGrowth veces más horas que el anterior. Un jugador nuevo paga poco; uno que ya
	-- gana mucho, mucho más. MinCost evita que sea gratis sin estantes.
	BaseHours = 1.5,
	HoursGrowth = 1.2,
	MinCost = 50000,
	BonusPerRebirth = 0.5, -- +50 % de ganancia en los estantes por renacimiento
}

-- Costo del siguiente renacimiento (nil si ya hizo todos). `data` es el perfil del jugador:
-- usa lo que generan sus estantes (o lo más que han generado: PeakIncome, así quitar minerales
-- no lo abarata) por el multiplicador que ya tiene.
function Config.GetRebirthCost(data)
	local done = data.Rebirths or 0
	local rebirth = Config.Rebirth
	if done >= rebirth.Max then
		return nil
	end
	local baseIncome = math.max(Config.GetTotalIncome(data), data.PeakIncome or 0)
	local income = baseIncome * Config.GetRebirthMultiplier(done)
	local seconds = rebirth.BaseHours * 3600 * rebirth.HoursGrowth ^ done
	return math.max(rebirth.MinCost, math.ceil(income * seconds))
end

-- Multiplicador de lo que generan los estantes con `done` renacimientos.
function Config.GetRebirthMultiplier(done)
	return 1 + Config.Rebirth.BonusPerRebirth * (done or 0)
end

-- Dinero acumulado en un estante desde `since` (os.time) hasta `now`. `multiplier` es el de
-- los renacimientos del jugador.
function Config.GetStandPending(mineralId, since, now, multiplier)
	if since <= 0 then
		return 0 -- sin hora de inicio válida no se acumula nada (evita cobrar el tope de golpe)
	end
	local seconds = math.clamp(now - since, 0, Config.StandCapacitySeconds)
	return seconds * Config.GetMineralIncome(mineralId) * (multiplier or 1)
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
Config.ZoneCount = 15
Config.MineHalfWidth = 150

-- Weights: probabilidad relativa por rareza, en el orden de Config.Rarities. Cada rareza
-- tiene una zona "central" donde es más común (Gauss con ancho ZoneSpread) y un factor de
-- rareza: mientras más profundo, más raros. Las dos primeras rarezas nunca desaparecen del
-- todo (siguen saliendo minerales normales aunque el jugador mejore).
local RARITY_CENTER = { 1, 3.5, 6.5, 9.5, 12.5, 15.5 } -- zona donde cada rareza es más común
local RARITY_SCARCITY = { 1, 0.8, 0.6, 0.45, 0.3, 0.15 }
local ZONE_SPREAD = 2.2

local function zoneWeights(zone)
	local weights = {}
	for index = 1, #RARITY_CENTER do
		local distance = (zone - RARITY_CENTER[index]) / ZONE_SPREAD
		local weight = math.exp(-distance * distance / 2) * RARITY_SCARCITY[index]
		if index <= 2 or zone > RARITY_CENTER[index] then
			-- Una rareza que ya "quedó atrás" sigue saliendo un poco (nunca desaparece del todo).
			weight = math.max(weight, if index <= 2 then 0.01 else 0.02)
		elseif weight < 0.01 then
			weight = 0
		end
		weights[index] = weight
	end
	return weights
end

Config.Zones = {}
for zone = 1, Config.ZoneCount do
	local t = (zone - 1) / (Config.ZoneCount - 1)
	local gray = math.floor(172 - 80 * t)
	Config.Zones[zone] = {
		Name = "Zona " .. zone,
		Color = Color3.fromRGB(gray, gray - 2, gray + 4),
		GemColor = Color3.fromHSV((0.35 + zone * 0.11) % 1, 0.55, 1),
		Weights = zoneWeights(zone),
	}
end

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

	-- Solo los minerales de esa rareza que ya pueden aparecer en esta zona.
	local available = {}
	for _, mineral in Config.MineralsByRarity[Config.Rarities[chosen].Id] do
		if mineral.MinZone <= zone then
			table.insert(available, mineral)
		end
	end
	if #available == 0 then
		available = Config.MineralsByRarity[Config.Rarities[chosen].Id]
	end
	return available[rng:NextInteger(1, #available)]
end

-- Mineral de un cristal para UN jugador. Es determinista: servidor y cliente obtienen
-- lo mismo con la misma semilla del cristal, el id del jugador y cuántas veces lo rompió.
function Config.GetNodeMineral(seed, userId, count, zone)
	local mixed = (seed * 73856093 + (userId % 1000003) * 19349663 + count * 83492791) % 2147483647
	return Config.RollNodeMineral(zone, Random.new(mixed))
end

-- Tiempo que hay que mantener la tecla para picar: más profundo y más raro = más largo.
Config.MineTime = {
	ZoneBase = {}, -- segundos por zona (1 s en la zona 1, +0,25 s por zona)
	RarityFactor = { 1, 1.2, 1.6, 2.2, 3, 4 }, -- multiplicador por rareza (orden de Config.Rarities)
	StrengthReduction = 0.04, -- cada nivel de fuerza lo acorta un 4 %
	MinStrengthFactor = 0.4, -- como mínimo queda el 40 % del tiempo
	MissingPickaxePenalty = 0.5, -- +50 % de tiempo por cada nivel de pico que te falta
}

for zone = 1, Config.ZoneCount do
	Config.MineTime.ZoneBase[zone] = 1 + 0.25 * (zone - 1)
end

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
	Speed = { Label = "Velocidad", BaseCost = 2500, Growth = 1.65, MaxLevel = 20 },
	Strength = { Label = "Fuerza", BaseCost = 5000, Growth = 1.7, MaxLevel = 15 },
	Pickaxe = { Label = "Pico", BaseCost = 15000, Growth = 4.5, MaxLevel = 6 },
}
-- Productos de Robux (tiendas del lado derecho). Id = 0 significa "aun no configurado":
-- se muestra "Proximamente". Cuando se creen los pases / productos en Roblox, se pone su Id.
Config.RobuxProducts = {
	X2 = {
		Name = "Doble de dinero",
		Description = "Ganas el doble de dinero en todo: ventas y estantes. ¡Para siempre!",
		Kind = "Pass",
		Id = 2089265407,
	},
	Boots = {
		Name = "Botas lunares VIP",
		Description = "Corres un 25 % más rápido, para siempre. ¡Escapa mejor del Alien!",
		Kind = "Pass",
		Id = 2089157257,
	},
	Shield = {
		Name = "Escudo anti-Alien",
		Description = "Si el Alien te atrapa, conservas tu mineral. Se gasta al usarlo.",
		Kind = "Product",
		Id = 3732361306,
	},
	Credits = {
		Name = "Paquetes de dinero",
		Description = "Te da dinero al instante: lo que tus estantes generan en 30 minutos (mínimo $25,000).",
		Kind = "Product",
		Id = 3732361539,
	},
}

Config.UpgradeOrder = { "Speed", "Strength", "Pickaxe" }

function Config.GetUpgradeCost(kind, level)
	local upgrade = Config.Upgrades[kind]
	return math.ceil(upgrade.BaseCost * upgrade.Growth ^ level)
end

-- Velocidad al caminar. Las botas VIP (Robux) la suben un 25 %.
function Config.GetWalkSpeed(level, hasBoots)
	return (16 + 1.2 * level) * (if hasBoots then 1.25 else 1)
end

-- Multiplicador de todo el dinero que ganas (ventas y estantes): x2 con el pase de Robux.
function Config.GetMoneyMultiplier(data)
	return if data and data.Passes and data.Passes.X2 then 2 else 1
end

-- Paquete de dinero (Robux): equivale a Hours horas (0,5 = 30 minutos) de lo que ya generan tus estantes, con un
-- mínimo para quien aún no tiene.
Config.CreditsPack = { Hours = 0.5, Min = 25000 }

----------------------------------------------------------------------
-- Ovni
----------------------------------------------------------------------

-- Cada zona pide un nivel mínimo de velocidad. El ovni va un poco más rápido que un jugador
-- con ese nivel mínimo (ver Margin): con el nivel mínimo o más no te alcanza, con menos puede
-- alcanzarte, y mientras menos nivel tengas, antes te atrapa. Un jugador con nivel máximo
-- (40 de velocidad) siempre se salva.
Config.ZoneMinSpeedLevel = { 0, 2, 3, 4, 6, 7, 9, 10, 11, 13, 14, 16, 17, 19, 20 }

Config.Ufo = {
	Margin = 3, -- studs/s que el ovni supera al jugador con el nivel mínimo de la zona
	SpawnDelay = 2, -- segundos entre sacar el mineral y que aparezca
	SpawnDistance = 50, -- studs detrás del jugador (hacia el fondo de la mina)
	HoverHeight = 8, -- altura sobre el jugador
	CatchDistance = 4, -- distancia horizontal a la que atrapa
}

-- Velocidad del ovni según la zona en que va el jugador.
function Config.GetUfoSpeed(depth)
	local minLevel = Config.ZoneMinSpeedLevel[Config.GetZone(depth)]
	return Config.GetWalkSpeed(minLevel) + Config.Ufo.Margin
end

return Config
