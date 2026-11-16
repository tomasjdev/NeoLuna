-- Construye el mundo de la Luna (estilo realista): cielo negro con estrellas y la
-- Tierra, suelo de regolito gris con cráteres y rocas, colinas lejanas, la base
-- con la tienda y la mina dividida en zonas con paredes, arcos y carteles.
-- Es determinista (misma semilla = mismo mundo).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildingModels = require(ReplicatedStorage.Shared.BuildingModels)
local Npcs = require(script.Parent.Npcs)

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

-- Una pieza no puede medir mas de 2048: las cajas largas sobre el eje X se parten en tramos.
-- `make(centerX, length)` crea cada tramo.
local function longX(fromX, toX, make)
	local pieces = math.ceil((toX - fromX) / 1800)
	local length = (toX - fromX) / pieces
	for i = 1, pieces do
		make(fromX + length * (i - 0.5), length + 1)
	end
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
	-- La elipse cubre desde las bases (x = -300) hasta el fondo de la mina.
	local centerX = (MINE_LENGTH - 300) / 2
	local radiusX = (MINE_LENGTH + 300) / 2 + 600
	local radiusZ = 900
	local hillCount = math.floor(44 * (radiusX + radiusZ) / 1900)
	for i = 1, hillCount do
		local angle = (i / hillCount) * math.pi * 2 + rng:NextNumber(-0.02, 0.02)
		local scale = rng:NextNumber(0.96, 1.06)
		local diameter = rng:NextNumber(250, 600)
		part({
			Name = "Hill" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * diameter,
			Position = Vector3.new(
				centerX + math.cos(angle) * radiusX * scale,
				-diameter * 0.39,
				math.sin(angle) * radiusZ * scale
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

	-- Suelo de todo el mundo: desde detras de las bases hasta mas alla del fondo de la mina,
	-- en losas (una pieza no puede medir mas de 2048).
	local groundMinX, groundMaxX = -1100, MINE_LENGTH + 900
	local tiles = math.ceil((groundMaxX - groundMinX) / 2000)
	local tileLength = (groundMaxX - groundMinX) / tiles
	for tile = 1, tiles do
		part({
			Name = "MoonGround" .. tile,
			Size = Vector3.new(tileLength + 2, 20, 2048),
			Position = Vector3.new(groundMinX + tileLength * (tile - 0.5), -10.15, 0),
			Color = REGOLITH,
			Material = Enum.Material.Slate,
			CanCollide = true,
		}, world)
	end

	-- Cráteres: disco claro (borde) con disco oscuro (fondo) y rocas en el borde.
	local areaScale = (MINE_LENGTH + 900) / 1900 -- el mundo original medía 1900 de largo
	for i = 1, math.floor(38 * areaScale) do
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
	for i = 1, math.floor(260 * areaScale) do
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

-- Luz en el piso: un disco plano que brilla y alumbra desde abajo, sin postes que tapen la vista.
local function floorLight(parent, x, z, range)
	local disc = part({ Name = "FloorLight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3.4, 3.4), CFrame = CFrame.new(x, 0.55, z) * VERTICAL, Color = c(255, 240, 200), Material = Enum.Material.Neon }, parent)
	part({ Name = "FloorLightRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 4.2, 4.2), CFrame = CFrame.new(x, 0.52, z) * VERTICAL, Color = c(70, 74, 86), Material = Enum.Material.Metal }, parent)
	local light = Instance.new("PointLight")
	light.Color = c(255, 235, 190)
	light.Range = range
	light.Brightness = 1
	light.Parent = disc
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
		floorLight(folder, BASES_X + BASE_HALF - 4, z - BASE_HALF + 4, 24)
		floorLight(folder, BASES_X + BASE_HALF - 4, z + BASE_HALF - 4, 24)

		-- Pisos: el piso 1 es la base; los demas flotan encima (Config.FloorHeight cada uno) y
		-- solo se ven cuando el dueno los compra (Bases.Update). Cada piso tiene 8 estantes y un
		-- ascensor; el piso 1 tiene ademas la terminal para comprar pisos.
		local stands = {}
		local floors = {}
		for f = 1, Config.MaxFloors do
			local oy = (f - 1) * Config.FloorHeight
			local floorInfo = { Parts = {} }
			floors[f] = floorInfo
			local function floorPart(props)
				local p = part(props, folder)
				table.insert(floorInfo.Parts, { Part = p, Transparency = p.Transparency, CanCollide = p.CanCollide })
				return p
			end

			-- Piso de arriba: placa con una muesca al fondo de la base (oeste, al centro) por donde
			-- sube una escalera vertical, y 4 columnas de soporte en las esquinas.
			if f > 1 then
				local plateColor = c(190, 190, 196)
				local notchX = BASES_X - BASE_HALF + 2.5 -- centro de la muesca (5 de ancho)
				local plateY = oy - 0.25
				-- placa: el bloque principal y dos tiras a los lados de la muesca (z -3 a 3)
				floorPart({ Name = "FloorPlate", Size = Vector3.new(size - 5, 1.5, size), Position = Vector3.new(BASES_X + 2.5, plateY, z), Color = plateColor, Material = Enum.Material.Concrete, CanCollide = true })
				local stripLength = BASE_HALF - 3
				floorPart({ Name = "FloorPlateNorth", Size = Vector3.new(5, 1.5, stripLength), Position = Vector3.new(notchX, plateY, z - 3 - stripLength / 2), Color = plateColor, Material = Enum.Material.Concrete, CanCollide = true })
				floorPart({ Name = "FloorPlateSouth", Size = Vector3.new(5, 1.5, stripLength), Position = Vector3.new(notchX, plateY, z + 3 + stripLength / 2), Color = plateColor, Material = Enum.Material.Concrete, CanCollide = true })
				for _, sign in { -1, 1 } do
					floorPart({ Name = "TrimX", Size = Vector3.new(size + 3, 0.8, 1.5), Position = Vector3.new(BASES_X, oy + 0.6, z + sign * BASE_HALF), Color = accent })
					floorPart({ Name = "TrimZ", Size = Vector3.new(1.5, 0.8, size), Position = Vector3.new(BASES_X + sign * BASE_HALF, oy + 0.6, z), Color = accent })
				end

				-- Escalera vertical (TrussPart: se trepa caminando contra ella). Va del piso de
				-- abajo hasta un poco por encima de este piso para poder salir a la placa.
				local ladder = Instance.new("TrussPart")
				ladder.Name = "Ladder"
				ladder.Anchored = true
				ladder.Size = Vector3.new(2, Config.FloorHeight + 3, 2)
				ladder.Position = Vector3.new(notchX, oy - Config.FloorHeight + 0.5 + (Config.FloorHeight + 3) / 2, z)
				ladder.Color = c(255, 205, 70)
				ladder.Material = Enum.Material.Metal
				ladder.Parent = folder
				table.insert(floorInfo.Parts, { Part = ladder, Transparency = 0, CanCollide = true })

				-- Soportes: una columna en cada esquina, desde el piso de abajo hasta este.
				local columnHeight = Config.FloorHeight - 1
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						floorPart({
							Name = "FloorColumn",
							Size = Vector3.new(3, columnHeight, 3),
							Position = Vector3.new(BASES_X + sx * (BASE_HALF - 2), oy - Config.FloorHeight + 0.5 + columnHeight / 2, z + sz * (BASE_HALF - 2)),
							Color = c(150, 154, 166),
							Material = Enum.Material.Metal,
							CanCollide = true,
						})
					end
				end
			end

			-- Estantes: 2 filas de 4. Cada uno tiene un pedestal, un cristal que aparece cuando
			-- guarda un mineral, un cartel de bloqueo y una placa verde en el suelo para cobrar
			-- (se pisa).
			for slot = 1, Config.StandsPerFloor do
				local k = (f - 1) * Config.StandsPerFloor + slot
				local row, col = (slot - 1) // 4, (slot - 1) % 4
				local sx = BASES_X - 21 + col * 14
				local sz = z + (if row == 0 then -18 else 18)
				local towardCenter = if row == 0 then 1 else -1

				local pedestal = part({ Name = "Stand", Size = Vector3.new(7, 2.4, 7), Position = Vector3.new(sx, oy + 1.7, sz), Color = c(205, 208, 216), Material = Enum.Material.Metal, CanCollide = true }, folder)
				pedestal:SetAttribute("BaseIndex", i)
				pedestal:SetAttribute("StandIndex", k)
				pedestal:SetAttribute("Locked", false)
				local top = part({ Name = "StandTop", Size = Vector3.new(7.6, 0.4, 7.6), Position = Vector3.new(sx, oy + 3.1, sz), Color = accent }, folder)

				local crystal = part({
					Name = "StandCrystal",
					Size = Vector3.new(2.2, 3.6, 2.2),
					CFrame = CFrame.new(sx, oy + 5.1, sz) * CFrame.Angles(0, math.rad(45), 0),
					Material = Enum.Material.Glass,
					Transparency = 1,
				}, folder)

				-- Cartel de bloqueo (se muestra solo mientras el estante esta bloqueado).
				local signGui = Instance.new("BillboardGui")
				signGui.Name = "OwnerOnlyLockSign"
				signGui.Size = UDim2.fromOffset(150, 52)
				signGui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
				signGui.MaxDistance = 90
				signGui.Enabled = false
				signGui.Parent = pedestal
				local signLabel = Instance.new("TextLabel")
				signLabel.Size = UDim2.fromScale(1, 1)
				signLabel.BackgroundColor3 = c(38, 42, 52)
				signLabel.BackgroundTransparency = 0.15
				signLabel.Font = Enum.Font.GothamBold
				signLabel.TextScaled = true
				signLabel.TextColor3 = c(255, 205, 90)
				signLabel.Text = "BLOQUEADO"
				signLabel.Parent = signGui
				local signCorner = Instance.new("UICorner")
				signCorner.CornerRadius = UDim.new(0, 10)
				signCorner.Parent = signLabel

				-- Desbloquear (lo activa Bases.Update solo en el siguiente estante por abrir).
				local unlockPrompt = Instance.new("ProximityPrompt")
				unlockPrompt.Name = "OwnerOnlyUnlockPrompt"
				unlockPrompt.ActionText = "Desbloquear"
				unlockPrompt.HoldDuration = 0.4
				unlockPrompt.MaxActivationDistance = 12
				unlockPrompt.RequiresLineOfSight = false
				unlockPrompt.Enabled = false
				unlockPrompt.Parent = pedestal

				-- Placa rectangular, paralela al borde frontal del estante, pegada a el. Su lado
				-- largo es el eje Z de la pieza y se gira 90 grados: el texto de una cara superior
				-- corre a lo largo de ese eje, asi queda horizontal para quien camina hacia el
				-- estante (cada fila gira al lado contrario para leerse bien desde el centro).
				local pad = part({
					Name = "CollectPad",
					Size = Vector3.new(2.6, 0.3, 6.4),
					CFrame = CFrame.new(sx, oy + 0.65, sz + towardCenter * 5.6) * CFrame.Angles(0, if row == 0 then -math.pi / 2 else math.pi / 2, 0),
					Color = c(70, 200, 120),
					CanTouch = true,
				}, folder)
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
				padLabel.Font = Enum.Font.FredokaOne
				padLabel.TextColor3 = WHITE
				padLabel.Parent = padGui
				local padText = Instance.new("UIPadding")
				padText.PaddingTop = UDim.new(0, 6)
				padText.PaddingBottom = UDim.new(0, 6)
				padText.Parent = padLabel

				stands[k] = {
					Index = k, Floor = f, Slot = slot, Accent = accent,
					Pedestal = pedestal, Top = top, Crystal = crystal, Pad = pad, PadGui = padGui,
					SignGui = signGui, SignLabel = signLabel, UnlockPrompt = unlockPrompt,
				}
			end
		end

		-- Terminal para comprar pisos (en el piso 1, al otro lado del ascensor).
		local terminal = part({ Name = "FloorTerminal", Size = Vector3.new(3, 5, 3), Position = Vector3.new(BASES_X - 29, 3, z + 12), Color = c(60, 66, 82), Material = Enum.Material.Metal, CanCollide = true }, folder)
		part({ Name = "FloorTerminalTop", Size = Vector3.new(3.6, 0.6, 3.6), Position = Vector3.new(BASES_X - 29, 5.8, z + 12), Color = accent, Material = Enum.Material.Neon }, folder)
		terminal:SetAttribute("BaseIndex", i)
		local terminalGui = Instance.new("BillboardGui")
		terminalGui.Name = "OwnerOnlyTerminalGui"
		terminalGui.Size = UDim2.fromOffset(104, 38)
		terminalGui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		terminalGui.MaxDistance = 60
		terminalGui.Parent = terminal
		local terminalLabel = Instance.new("TextLabel")
		terminalLabel.Size = UDim2.fromScale(1, 1)
		terminalLabel.BackgroundColor3 = c(38, 42, 52)
		terminalLabel.BackgroundTransparency = 0.15
		terminalLabel.Font = Enum.Font.GothamBold
		terminalLabel.TextScaled = true
		local terminalPad = Instance.new("UIPadding")
		terminalPad.PaddingTop = UDim.new(0, 3)
		terminalPad.PaddingBottom = UDim.new(0, 3)
		terminalPad.Parent = terminalLabel
		terminalLabel.TextColor3 = accent
		terminalLabel.Text = "NUEVO PISO"
		terminalLabel.Parent = terminalGui
		local terminalCorner = Instance.new("UICorner")
		terminalCorner.CornerRadius = UDim.new(0, 10)
		terminalCorner.Parent = terminalLabel
		local terminalPrompt = Instance.new("ProximityPrompt")
		terminalPrompt.Name = "OwnerOnlyTerminalPrompt"
		terminalPrompt.ActionText = "Comprar piso"
		terminalPrompt.HoldDuration = 0.4
		terminalPrompt.MaxActivationDistance = 12
		terminalPrompt.RequiresLineOfSight = false
		terminalPrompt.Parent = terminal

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
		spawn.CanCollide = false
		spawn.Transparency = 1
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") or child:IsA("Texture") then
				child:Destroy()
			end
		end
		spawn.Parent = folder

		-- Cartel flotante con el dueño.
		local anchor = part({ Name = "LabelAnchor", Size = Vector3.one, Position = Vector3.new(BASES_X, 40, z), Transparency = 1 }, folder)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(260, 66)
		gui.AlwaysOnTop = true
		gui.Enabled = false
		gui.MaxDistance = 220
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = c(38, 42, 52)
		label.BackgroundTransparency = 0.2
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = accent
		label.Text = ""
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label

		table.insert(list, {
			Spawn = spawn, Label = label, LabelAnchor = anchor, Center = Vector3.new(BASES_X, 0, z), Index = i, Plate = plate,
			Stands = stands, Floors = floors, Terminal = { Prompt = terminalPrompt, Label = terminalLabel },
		})
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
		floorLight(plaza, PLAZA_CENTER.X + math.cos(angle) * 28, PLAZA_CENTER.Z + math.sin(angle) * 28, 26)
	end

	buildRover(plaza, Vector3.new(PLAZA_CENTER.X - 5, 0.5, PLAZA_CENTER.Z + 62))

	-- Horno de fusion: uno solo para todos los jugadores del servidor, en el centro de la
	-- plaza. Cada uno funde SUS minerales (nadie puede quitarle minerales a otro).
	local fx, fz = PLAZA_CENTER.X, PLAZA_CENTER.Z
	-- Estilo astronauta: cuerpo blanco, banda celeste, nucleo de cristal naranja y antena.
	local WHITE_METAL = c(205, 209, 220)
	local CYAN = c(70, 150, 200)
	local ORANGE = c(255, 140, 50)
	local function disk(name, y, height, diameter, color, material, extra)
		local props = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = CFrame.new(fx, y, fz) * VERTICAL, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = true }
		for key, value in extra or {} do
			props[key] = value
		end
		return part(props, plaza)
	end
	disk("FurnacePlatform", 0.9, 0.8, 12, c(200, 205, 216), Enum.Material.Metal)
	disk("FurnacePlatformGlow", 0.55, 0.2, 12.6, CYAN, Enum.Material.SmoothPlastic)
	local kiln = disk("FusionFurnace", 2.9, 4, 8, WHITE_METAL, Enum.Material.SmoothPlastic, { CanCollide = true })
	disk("FurnaceBandLow", 4.8, 0.5, 8.5, CYAN, Enum.Material.SmoothPlastic)
	-- Nucleo: cristal naranja con luz, sostenido por 4 puntales.
	disk("FurnaceCoreGlass", 6.8, 4, 6, c(255, 180, 110), Enum.Material.Glass, { Transparency = 0.45 })
	local core = part({ Name = "FurnaceCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, Position = Vector3.new(fx, 6.8, fz), Color = c(215, 130, 60), Material = Enum.Material.SmoothPlastic }, plaza)
	local coreLight = Instance.new("PointLight")
	coreLight.Color = c(255, 170, 90)
	coreLight.Range = 12
	coreLight.Brightness = 0.3
	coreLight.Parent = core
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		part({ Name = "FurnaceStrut", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.6, 0.6), CFrame = CFrame.new(fx + math.cos(angle) * 3, 6.8, fz + math.sin(angle) * 3) * VERTICAL, Color = WHITE_METAL }, plaza)
	end
	disk("FurnaceBandHigh", 8.8, 0.5, 8.5, CYAN, Enum.Material.SmoothPlastic)
	disk("FurnaceUpper", 10.1, 2.6, 8, WHITE_METAL)
	disk("FurnaceStripe", 10.1, 0.7, 8.2, ORANGE)
	part({ Name = "FurnaceDome", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, Position = Vector3.new(fx, 11.4, fz), Color = WHITE_METAL, CanCollide = true }, plaza)
	-- Antena con punta luminosa y paneles naranjas (como los parches de un traje espacial).
	disk("FurnaceAntenna", 16, 3.4, 0.35, c(150, 156, 170), Enum.Material.Metal)
	part({ Name = "FurnaceAntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = Vector3.new(fx, 17.9, fz), Color = CYAN, Material = Enum.Material.SmoothPlastic }, plaza)
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local origin = Vector3.new(fx + math.cos(angle) * 4.05, 2.9, fz + math.sin(angle) * 4.05)
		part({ Name = "FurnacePanel", Size = Vector3.new(2.6, 2, 0.3), CFrame = CFrame.lookAt(origin, Vector3.new(fx, 2.9, fz)), Color = ORANGE, CanCollide = true }, plaza)
		part({ Name = "FurnaceButton", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.lookAt(origin + Vector3.new(math.cos(angle) * 0.2, 0.3, math.sin(angle) * 0.2), Vector3.new(fx, 3.2, fz)), Color = CYAN, Material = Enum.Material.SmoothPlastic }, plaza)
	end

	-- Titulo bien arriba del horno, sobre la chimenea.
	local fuseGui = Instance.new("BillboardGui")
	fuseGui.Size = UDim2.fromOffset(96, 28)
	fuseGui.MaxDistance = 120
	fuseGui.Parent = part({ Name = "FurnaceTitleAnchor", Size = Vector3.one, Position = Vector3.new(fx, 23, fz), Transparency = 1 }, plaza)
	local fuseLabel = Instance.new("TextLabel")
	fuseLabel.Size = UDim2.fromScale(1, 1)
	fuseLabel.BackgroundColor3 = c(38, 42, 52)
	fuseLabel.BackgroundTransparency = 0.15
	fuseLabel.Font = Enum.Font.GothamBold
	fuseLabel.TextScaled = true
	fuseLabel.TextColor3 = c(255, 170, 80)
	fuseLabel.Text = "FUSIÓN"
	fuseLabel.Parent = fuseGui
	local fuseCorner = Instance.new("UICorner")
	fuseCorner.CornerRadius = UDim.new(0, 10)
	fuseCorner.Parent = fuseLabel
	local fusePrompt = Instance.new("ProximityPrompt")
	fusePrompt.ActionText = "Fusionar minerales"
	fusePrompt.ObjectText = "Horno de fusión"
	fusePrompt.HoldDuration = 0
	fusePrompt.MaxActivationDistance = 16
	fusePrompt.RequiresLineOfSight = false
	fusePrompt.Parent = kiln

	-- Cartel del jugador mas rico de la sesion, muy arriba del centro de la plaza: solo su
	-- foto de perfil y su nombre (Main.server lo actualiza).
	local topAnchor = part({ Name = "TopPlayerAnchor", Size = Vector3.one, Position = Vector3.new(fx, 58, fz), Transparency = 1 }, plaza)
	local topGui = Instance.new("BillboardGui")
	topGui.Size = UDim2.fromOffset(150, 170)
	topGui.MaxDistance = 600
	topGui.AlwaysOnTop = false
	topGui.Enabled = false
	topGui.Parent = topAnchor
	local topImage = Instance.new("ImageLabel")
	topImage.AnchorPoint = Vector2.new(0.5, 0)
	topImage.Position = UDim2.new(0.5, 0, 0, 0)
	topImage.Size = UDim2.fromOffset(120, 120)
	topImage.BackgroundColor3 = c(255, 255, 255)
	topImage.Parent = topGui
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(1, 0)
	topCorner.Parent = topImage
	local topStroke = Instance.new("UIStroke")
	topStroke.Color = c(255, 205, 70)
	topStroke.Thickness = 4
	topStroke.Parent = topImage
	local topName = Instance.new("TextLabel")
	topName.Position = UDim2.fromOffset(0, 126)
	topName.Size = UDim2.new(1, 0, 0, 36)
	topName.BackgroundColor3 = c(38, 42, 52)
	topName.BackgroundTransparency = 0.15
	topName.Font = Enum.Font.GothamBold
	topName.TextScaled = true
	topName.TextColor3 = c(255, 230, 150)
	topName.Text = ""
	topName.Parent = topGui
	local topNameCorner = Instance.new("UICorner")
	topNameCorner.CornerRadius = UDim.new(0, 10)
	topNameCorner.Parent = topName
	local topPad = Instance.new("UIPadding")
	topPad.PaddingTop = UDim.new(0, 3)
	topPad.PaddingBottom = UDim.new(0, 3)
	topPad.Parent = topName
	-- Altar de renacimiento: al norte del horno. Todo es solido y sin brillos fuertes.
	local ax, az = fx, fz - 22
	local PURPLE = c(150, 110, 230)
	part({ Name = "AltarBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 11, 11), CFrame = CFrame.new(ax, 1, az) * VERTICAL, Color = c(200, 205, 216), Material = Enum.Material.Metal, CanCollide = true }, plaza)
	part({ Name = "AltarRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 11.6, 11.6), CFrame = CFrame.new(ax, 0.6, az) * VERTICAL, Color = PURPLE }, plaza)
	local altar = part({ Name = "RebirthAltar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 3.4, 3.4), CFrame = CFrame.new(ax, 2.5, az) * VERTICAL, Color = c(235, 238, 246), Material = Enum.Material.SmoothPlastic, CanCollide = true }, plaza)
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		part({ Name = "AltarPillar", Size = Vector3.new(1, 6, 1), Position = Vector3.new(ax + math.cos(angle) * 4.2, 4, az + math.sin(angle) * 4.2), Color = c(205, 208, 220), Material = Enum.Material.Metal, CanCollide = true }, plaza)
		part({ Name = "AltarPillarTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Position = Vector3.new(ax + math.cos(angle) * 4.2, 7.3, az + math.sin(angle) * 4.2), Color = PURPLE }, plaza)
	end
	-- Cristal flotante (dos cubos girados) sobre el pedestal.
	part({ Name = "AltarGem", Size = Vector3.one * 2.6, CFrame = CFrame.new(ax, 6.2, az) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color = PURPLE, Material = Enum.Material.Glass, Transparency = 0.15 }, plaza)
	local altarLight = Instance.new("PointLight")
	altarLight.Color = PURPLE
	altarLight.Range = 14
	altarLight.Brightness = 0.4
	altarLight.Parent = altar
	local altarAnchor = part({ Name = "AltarTitleAnchor", Size = Vector3.one, Position = Vector3.new(ax, 13, az), Transparency = 1 }, plaza)
	local altarGui = Instance.new("BillboardGui")
	altarGui.Size = UDim2.fromOffset(104, 30)
	altarGui.MaxDistance = 100
	altarGui.Parent = altarAnchor
	local altarLabel = Instance.new("TextLabel")
	altarLabel.Size = UDim2.fromScale(1, 1)
	altarLabel.BackgroundColor3 = c(38, 42, 52)
	altarLabel.BackgroundTransparency = 0.15
	altarLabel.Font = Enum.Font.GothamBold
	altarLabel.TextScaled = true
	altarLabel.TextColor3 = c(190, 160, 255)
	altarLabel.Text = "RENACER"
	altarLabel.Parent = altarGui
	local altarCorner = Instance.new("UICorner")
	altarCorner.CornerRadius = UDim.new(0, 10)
	altarCorner.Parent = altarLabel
	local altarPad = Instance.new("UIPadding")
	altarPad.PaddingTop = UDim.new(0, 3)
	altarPad.PaddingBottom = UDim.new(0, 3)
	altarPad.Parent = altarLabel
	local altarPrompt = Instance.new("ProximityPrompt")
	altarPrompt.ActionText = "Renacer"
	altarPrompt.ObjectText = "Altar de renacimiento"
	altarPrompt.HoldDuration = 0
	altarPrompt.MaxActivationDistance = 14
	altarPrompt.RequiresLineOfSight = false
	altarPrompt.Parent = altar

	local fuse = {
		Rebirth = { Prompt = altarPrompt, Position = Vector3.new(ax, 3, az) },
		Prompt = fusePrompt,
		Position = Vector3.new(fx, 3, fz),
		Top = { Gui = topGui, Image = topImage, Name = topName },
	}

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

	return fuse
end

-- Tienda con su ProximityPrompt y un emblema flotante encima. `facing` es hacia donde
-- mira el frente.
local function buildShop(parent, position, facing, def)
	local origin = CFrame.lookAt(position, position + facing)
	local shop = BuildingModels.Shop(origin, def.Text, def.Accent)
	shop.Parent = parent

	local emblem = BuildingModels.Emblem(def.Id, origin * CFrame.new(0, 18, 0))
	emblem.Parent = parent

	-- Vendedor junto a la ventana, mirando hacia el frente de la tienda.
	if def.Npc then
		local npcPosition = origin:PointToWorldSpace(Vector3.new(5.5, 0, -8.2))
		local npc = Npcs.Build(CFrame.lookAt(npcPosition, npcPosition + facing), def.Npc)
		npc.Parent = parent
	end

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
	{
		Id = "Sell", Kind = "Upgrade", Text = "VENDER", Accent = c(235, 175, 40), ObjectText = "Vender minerales",
		Npc = { Skin = 2, Hair = c(110, 60, 35), Hairstyle = "Ponytail", Accent = c(235, 175, 40), Item = "Gem", ItemColor = c(255, 120, 200), Wave = true },
	},
	{
		Id = "Pickaxe", Kind = "Upgrade", Text = "PICO", Accent = c(235, 130, 40), ObjectText = "Mejorar pico",
		Npc = { Skin = 3, Hair = c(35, 25, 20), Hairstyle = "Short", Accent = c(235, 130, 40), Item = "Pickaxe", Antenna = true },
	},
	{
		Id = "Strength", Kind = "Upgrade", Text = "FUERZA", Accent = c(230, 90, 90), ObjectText = "Mejorar fuerza",
		Npc = { Skin = 4, Hair = c(25, 20, 20), Hairstyle = "Bun", Accent = c(230, 90, 90), Wave = true },
	},
	{
		Id = "Speed", Kind = "Upgrade", Text = "VELOCIDAD", Accent = c(60, 170, 255), ObjectText = "Mejorar velocidad",
		Npc = { Skin = 1, Hair = c(230, 190, 90), Hairstyle = "Short", Accent = c(60, 170, 255), Antenna = true, Wave = true },
	},
}

local ROBUX_SHOPS = {
	{
		Id = "X2", Kind = "Robux", Text = "x2 DINERO", Accent = c(70, 190, 110), ObjectText = "Doble de dinero",
		Npc = { Skin = 2, Hair = c(70, 45, 30), Hairstyle = "Short", Accent = c(70, 190, 110), Item = "Gem", ItemColor = c(255, 215, 80) },
	},
	{
		Id = "Boots", Kind = "Robux", Text = "BOTAS VIP", Accent = c(70, 190, 110), ObjectText = "Botas lunares VIP",
		Npc = { Skin = 1, Hair = c(240, 120, 160), Hairstyle = "Long", Accent = c(70, 190, 110), Wave = true },
	},
	{
		Id = "Shield", Kind = "Robux", Text = "ESCUDO", Accent = c(70, 190, 110), ObjectText = "Escudo anti-Alien",
		Npc = { Skin = 4, Hair = c(20, 20, 25), Hairstyle = "Short", Accent = c(70, 190, 110), Antenna = true },
	},
	{
		Id = "Credits", Kind = "Robux", Text = "PAQUETES $", Accent = c(70, 190, 110), ObjectText = "Paquetes de dinero",
		Npc = { Skin = 3, Hair = c(40, 30, 25), Hairstyle = "Long", Accent = c(70, 190, 110), Wave = true },
	},
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
		longX(-15, MINE_LENGTH + 15, function(centerX, length)
			part({
				Name = "RimBarrier",
				Size = Vector3.new(length, BARRIER_HEIGHT, 12),
				Position = Vector3.new(centerX, BARRIER_HEIGHT / 2, sign * (HALF_WIDTH + 5)),
				Transparency = 1,
				CanCollide = true,
			}, folder)
		end)
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
		longX(-10, MINE_LENGTH + 10, function(centerX, length)
			part({ Name = "Wall", Size = Vector3.new(length, 24, 10), Position = Vector3.new(centerX, 12, z), Color = ROCK_DARK, Material = Enum.Material.Slate, CanCollide = true }, mine)
		end)
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
	arch(mine, 0, 70, "MINA LUNAR - ZONA 1", c(255, 200, 40))
	for zone = 2, Config.ZoneCount do
		arch(mine, (zone - 1) * Config.ZoneLength, 70, Config.Zones[zone].Name:upper(), Config.Zones[zone].GemColor)
	end

	-- Carteles de profundidad cada 100 studs.
	for depth = 100, MINE_LENGTH, 100 do
		part({ Name = "MarkerPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 0.9, 0.9), CFrame = CFrame.new(depth, 3.5, -HALF_WIDTH + 12) * VERTICAL, Color = STEEL, Material = Enum.Material.Metal }, mine)
		board(mine, facingBase(Vector3.new(depth, 8, -HALF_WIDTH + 12)), Vector3.new(7, 3, 0.5), depth .. " m", PANEL_DARK, WHITE)
	end
end

-- Construye el mundo y devuelve { Bases = {...}, Shops = {...}, Fuse = { Prompt, Position } }.
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
	local fuse = buildPlaza(world)

	return {
		Bases = buildBases(world),
		Shops = buildShops(world),
		Fuse = fuse,
	}
end

return WorldBuilder
