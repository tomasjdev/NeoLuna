-- Construye el mundo de la Luna (estilo realista): cielo negro con estrellas y la
-- Tierra, suelo de regolito gris con cráteres y rocas, colinas lejanas, la base
-- con la tienda y la mina dividida en zonas con paredes, arcos y carteles.
-- Es determinista (misma semilla = mismo mundo).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildingModels = require(ReplicatedStorage.Shared.BuildingModels)

local WorldBuilder = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local REGOLITH = c(158, 156, 154)
local ROCK_DARK = c(92, 90, 94)
local STEEL = c(150, 155, 165)
local PANEL_DARK = c(38, 42, 52)
local WHITE = c(235, 235, 240)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local MINE_LENGTH = Config.ZoneLength * Config.ZoneCount
local HALF_WIDTH = Config.MineHalfWidth
-- Zona de bases (hasta Config.MaxPlayers, en fila), plaza comun y tiendas junto a la entrada.
local BASES_X = -145
local BASE_SPACING = 75
local BASE_HALF = 32 -- cada base mide 64 x 64
local PLAZA_CENTER = Vector3.new(-70, 0, 0)
local PLAZA_RADIUS = 35
local SHOP_X = -16 -- pegadas a la linea de inicio de la mina (x = 0)
local SHOP_FIRST_Z = 60 -- la primera tienda de cada lado
local SHOP_SPACING = 26 -- separacion entre tiendas
local BASE_COLORS = {
	c(235, 120, 120),
	c(120, 170, 235),
	c(120, 200, 140),
	c(235, 200, 100),
	c(190, 140, 230),
}
local WORLD_CENTER = Vector3.new(MINE_LENGTH / 2 - 100, 0, 0)
local MOON_GRAVITY = 55 -- la Tierra es 196.2; menos gravedad = saltos más largos y flotantes

WorldBuilder.ReturnPosition = Vector3.new(-45, 4, 0) -- adonde vuelve el jugador si pierde el mineral

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

local function gray(rng, low, high)
	local v = rng:NextInteger(low, high)
	return c(v, v - 2, v + 2)
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
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor
	label.Parent = gui
	return p
end

-- Mira hacia -X (hacia la base), de modo que quien viene de la base lee el cartel.
local function facingBase(position)
	return CFrame.lookAt(position, position + Vector3.new(-1, 0, 0))
end

----------------------------------------------------------------------
-- Cielo y luz
----------------------------------------------------------------------

local function setupLighting()
	-- Noche cerrada = cielo negro con estrellas; el brillo sale de la luz ambiente.
	Lighting.ClockTime = 0
	Lighting.Brightness = 3
	Lighting.Ambient = c(135, 135, 145)
	Lighting.OutdoorAmbient = c(150, 150, 160)
	Lighting.ExposureCompensation = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 1e6

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 6000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.3
	bloom.Parent = Lighting

	workspace.Gravity = MOON_GRAVITY
end

-- Disco dibujado con interfaz, visible aunque la pieza sea invisible.
local function skyPanel(world, name, position, size, canvas, build)
	local panel = part({
		Name = name,
		Size = Vector3.new(size, size, 1),
		CFrame = CFrame.lookAt(position, WORLD_CENTER + Vector3.new(0, 20, 0)),
		Transparency = 1,
	}, world)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(canvas, canvas)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	pcall(function()
		gui.MaxDistance = 1e5 -- que se vea desde toda la mina
	end)
	gui.Parent = panel
	build(gui, canvas)
end

local function circle(parent, center, diameter, color, transparency)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(center.X, center.Y)
	frame.Size = UDim2.fromScale(diameter, diameter)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function blob(parent, center, width, height, rotation, color, transparency)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(center.X, center.Y)
	frame.Size = UDim2.fromScale(width, height)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.45, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- La Tierra: océano azul, continentes, nubes, brillo atmosférico y sombra de noche.
