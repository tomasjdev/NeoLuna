-- Props procedurales: ovni, pico lanzado y gema que carga el jugador.
-- Sustitutos de los modelos de Blender de más adelante: mismas funciones.

local Props = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- tumba un cilindro (eje X -> eje Y)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
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

-- Ovni simpático: platillo menta con cúpula de cristal, alienígena sonriente y
-- luces de colores. Se centra en el origen; el rayo de luz sale por debajo.
function Props.Ufo()
	local model = Instance.new("Model")
	model.Name = "Ufo"

	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 9, 9),
		CFrame = CFrame.new(0, 0, 0) * VERTICAL,
		Color = c(170, 235, 200),
	}, model)
	model.PrimaryPart = body

	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 10.4, 10.4),
		CFrame = CFrame.new(0, -0.2, 0) * VERTICAL,
		Color = c(255, 205, 120),
	}, model)

	part({
		Name = "Alien",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		CFrame = CFrame.new(0, 1.5, 0),
		Color = c(130, 220, 120),
	}, model)
	for _, x in { -0.5, 0.5 } do
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5,
			CFrame = CFrame.new(x, 1.7, -1.05),
			Color = c(40, 30, 70),
		}, model)
	end
	part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		CFrame = CFrame.new(0, 1.4, 0),
		Color = c(200, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	}, model)

	local lights = { c(255, 150, 190), c(255, 235, 130), c(150, 200, 255) }
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		part({
			Name = "Light",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = CFrame.new(math.cos(angle) * 4.6, -0.3, math.sin(angle) * 4.6),
			Color = lights[i % #lights + 1],
		}, model)
	end

	part({
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 3.8, 3.8),
		CFrame = CFrame.new(0, -4.2, 0) * VERTICAL,
		Color = c(255, 240, 150),
		Transparency = 0.75,
	}, model)

	return model
end

-- Pico lanzado: mango de madera y cabeza de metal pastel.
function Props.Pickaxe()
	local model = Instance.new("Model")
	model.Name = "ThrownPickaxe"

	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.5, 0.5, 3.4),
		CFrame = CFrame.new(0, 0, 0),
		Color = c(200, 145, 100),
	}, model)
	model.PrimaryPart = handle

	part({
		Name = "Head",
		Size = Vector3.new(3.2, 0.6, 0.7),
		CFrame = CFrame.new(0, 0, -1.7),
		Color = c(150, 175, 220),
	}, model)
	part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		CFrame = CFrame.new(0, 0, -1.7),
		Color = c(255, 215, 90),
	}, model)

	return model
end

-- Gema que flota sobre la cabeza del jugador mientras carga un mineral.
-- Devuelve la pieza (no anclada, soldada a la cabeza); destruirla la quita.
function Props.CarriedGem(character, color)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gem = Instance.new("Part")
	gem.Name = "CarriedGem"
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.one * 2.2
	gem.Color = color
	gem.Material = Enum.Material.Glass
	gem.Transparency = 0.1
	gem.CanCollide = false
	gem.CanTouch = false
	gem.CanQuery = false
	gem.Massless = true
	gem.CFrame = head.CFrame * CFrame.new(0, 3, 0)
	gem.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = gem
	weld.Parent = gem
	return gem
end

return Props
