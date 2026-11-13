-- Configuración y fórmulas compartidas (servidor y cliente).
-- Todos los números de balance viven aquí para ajustarlos en la Fase 5.

local Config = {}

Config.StartingCredits = 50
Config.RegolithValue = 1 -- créditos por unidad de regolito entregada
Config.MaxDrones = 20

Config.Drone = {
	BaseSpeed = 16, -- studs/s
	BaseCapacity = 5, -- unidades por viaje
	MiningTime = 1.5, -- segundos extrayendo
}

-- Coste = BaseCost * Growth ^ nivel. PerLevel es el bonus por nivel.
Config.Upgrades = {
	Drone = { Label = "Comprar dron", BaseCost = 25, Growth = 1.35 },
	Capacity = { Label = "Capacidad", BaseCost = 40, Growth = 1.5, PerLevel = 2 }, -- +2 unidades
	Speed = { Label = "Velocidad", BaseCost = 40, Growth = 1.5, PerLevel = 0.2 }, -- +20% de la base
}

Config.UpgradeOrder = { "Drone", "Capacity", "Speed" }

function Config.GetSpeed(level)
	return Config.Drone.BaseSpeed * (1 + Config.Upgrades.Speed.PerLevel * level)
end

function Config.GetCapacity(level)
	return Config.Drone.BaseCapacity + Config.Upgrades.Capacity.PerLevel * level
end

-- state = { Credits, Drones, Capacity, Speed }
function Config.GetCost(kind, state)
	local up = Config.Upgrades[kind]
	local level = if kind == "Drone" then state.Drones - 1 else state[kind]
	return math.ceil(up.BaseCost * up.Growth ^ level)
end

return Config