local function buildEarth(world)
	local position = Vector3.new(MINE_LENGTH + 500, 470, 40)
	skyPanel(world, "Earth", position, 340, 1024, function(gui)
		local root = Instance.new("Frame")
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = gui

		circle(root, Vector2.new(0.5, 0.5), 1.0, c(110, 175, 255), 0.88) -- halo atmosférico
		circle(root, Vector2.new(0.5, 0.5), 0.84, c(30, 85, 185)) -- océano
		circle(root, Vector2.new(0.42, 0.4), 0.5, c(60, 130, 215), 0.45) -- reflejo

		local land = c(70, 150, 80)
		local desert = c(190, 165, 100)
		blob(root, Vector2.new(0.4, 0.38), 0.15, 0.24, 20, land)
		blob(root, Vector2.new(0.36, 0.55), 0.1, 0.2, -15, land)
		blob(root, Vector2.new(0.6, 0.42), 0.18, 0.14, 10, land)
		blob(root, Vector2.new(0.62, 0.55), 0.1, 0.13, 30, desert)
		blob(root, Vector2.new(0.5, 0.66), 0.12, 0.07, 0, c(240, 245, 250)) -- hielo

		local cloud = c(255, 255, 255)
		blob(root, Vector2.new(0.46, 0.3), 0.26, 0.035, -12, cloud, 0.35)
		blob(root, Vector2.new(0.55, 0.5), 0.3, 0.04, 8, cloud, 0.4)
		blob(root, Vector2.new(0.4, 0.62), 0.22, 0.03, -6, cloud, 0.4)
		blob(root, Vector2.new(0.58, 0.34), 0.18, 0.03, 14, cloud, 0.45)

		circle(root, Vector2.new(0.63, 0.5), 0.84, c(0, 6, 25), 0.55) -- lado nocturno
	end)
end

-- El Sol: disco blanco con brillo.
local function buildSun(world)
	local position = Vector3.new(MINE_LENGTH - 200, 760, 1100)
	skyPanel(world, "Sun", position, 260, 512, function(gui)
		local root = Instance.new("Frame")
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = gui
		circle(root, Vector2.new(0.5, 0.5), 1.0, c(255, 240, 200), 0.9)
		circle(root, Vector2.new(0.5, 0.5), 0.7, c(255, 245, 215), 0.7)
		circle(root, Vector2.new(0.5, 0.5), 0.4, c(255, 252, 240), 0)
	end)
end

-- Colinas lejanas redondeadas alrededor de todo el mundo.
local function buildHills(world, rng)
	for i = 1, 44 do
		local angle = (i / 44) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(860, 960)
		local diameter = rng:NextNumber(250, 600)
		part({
			Name = "Hill" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * diameter,
			Position = Vector3.new(
				WORLD_CENTER.X + math.cos(angle) * radius,
				-diameter * 0.39,
				WORLD_CENTER.Z + math.sin(angle) * radius
			),
			Color = gray(rng, 80, 120),
			Material = Enum.Material.Slate,
		}, world)
	end
end

----------------------------------------------------------------------
-- Suelo
----------------------------------------------------------------------

local function inBaseArea(x, z, margin)
	return x > -310 - margin and x < -30 + margin and math.abs(z) < 240 + margin
end

local function inMineArea(x, z, margin)
	return x > -30 - margin and x < MINE_LENGTH + 30 + margin and math.abs(z) < HALF_WIDTH + 12 + margin
end

