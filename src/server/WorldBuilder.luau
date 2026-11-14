-- Construye el mundo de la Luna (estilo colorido y amigable): iluminación, suelo
-- pastel, la base con la tienda, la entrada con la línea de inicio y la mina
-- dividida en zonas con paredes, arcos y carteles de profundidad.
-- Es determinista (misma semilla = mismo mundo).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildingModels = require(ReplicatedStorage.Shared.BuildingModels)

local WorldBuilder = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WHITE = c(250, 247, 255)
local PINK = c(255, 170, 190)
local WALL = c(205, 195, 232)
local GROUND = c(205, 195, 235)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local PASTELS = {
	c(255, 170, 190),
	c(170, 220, 255),
	c(255, 225, 150),
	c(190, 235, 190),
	c(210, 190, 255),
	c(255, 200, 160),
}

local MINE_LENGTH = Config.ZoneLength * Config.ZoneCount
local HALF_WIDTH = Config.MineHalfWidth
local BASE_CENTER = Vector3.new(-60, 0, 0)
local SHOP_POSITION = Vector3.new(-60, 0, -32)

WorldBuilder.BaseCenter = BASE_CENTER
WorldBuilder.ReturnPosition = Vector3.new(-40, 4, 0) -- adonde vuelve el jugador si pierde el mineral

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Cartel con texto. `cframe` orienta la cara frontal (-Z local).
local function board(parent, cframe, size, text, background, textColor)
	local p = part({ Name = "Board", Size = size, CFrame = cframe, Color = background }, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.Parent = gui
	return p
end

-- Mira hacia -X (hacia la base), de modo que quien viene de la base lee el cartel.
local function facingBase(position)
	return CFrame.lookAt(position, position + Vector3.new(-1, 0, 0))
end

----------------------------------------------------------------------
-- Entorno
----------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = c(150, 145, 185)
	Lighting.OutdoorAmbient = c(165, 155, 200)
	Lighting.FogEnd = 100000

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Offset = 0.25
	atmosphere.Color = c(205, 190, 255)
	atmosphere.Decay = c(255, 205, 230)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
end

local function buildGround(world, rng)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Color = GROUND
		baseplate.Material = Enum.Material.SmoothPlastic
	end

	-- La baseplate de Studio no cubre toda la mina: suelo grande por debajo.
	part({
		Name = "MoonGround",
		Size = Vector3.new(MINE_LENGTH + 900, 20, 1200),
		Position = Vector3.new(MINE_LENGTH / 2 - 100, -10.15, 0),
		Color = GROUND,
		CanCollide = true,
	}, world)

	-- Cráteres suaves fuera de la mina y de la base.
	for i = 1, 45 do
		local radius = rng:NextNumber(8, 28)
		local x = rng:NextNumber(-380, MINE_LENGTH + 380)
		local z = rng:NextNumber(-500, 500)
		local insideMine = x > -40 and x < MINE_LENGTH + 40 and math.abs(z) < HALF_WIDTH + radius + 30
		local nearBase = (Vector3.new(x, 0, z) - BASE_CENTER).Magnitude < 90 + radius
		if not insideMine and not nearBase then
			part({
				Name = "Crater" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, radius * 2, radius * 2),
				CFrame = CFrame.new(x, 0.55, z) * VERTICAL,
				Color = c(188, 177, 222),
			}, world)
		end
	end
end

----------------------------------------------------------------------
-- Base y tienda
----------------------------------------------------------------------

local function buildBase(world)
	local base = Instance.new("Folder")
	base.Name = "Base"
	base.Parent = world

	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 96, 96),
		CFrame = CFrame.new(BASE_CENTER.X, 0.25, BASE_CENTER.Z) * VERTICAL,
		Color = c(250, 244, 255),
		CanCollide = true,
	}, base)
	part({
		Name = "PlazaRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 101, 101),
		CFrame = CFrame.new(BASE_CENTER.X, 0.2, BASE_CENTER.Z) * VERTICAL,
		Color = PINK,
	}, base)

	-- Farolas redondas.
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local x = BASE_CENTER.X + math.cos(angle) * 44
		local z = BASE_CENTER.Z + math.sin(angle) * 44
		part({
			Name = "LampPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9, 0.9, 0.9),
			CFrame = CFrame.new(x, 4.5, z) * VERTICAL,
			Color = WHITE,
		}, base)
		part({
			Name = "LampBall",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.2,
			Position = Vector3.new(x, 10, z),
			Color = c(255, 240, 170),
		}, base)
	end

	-- Punto de aparición dentro de la base.
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Parent = workspace
	end
	spawn.Position = Vector3.new(BASE_CENTER.X, 1, BASE_CENTER.Z + 10)

	-- Tienda (el frente mira a +Z, hacia la plaza).
	local shop = BuildingModels.Shop(CFrame.new(SHOP_POSITION.X, 0.5, SHOP_POSITION.Z) * CFrame.Angles(0, math.pi, 0))
	shop.Parent = base

	local promptPart = part({
		Name = "ShopPrompt",
		Size = Vector3.new(8, 6, 2),
		Position = Vector3.new(SHOP_POSITION.X, 3, SHOP_POSITION.Z + 8),
		Transparency = 1,
	}, base)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir tienda"
	prompt.ObjectText = "Tienda lunar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	return prompt
