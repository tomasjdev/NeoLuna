-- Cielo detallado que se ve igual estés donde estés: una "caja" de 5 caras (4 lados y arriba) con
-- estrellas, nebulosas y planetas dibujados, que sigue a la cámara (como el cielo de Roblox).
-- Se crea solo en la pantalla de cada jugador. Las estrellas y los planetas se dibujan en la parte
-- alta de cada cara (más de 20 grados sobre el horizonte), para que no se vean sobre las colinas.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SkyDome = {}

local DISTANCE = 900 -- de la cámara al centro de cada cara
local FACE_SIZE = 1800 -- 2 x DISTANCE: cada cara cubre justo 90 grados
local CANVAS = 1024
local HORIZON_LIMIT = 0.30 -- en las caras laterales, solo se dibuja por encima de esta altura (0 = arriba)

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function newFrame(parent, props)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	for key, value in props do
		frame[key] = value
	end
	frame.Parent = parent
	return frame
end

local function circle(parent, x, y, diameter, color, transparency)
	local frame = newFrame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(diameter, diameter),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

local function blob(parent, x, y, width, height, rotation, color, transparency)
	local frame = newFrame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		Rotation = rotation,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.45, 0)
	corner.Parent = frame
	return frame
end

-- Estrellas de distintos tamaños y tonos. `maxV`: hasta qué altura (0 a 1) se dibujan.
local function stars(root, rng, count, maxV)
	local tones = { c(255, 255, 255), c(255, 240, 205), c(190, 215, 255), c(255, 205, 225), c(210, 255, 240) }
	for _ = 1, count do
		local size = rng:NextNumber(0.0018, 0.007)
		if rng:NextNumber() < 0.06 then
			size = rng:NextNumber(0.008, 0.013) -- alguna estrella más grande
		end
		local star = circle(root, rng:NextNumber(0.02, 0.98), rng:NextNumber(0.01, maxV), size, tones[rng:NextInteger(1, #tones)], rng:NextNumber(0, 0.4))
		star.Size = UDim2.fromScale(size, size)
	end
end

local function nebula(root, rng, palette, region)
	for _ = 1, 14 do
		local d = rng:NextNumber(0.18, 0.5)
		circle(
			root,
			rng:NextNumber(region.X0, region.X1),
			rng:NextNumber(region.Y0, region.Y1),
			d,
			palette[rng:NextInteger(1, #palette)],
			rng:NextNumber(0.9, 0.968)
		)
	end
end

-- Planetas (todos pequeños dentro de la cara, en la parte alta).
local function gasGiant(root, x, y, size)
	blob(root, x, y, size * 1.7, size * 0.3, -16, c(235, 215, 175), 0.4) -- anillo detrás
	circle(root, x, y, size, c(225, 165, 105))
	for _, band in { { -0.22, 0.88, c(190, 120, 75) }, { -0.08, 0.95, c(245, 205, 150) }, { 0.08, 0.9, c(185, 115, 80) }, { 0.22, 0.7, c(240, 195, 140) } } do
		blob(root, x, y + size * band[1], size * band[2], size * 0.085, 0, band[3], 0.15)
	end
	circle(root, x + size * 0.1, y, size, c(0, 5, 25), 0.65) -- sombra
	blob(root, x, y + size * 0.04, size * 1.75, size * 0.11, -16, c(235, 215, 175), 0.35) -- anillo por delante
end

local function roundPlanet(root, x, y, size, base, light, dark)
	circle(root, x, y, size * 1.18, light, 0.88) -- halo
	circle(root, x, y, size, base)
	circle(root, x - size * 0.12, y - size * 0.14, size * 0.46, light, 0.5)
	circle(root, x + size * 0.18, y + size * 0.16, size * 0.14, dark, 0.35)
	circle(root, x - size * 0.2, y + size * 0.2, size * 0.09, dark, 0.35)
	circle(root, x + size * 0.1, y, size, c(0, 5, 25), 0.6) -- sombra
end

local function ringedPlanet(root, x, y, size, base, ring)
	blob(root, x, y, size * 1.9, size * 0.34, 18, ring, 0.45)
	circle(root, x, y, size, base)
	blob(root, x, y - size * 0.15, size * 0.9, size * 0.07, 0, ring, 0.55)
	circle(root, x + size * 0.1, y, size, c(0, 5, 25), 0.6)
	blob(root, x, y + size * 0.05, size * 1.9, size * 0.12, 18, ring, 0.35)
end

-- Qué se dibuja en cada cara.
local FACES = {
	{
		Name = "East", Direction = Vector3.new(1, 0, 0), Up = Vector3.yAxis, Seed = 1, Stars = 280, Side = true,
		Draw = function(root, rng)
			nebula(root, rng, { c(60, 190, 220), c(60, 120, 230), c(110, 230, 190) }, { X0 = 0.2, X1 = 0.8, Y0 = 0.05, Y1 = 0.25 })
			roundPlanet(root, 0.72, 0.14, 0.075, c(110, 200, 150), c(170, 240, 200), c(60, 130, 90))
		end,
	},
	{
		Name = "West", Direction = Vector3.new(-1, 0, 0), Up = Vector3.yAxis, Seed = 2, Stars = 280, Side = true,
		Draw = function(root, rng)
			nebula(root, rng, { c(150, 80, 230), c(90, 70, 210), c(230, 90, 190) }, { X0 = 0.15, X1 = 0.85, Y0 = 0.05, Y1 = 0.25 })
			gasGiant(root, 0.42, 0.15, 0.15)
			roundPlanet(root, 0.85, 0.2, 0.05, c(200, 90, 70), c(240, 150, 110), c(150, 60, 50))
		end,
	},
	{
		Name = "North", Direction = Vector3.new(0, 0, -1), Up = Vector3.yAxis, Seed = 3, Stars = 280, Side = true,
		Draw = function(root, rng)
			nebula(root, rng, { c(240, 110, 90), c(230, 160, 80), c(200, 70, 150) }, { X0 = 0.2, X1 = 0.8, Y0 = 0.05, Y1 = 0.25 })
			roundPlanet(root, 0.3, 0.17, 0.11, c(125, 80, 205), c(190, 135, 255), c(90, 55, 160))
			ringedPlanet(root, 0.75, 0.11, 0.06, c(120, 190, 235), c(235, 245, 255))
		end,
	},
	{
		Name = "South", Direction = Vector3.new(0, 0, 1), Up = Vector3.yAxis, Seed = 4, Stars = 280, Side = true,
		Draw = function(root, rng)
			nebula(root, rng, { c(150, 80, 230), c(60, 190, 220), c(230, 90, 190) }, { X0 = 0.2, X1 = 0.8, Y0 = 0.05, Y1 = 0.25 })
			roundPlanet(root, 0.6, 0.15, 0.085, c(200, 232, 255), c(235, 248, 255), c(150, 190, 225))
			roundPlanet(root, 0.2, 0.22, 0.045, c(235, 190, 90), c(255, 225, 150), c(190, 140, 60))
		end,
	},
	{
		Name = "Top", Direction = Vector3.new(0, 1, 0), Up = Vector3.new(0, 0, -1), Seed = 5, Stars = 700, Side = false,
		Draw = function(root, rng)
			nebula(root, rng, { c(150, 80, 230), c(90, 70, 210), c(60, 190, 220), c(230, 90, 190) }, { X0 = 0.15, X1 = 0.85, Y0 = 0.15, Y1 = 0.85 })
			ringedPlanet(root, 0.7, 0.35, 0.09, c(230, 150, 100), c(250, 225, 190))
			roundPlanet(root, 0.28, 0.66, 0.07, c(110, 210, 170), c(175, 245, 215), c(60, 140, 105))
		end,
	},
}

-- Roblox dibuja el contenido de cada cara la primera vez que entra en pantalla, así que sin esto
-- las estrellas y los planetas "aparecían" al mirar hacia ellos. Al empezar se mira un instante
-- hacia cada cara (con la pantalla tapada) para que todas queden dibujadas desde el principio.
local function prewarm(parts, cover)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local previous = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	for _, entry in parts do
		camera.CFrame = CFrame.lookAt(previous.Position, previous.Position + entry.Face.Direction, entry.Face.Up)
		RunService.RenderStepped:Wait()
		task.wait(0.3)
	end
	camera.CFrame = previous
	camera.CameraType = Enum.CameraType.Custom
	if cover then
		TweenService:Create(cover, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function()
			cover.Parent:Destroy()
		end)
	end
end

function SkyDome.start()
	-- Pantalla negra mientras se prepara el cielo (dura un par de segundos).
	local coverGui = Instance.new("ScreenGui")
	coverGui.Name = "NeoLunaSkyCover"
	coverGui.ResetOnSpawn = false
	coverGui.IgnoreGuiInset = true
	coverGui.DisplayOrder = 1000
	local cover = Instance.new("Frame")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(2, 4, 18)
	cover.BorderSizePixel = 0
	cover.Parent = coverGui
	coverGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local folder = Instance.new("Folder")
	folder.Name = "NeoLunaSkyDome"
	folder.Parent = workspace

	local parts = {}
	for _, face in FACES do
		local rng = Random.new(face.Seed * 101)
		local part = Instance.new("Part")
		part.Name = "Sky" .. face.Name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(FACE_SIZE, FACE_SIZE, 1)
		part.Parent = folder

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(CANVAS, CANVAS)
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		pcall(function()
			gui.MaxDistance = 1e5
		end)
		gui.Parent = part

		local root = newFrame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		stars(root, rng, face.Stars, if face.Side then HORIZON_LIMIT else 0.98)
		face.Draw(root, rng)
		table.insert(parts, { Part = part, Face = face })
	end

	-- El cielo siempre está centrado en la cámara, así que se ve igual desde cualquier lugar.
	RunService:BindToRenderStep("NeoLunaSkyDome", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = camera.CFrame.Position
		for _, entry in parts do
			local position = origin + entry.Face.Direction * DISTANCE
			entry.Part.CFrame = CFrame.lookAt(position, origin, entry.Face.Up)
		end
	end)

	prewarm(parts, cover)
end

return SkyDome