local function buildGround(world, rng)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Color = REGOLITH
		baseplate.Material = Enum.Material.Slate
	end

	part({
		Name = "MoonGround",
		Size = Vector3.new(2048, 20, 2048),
		Position = Vector3.new(WORLD_CENTER.X, -10.15, WORLD_CENTER.Z),
		Color = REGOLITH,
		Material = Enum.Material.Slate,
		CanCollide = true,
	}, world)

	-- Cráteres: disco claro (borde) con disco oscuro (fondo) y rocas en el borde.
	for i = 1, 38 do
		local radius = rng:NextNumber(10, 34)
		local x = rng:NextNumber(-500, MINE_LENGTH + 400)
		local z = rng:NextNumber(-800, 800)
		if not inMineArea(x, z, radius) and not inBaseArea(x, z, radius) then
			part({
				Name = "CraterRim" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, radius * 2, radius * 2),
				CFrame = CFrame.new(x, 0.5, z) * VERTICAL,
				Color = c(178, 176, 173),
				Material = Enum.Material.Slate,
			}, world)
			part({
				Name = "CraterFloor" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, radius * 1.6, radius * 1.6),
				CFrame = CFrame.new(x, 0.6, z) * VERTICAL,
				Color = c(112, 110, 108),
				Material = Enum.Material.Slate,
			}, world)
			for k = 1, 6 do
				local angle = rng:NextNumber(0, math.pi * 2)
				local size = rng:NextNumber(1.5, 4)
				part({
					Name = "RimRock",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * size,
					Position = Vector3.new(x + math.cos(angle) * radius, size * 0.3, z + math.sin(angle) * radius),
					Color = gray(rng, 110, 150),
					Material = Enum.Material.Slate,
				}, world)
			end
		end
	end

	-- Rocas sueltas.
	for i = 1, 260 do
		local x = rng:NextNumber(-500, MINE_LENGTH + 400)
		local z = rng:NextNumber(-800, 800)
		if not inMineArea(x, z, 4) and not inBaseArea(x, z, 4) then
			local size = rng:NextNumber(1, 6)
			part({
				Name = "Rock" .. i,
				Size = Vector3.new(size, size * rng:NextNumber(0.5, 1), size * rng:NextNumber(0.7, 1.2)),
				CFrame = CFrame.new(x, size * 0.25, z)
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
				Color = gray(rng, 90, 140),
				Material = Enum.Material.Slate,
				CanCollide = true,
			}, world)
		end
	end
end

----------------------------------------------------------------------
-- Base, módulos y tienda
----------------------------------------------------------------------