end

----------------------------------------------------------------------
-- Mina
----------------------------------------------------------------------

-- Arco con cartel que cruza el camino; `width` es la separación entre postes.
local function arch(parent, x, width, text, color)
	for _, z in { -width / 2, width / 2 } do
		part({
			Name = "ArchPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 3, 3),
			CFrame = CFrame.new(x, 11, z) * VERTICAL,
			Color = WHITE,
			CanCollide = true,
		}, parent)
		part({
			Name = "ArchBall",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4.4,
			Position = Vector3.new(x, 22.5, z),
			Color = color,
		}, parent)
	end
	board(parent, facingBase(Vector3.new(x, 19, 0)), Vector3.new(width - 4, 7, 1), text, color, WHITE)
end

local function buildMine(world)
	local mine = Instance.new("Folder")
	mine.Name = "Mine"
	mine.Parent = world

	-- Suelo de cada zona con su color.
	for zone = 1, Config.ZoneCount do
		part({
			Name = "Zone" .. zone .. "Floor",
			Size = Vector3.new(Config.ZoneLength, 0.3, HALF_WIDTH * 2),
			Position = Vector3.new((zone - 0.5) * Config.ZoneLength, 0.15, 0),
			Color = Config.Zones[zone].Color,
		}, mine)
	end

	-- Línea de inicio: franjas alternadas rosa y amarillo.
	local stripe = 10
	for i = 0, (HALF_WIDTH * 2) / stripe - 1 do
		part({
			Name = "StartLine",
			Size = Vector3.new(3, 0.45, stripe),
			Position = Vector3.new(0, 0.225, -HALF_WIDTH + stripe / 2 + i * stripe),
			Color = if i % 2 == 0 then c(255, 235, 120) else PINK,
		}, mine)
	end

	-- Paredes de roca pastel a los lados y al fondo.
	for _, z in { -HALF_WIDTH - 5, HALF_WIDTH + 5 } do
		part({
			Name = "Wall",
			Size = Vector3.new(MINE_LENGTH + 20, 24, 10),
			Position = Vector3.new(MINE_LENGTH / 2, 12, z),
			Color = WALL,
			CanCollide = true,
		}, mine)
		for x = 0, MINE_LENGTH, 40 do
			part({
				Name = "Boulder",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 16,
				Position = Vector3.new(x, 24, z),
				Color = PASTELS[(x / 40) % #PASTELS + 1],
			}, mine)
		end
	end
	part({
		Name = "EndWall",
		Size = Vector3.new(10, 24, HALF_WIDTH * 2 + 20),
		Position = Vector3.new(MINE_LENGTH + 5, 12, 0),
		Color = WALL,
		CanCollide = true,
	}, mine)

	-- Arco de entrada y arcos al inicio de cada zona.
	arch(mine, 0, 70, "MINA LUNAR", c(255, 140, 170))
	for zone = 2, Config.ZoneCount do
		arch(mine, (zone - 1) * Config.ZoneLength, 70, Config.Zones[zone].Name:upper(), Config.Zones[zone].GemColor)
	end

	-- Carteles de profundidad cada 100 studs.
	for depth = 100, MINE_LENGTH, 100 do
		part({
			Name = "MarkerPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 0.9, 0.9),
			CFrame = CFrame.new(depth, 3.5, -HALF_WIDTH + 12) * VERTICAL,
			Color = WHITE,
		}, mine)
		board(mine, facingBase(Vector3.new(depth, 8, -HALF_WIDTH + 12)), Vector3.new(7, 3, 0.5), depth .. " m", WHITE, c(70, 50, 120))
	end
end

-- Construye el mundo y devuelve el ProximityPrompt de la tienda.
function WorldBuilder.Build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local rng = Random.new(1337)
	setupLighting()
	buildGround(world, rng)
	buildMine(world)
	local shopPrompt = buildBase(world)

	return {
		ShopPrompt = shopPrompt,
		ShopPosition = Vector3.new(SHOP_POSITION.X, 3, SHOP_POSITION.Z + 8),
	}
end

return WorldBuilder