-- Rover lunar: chasis blanco, ruedas, panel solar y antena parabólica.
local function buildRover(parent, position)
	part({ Name = "RoverBody", Size = Vector3.new(8, 1.6, 4.4), Position = position + Vector3.new(0, 2.4, 0), Color = WHITE, Material = Enum.Material.Metal, CanCollide = true }, parent)
	part({ Name = "RoverCab", Size = Vector3.new(3.4, 1.6, 3.4), Position = position + Vector3.new(1, 3.8, 0), Color = c(60, 80, 110), Material = Enum.Material.Glass }, parent)
	part({ Name = "RoverPanel", Size = Vector3.new(5, 0.2, 3.6), Position = position + Vector3.new(-1.6, 4.1, 0), Color = c(30, 45, 95) }, parent)
	part({ Name = "RoverMast", Size = Vector3.new(0.3, 3, 0.3), Position = position + Vector3.new(2.6, 4.6, 1.4), Color = STEEL }, parent)
	part({ Name = "RoverDish", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Position = position + Vector3.new(2.6, 6.2, 1.4), Color = WHITE }, parent)
	for _, x in { -2.8, 2.8 } do
		for _, z in { -2.5, 2.5 } do
			part({ Name = "RoverWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 2.4, 2.4), CFrame = CFrame.new(position + Vector3.new(x, 1.2, z)) * CFrame.Angles(0, math.rad(90), 0), Color = c(55, 55, 60) }, parent)
		end
	end
end

local function lampPost(parent, x, z, height, range)
	part({ Name = "LampPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.9, 0.9), CFrame = CFrame.new(x, height / 2, z) * VERTICAL, Color = STEEL, Material = Enum.Material.Metal }, parent)
	local lamp = part({ Name = "LampHead", Size = Vector3.new(2.4, 0.8, 2.4), Position = Vector3.new(x, height + 0.4, z), Color = c(255, 235, 190), Material = Enum.Material.Neon }, parent)
	local light = Instance.new("PointLight")
	light.Color = c(255, 235, 190)
	light.Range = range
	light.Brightness = 1.2
	light.Parent = lamp
end

local function pathStrip(parent, center, size)
	part({ Name = "Path", Size = size, Position = center, Color = c(120, 120, 130), Material = Enum.Material.Concrete }, parent)
end

-- Las bases de los jugadores: plataforma con borde de color, punto de aparición y un
-- cartel con el dueño. Devuelve una lista { Spawn, Label, Center, Index } por cada base.
local function buildBases(world)
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = world

	-- Calle colectora que recorre todas las bases y pasa junto a la plaza.
	pathStrip(
		folder,
		Vector3.new(BASES_X + BASE_HALF + 24, 0.15, 0),
		Vector3.new(10, 0.3, (Config.MaxPlayers - 1) * BASE_SPACING + 20)
	)

	local list = {}
	for i = 1, Config.MaxPlayers do
		local z = (i - (Config.MaxPlayers + 1) / 2) * BASE_SPACING
		local accent = BASE_COLORS[i]
		local size = BASE_HALF * 2

		local plate = part({ Name = "Base" .. i, Size = Vector3.new(size, 0.5, size), Position = Vector3.new(BASES_X, 0.25, z), Color = c(190, 190, 196), Material = Enum.Material.Concrete, CanCollide = true }, folder)
		plate:SetAttribute("Index", i)
		for _, sign in { -1, 1 } do
			part({ Name = "TrimX", Size = Vector3.new(size + 3, 0.8, 1.5), Position = Vector3.new(BASES_X, 0.6, z + sign * BASE_HALF), Color = accent }, folder)
			part({ Name = "TrimZ", Size = Vector3.new(1.5, 0.8, size), Position = Vector3.new(BASES_X + sign * BASE_HALF, 0.6, z), Color = accent }, folder)
		end
		lampPost(folder, BASES_X + BASE_HALF - 4, z - BASE_HALF + 4, 10, 24)
		lampPost(folder, BASES_X + BASE_HALF - 4, z + BASE_HALF - 4, 10, 24)

		-- Estantes: 2 filas de 4. Cada uno tiene un pedestal, un cristal que aparece cuando
		-- guarda un mineral, un cartel con lo que genera y una placa verde en el suelo para
		-- cobrar (se pisa).
		local stands = {}
		for k = 1, Config.StandsPerFloor do
			local row, col = (k - 1) // 4, (k - 1) % 4
			local sx = BASES_X - 21 + col * 14
			local sz = z + (if row == 0 then -18 else 18)
			local towardCenter = if row == 0 then 1 else -1

			local pedestal = part({ Name = "Stand", Size = Vector3.new(7, 2.4, 7), Position = Vector3.new(sx, 1.7, sz), Color = c(205, 208, 216), Material = Enum.Material.Metal, CanCollide = true }, folder)
			pedestal:SetAttribute("BaseIndex", i)
			pedestal:SetAttribute("StandIndex", k)
			part({ Name = "StandTop", Size = Vector3.new(7.6, 0.4, 7.6), Position = Vector3.new(sx, 3.1, sz), Color = accent }, folder)

			local crystal = part({
				Name = "StandCrystal",
				Size = Vector3.new(2.2, 3.6, 2.2),
				CFrame = CFrame.new(sx, 5.1, sz) * CFrame.Angles(0, math.rad(45), 0),
				Material = Enum.Material.Glass,
				Transparency = 1,
			}, folder)

			local standGui = Instance.new("BillboardGui")
			standGui.Size = UDim2.fromOffset(200, 54)
			standGui.StudsOffset = Vector3.new(0, 4, 0)
			standGui.AlwaysOnTop = true
			standGui.MaxDistance = 80
			standGui.Parent = crystal
			local standLabel = Instance.new("TextLabel")
			standLabel.Size = UDim2.fromScale(1, 1)
			standLabel.BackgroundColor3 = c(38, 42, 52)
			standLabel.BackgroundTransparency = 0.2
			standLabel.Font = Enum.Font.GothamBold
			standLabel.TextScaled = true
			standLabel.TextColor3 = WHITE
			standLabel.Text = ""
			standLabel.Visible = false
			standLabel.Parent = standGui
			local standCorner = Instance.new("UICorner")
			standCorner.CornerRadius = UDim.new(0, 8)
			standCorner.Parent = standLabel

			local pad = part({ Name = "CollectPad", Size = Vector3.new(6, 0.4, 6), Position = Vector3.new(sx, 0.7, sz + towardCenter * 8), Color = c(70, 200, 120), CanTouch = true }, folder)
			local padGui = Instance.new("SurfaceGui")
			padGui.Face = Enum.NormalId.Top
			padGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			padGui.PixelsPerStud = 30
			padGui.Parent = pad
			local padLabel = Instance.new("TextLabel")
			padLabel.Size = UDim2.fromScale(1, 1)
			padLabel.BackgroundTransparency = 1
			padLabel.Text = "COBRAR"
			padLabel.TextScaled = true
			padLabel.Font = Enum.Font.GothamBlack
			padLabel.TextColor3 = WHITE
			padLabel.Parent = padGui

			stands[k] = { Index = k, Pedestal = pedestal, Crystal = crystal, Label = standLabel, Pad = pad }
		end

		-- Camino de la base a la calle colectora.
		pathStrip(folder, Vector3.new(BASES_X + BASE_HALF + 12, 0.15, z), Vector3.new(24, 0.3, 10))

		-- Punto de aparición de esta base.
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(BASES_X, 1, z)
		spawn.Color = accent
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Transparency = 0.2
		spawn.Parent = folder

		-- Cartel flotante con el dueño.
		local anchor = part({ Name = "LabelAnchor", Size = Vector3.one, Position = Vector3.new(BASES_X, 18, z), Transparency = 1 }, folder)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(260, 66)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 220
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = c(38, 42, 52)
		label.BackgroundTransparency = 0.2
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = accent
		label.Text = ("Base %d · libre"):format(i)
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label

		table.insert(list, { Spawn = spawn, Label = label, Center = Vector3.new(BASES_X, 0, z), Index = i, Plate = plate, Stands = stands })
	end
	return list
end

-- Plaza común: un disco de concreto con farolas, vacío en el centro, y el módulo de
-- rover como decoración.
local function buildPlaza(world)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = world

	part({ Name = "PlazaDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2), CFrame = CFrame.new(PLAZA_CENTER.X, 0.25, PLAZA_CENTER.Z) * VERTICAL, Color = c(176, 176, 182), Material = Enum.Material.Concrete, CanCollide = true }, plaza)
	part({ Name = "PlazaRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, PLAZA_RADIUS * 2 + 5, PLAZA_RADIUS * 2 + 5), CFrame = CFrame.new(PLAZA_CENTER.X, 0.2, PLAZA_CENTER.Z) * VERTICAL, Color = c(105, 105, 114), Material = Enum.Material.Concrete }, plaza)

	-- Camino de la plaza a la entrada de la mina (x = 0).
	local pathStart = PLAZA_CENTER.X + PLAZA_RADIUS - 5
	pathStrip(plaza, Vector3.new((pathStart + 0) / 2, 0.15, 0), Vector3.new(-pathStart, 0.3, 24))

	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		lampPost(plaza, PLAZA_CENTER.X + math.cos(angle) * 28, PLAZA_CENTER.Z + math.sin(angle) * 28, 11, 26)
	end

	buildRover(plaza, Vector3.new(PLAZA_CENTER.X - 5, 0.5, PLAZA_CENTER.Z + 62))

	-- Quita los puntos de aparición de la plantilla de Studio (la placa blanca con el sol
	-- negro) y deja uno invisible en la plaza para quien no tenga base.
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.Position = Vector3.new(PLAZA_CENTER.X + 5, 0.6, PLAZA_CENTER.Z + 25)
	spawn.Parent = plaza
end

-- Tienda con su ProximityPrompt y un emblema flotante encima. `facing` es hacia donde
-- mira el frente.
local function buildShop(parent, position, facing, def)
	local origin = CFrame.lookAt(position, position + facing)
	local shop = BuildingModels.Shop(origin, def.Text, def.Accent)
	shop.Parent = parent

	local emblem = BuildingModels.Emblem(def.Id, origin * CFrame.new(0, 18, 0))
	emblem.Parent = parent

	local promptPosition = position + facing * 8 + Vector3.new(0, 3, 0)
	local promptPart = part({ Name = "ShopPrompt", Size = Vector3.new(8, 6, 2), Position = promptPosition, Transparency = 1 }, parent)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir tienda"
	prompt.ObjectText = def.ObjectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	return { Id = def.Id, Kind = def.Kind, Prompt = prompt, Position = promptPosition }
end

local UPGRADE_SHOPS = {
	{ Id = "Sell", Kind = "Upgrade", Text = "VENDER", Accent = c(235, 175, 40), ObjectText = "Vender minerales" },
	{ Id = "Pickaxe", Kind = "Upgrade", Text = "PICO", Accent = c(235, 130, 40), ObjectText = "Mejorar pico" },
	{ Id = "Strength", Kind = "Upgrade", Text = "FUERZA", Accent = c(230, 90, 90), ObjectText = "Mejorar fuerza" },
	{ Id = "Speed", Kind = "Upgrade", Text = "VELOCIDAD", Accent = c(60, 170, 255), ObjectText = "Mejorar velocidad" },
}

local ROBUX_SHOPS = {
	{ Id = "X2", Kind = "Robux", Text = "x2 DINERO", Accent = c(70, 190, 110), ObjectText = "Doble de créditos" },
	{ Id = "Boots", Kind = "Robux", Text = "BOTAS VIP", Accent = c(70, 190, 110), ObjectText = "Botas lunares VIP" },
	{ Id = "Shield", Kind = "Robux", Text = "ESCUDO", Accent = c(70, 190, 110), ObjectText = "Escudo anti-Alien" },
	{ Id = "Credits", Kind = "Robux", Text = "CRÉDITOS", Accent = c(70, 190, 110), ObjectText = "Paquetes de créditos" },
}

-- Las tiendas al borde de la linea de inicio, mirando hacia las bases: mejoras a un lado
-- (z negativa) y Robux al otro.
-- Devuelve una lista de { Id, Kind, Prompt, Position }.
local function buildShops(world)
	local folder = Instance.new("Folder")
	folder.Name = "Shops"
	folder.Parent = world

	local shops = {}
	for index, def in UPGRADE_SHOPS do
		local z = -(SHOP_FIRST_Z + (index - 1) * SHOP_SPACING)
		table.insert(shops, buildShop(folder, Vector3.new(SHOP_X, 0, z), Vector3.new(-1, 0, 0), def))
	end
	for index, def in ROBUX_SHOPS do
		local z = SHOP_FIRST_Z + (index - 1) * SHOP_SPACING
		table.insert(shops, buildShop(folder, Vector3.new(SHOP_X, 0, z), Vector3.new(-1, 0, 0), def))
	end
	return shops
end

----------------------------------------------------------------------
-- Limite de la zona jugable: borde de crater (montanas) que encierra bases, plaza,
-- tiendas y mina. Cada pared tiene una barrera invisible mas alta para que nadie
-- pueda saltar por encima.
----------------------------------------------------------------------

local WALL_HEIGHT = 60
local BARRIER_HEIGHT = 160
local WALL_THICKNESS = 16
local BASE_REGION = 205 -- la zona de bases va de x = -205 a 0 y de z = -205 a 205

local function wallBox(parent, center, width, depth)
	part({
		Name = "RimWall",
		Size = Vector3.new(width, WALL_HEIGHT, depth),
		Position = Vector3.new(center.X, WALL_HEIGHT / 2, center.Z),
		Color = ROCK_DARK,
		Material = Enum.Material.Slate,
		CanCollide = true,
	}, parent)
	part({
		Name = "RimBarrier",
		Size = Vector3.new(width, BARRIER_HEIGHT, depth),
		Position = Vector3.new(center.X, BARRIER_HEIGHT / 2, center.Z),
		Transparency = 1,
		CanCollide = true,
	}, parent)
end

-- Hilera de montanas redondeadas por fuera de una pared (`outward`: hacia el exterior).
local function mountainLine(parent, rng, from, to, outward)
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local count = math.max(1, math.floor(length / 50))
	for k = 0, count do
		local diameter = rng:NextNumber(70, 130)
		local position = from + direction * (length * k / count) + outward * (diameter * 0.5 + 8)
		part({
			Name = "Mountain",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * diameter,
			Position = Vector3.new(position.X, diameter * 0.2, position.Z),
			Color = gray(rng, 80, 125),
			Material = Enum.Material.Slate,
		}, parent)
	end
end

local function buildBoundary(world, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Boundary"
	folder.Parent = world

	local R, T = BASE_REGION, WALL_THICKNESS
	local minX, maxX = -R - T, T / 2
	local edge = R + T -- cara exterior de las paredes norte y sur

	-- Zona de bases: oeste, norte, sur y los dos tramos al este que cierran hasta la mina.
	wallBox(folder, Vector3.new(-R - T / 2, 0, 0), T, 2 * edge)
	wallBox(folder, Vector3.new((minX + maxX) / 2, 0, -(R + T / 2)), maxX - minX, T)
	wallBox(folder, Vector3.new((minX + maxX) / 2, 0, R + T / 2), maxX - minX, T)
	local closeLength = edge - HALF_WIDTH
	for _, sign in { -1, 1 } do
		wallBox(folder, Vector3.new(0, 0, sign * (HALF_WIDTH + closeLength / 2)), T, closeLength)
	end

	-- La mina ya tiene paredes visibles; se les suma la barrera invisible.
	for _, sign in { -1, 1 } do
		part({
			Name = "RimBarrier",
			Size = Vector3.new(MINE_LENGTH + 30, BARRIER_HEIGHT, 12),
			Position = Vector3.new(MINE_LENGTH / 2, BARRIER_HEIGHT / 2, sign * (HALF_WIDTH + 5)),
			Transparency = 1,
			CanCollide = true,
		}, folder)
	end
	part({
		Name = "RimBarrier",
		Size = Vector3.new(12, BARRIER_HEIGHT, HALF_WIDTH * 2 + 30),
		Position = Vector3.new(MINE_LENGTH + 5, BARRIER_HEIGHT / 2, 0),
		Transparency = 1,
		CanCollide = true,
	}, folder)

	-- Montanas por fuera de todo el perimetro.
	mountainLine(folder, rng, Vector3.new(minX, 0, -edge), Vector3.new(minX, 0, edge), Vector3.new(-1, 0, 0))
	mountainLine(folder, rng, Vector3.new(minX, 0, -edge), Vector3.new(maxX, 0, -edge), Vector3.new(0, 0, -1))
	mountainLine(folder, rng, Vector3.new(minX, 0, edge), Vector3.new(maxX, 0, edge), Vector3.new(0, 0, 1))
	for _, sign in { -1, 1 } do
		-- Una montana pequena tras cada tramo de muro que cierra hasta la mina.
		local small = rng:NextNumber(45, 60)
		part({
			Name = "Mountain",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * small,
			Position = Vector3.new(maxX + small / 2 + 8, small * 0.2, sign * (HALF_WIDTH + closeLength / 2)),
			Color = gray(rng, 80, 125),
			Material = Enum.Material.Slate,
		}, folder)
		-- A lo largo de la mina, empezando lejos de la zona de bases para no meterse en ella.
		mountainLine(folder, rng, Vector3.new(maxX + 75, 0, sign * (HALF_WIDTH + 12)), Vector3.new(MINE_LENGTH + 10, 0, sign * (HALF_WIDTH + 12)), Vector3.new(0, 0, sign))
	end
	mountainLine(folder, rng, Vector3.new(MINE_LENGTH + 12, 0, -HALF_WIDTH), Vector3.new(MINE_LENGTH + 12, 0, HALF_WIDTH), Vector3.new(1, 0, 0))
end

----------------------------------------------------------------------
-- Mina
----------------------------------------------------------------------

-- Arco de acero con cartel y focos; `width` es la separación entre postes.
local function arch(parent, x, width, text, accent)
	for _, z in { -width / 2, width / 2 } do
		part({ Name = "ArchPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 3, 3), CFrame = CFrame.new(x, 11, z) * VERTICAL, Color = STEEL, Material = Enum.Material.Metal, CanCollide = true }, parent)
		local lamp = part({ Name = "ArchLamp", Size = Vector3.new(3.4, 1, 3.4), Position = Vector3.new(x, 22.5, z), Color = c(255, 235, 190), Material = Enum.Material.Neon }, parent)
		local light = Instance.new("PointLight")
		light.Color = c(255, 235, 190)
		light.Range = 40
		light.Brightness = 1.4
		light.Parent = lamp
	end
	part({ Name = "ArchBeam", Size = Vector3.new(2, 2, width + 2), Position = Vector3.new(x, 22, 0), Color = STEEL, Material = Enum.Material.Metal }, parent)
	board(parent, facingBase(Vector3.new(x, 18.5, 0)), Vector3.new(width - 8, 6, 1), text, PANEL_DARK, accent)
end

local function buildMine(world, rng)
	local mine = Instance.new("Folder")
	mine.Name = "Mine"
	mine.Parent = world

	-- Suelo de cada zona: grises cada vez más oscuros según la profundidad.
	for zone = 1, Config.ZoneCount do
		part({
			Name = "Zone" .. zone .. "Floor",
			Size = Vector3.new(Config.ZoneLength, 0.3, HALF_WIDTH * 2),
			Position = Vector3.new((zone - 0.5) * Config.ZoneLength, 0.15, 0),
			Color = Config.Zones[zone].Color,
			Material = Enum.Material.Slate,
		}, mine)
	end

	-- Línea de inicio: franjas de peligro amarillas y negras.
	local stripe = 10
	for i = 0, (HALF_WIDTH * 2) / stripe - 1 do
		part({
			Name = "StartLine",
			Size = Vector3.new(3, 0.45, stripe),
			Position = Vector3.new(0, 0.225, -HALF_WIDTH + stripe / 2 + i * stripe),
			Color = if i % 2 == 0 then c(255, 200, 40) else c(30, 30, 32),
		}, mine)
	end

	-- Paredes de roca a los lados y al fondo, con peñascos encima.
	for _, z in { -HALF_WIDTH - 5, HALF_WIDTH + 5 } do
		part({ Name = "Wall", Size = Vector3.new(MINE_LENGTH + 20, 24, 10), Position = Vector3.new(MINE_LENGTH / 2, 12, z), Color = ROCK_DARK, Material = Enum.Material.Slate, CanCollide = true }, mine)
		for x = -10, MINE_LENGTH + 10, 22 do
			local size = rng:NextNumber(14, 26)
			part({
				Name = "Boulder",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				Position = Vector3.new(x + rng:NextNumber(-5, 5), 20 + size * 0.2, z + rng:NextNumber(-3, 3)),
				Color = gray(rng, 80, 125),
				Material = Enum.Material.Slate,
			}, mine)
		end
	end
	part({ Name = "EndWall", Size = Vector3.new(10, 24, HALF_WIDTH * 2 + 20), Position = Vector3.new(MINE_LENGTH + 5, 12, 0), Color = ROCK_DARK, Material = Enum.Material.Slate, CanCollide = true }, mine)

	-- Arco de entrada y arcos al inicio de cada zona.
	arch(mine, 0, 70, "MINA LUNAR", c(255, 200, 40))
	for zone = 2, Config.ZoneCount do
		arch(mine, (zone - 1) * Config.ZoneLength, 70, Config.Zones[zone].Name:upper(), Config.Zones[zone].GemColor)
	end

	-- Carteles de profundidad cada 100 studs.
	for depth = 100, MINE_LENGTH, 100 do
		part({ Name = "MarkerPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 0.9, 0.9), CFrame = CFrame.new(depth, 3.5, -HALF_WIDTH + 12) * VERTICAL, Color = STEEL, Material = Enum.Material.Metal }, mine)
		board(mine, facingBase(Vector3.new(depth, 8, -HALF_WIDTH + 12)), Vector3.new(7, 3, 0.5), depth .. " m", PANEL_DARK, WHITE)
	end
end

-- Construye el mundo y devuelve { Bases = {...}, Shops = {...} }.
function WorldBuilder.Build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local rng = Random.new(1337)
	setupLighting()
	buildGround(world, rng)
	buildHills(world, rng)
	buildEarth(world)
	buildSun(world)
	buildMine(world, rng)
	buildBoundary(world, rng)
	buildPlaza(world)

	return {
		Bases = buildBases(world),
		Shops = buildShops(world),
	}
end

return WorldBuilder
