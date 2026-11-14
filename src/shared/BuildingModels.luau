-- Modelos de construcciones (cartoon, colores pastel, formas redondeadas).
-- Cada función recibe `origin`: CFrame de la base de la construcción y devuelve
-- un Model con WorldPivot en esa base. El frente mira a -Z.

local BuildingModels = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WHITE = c(250, 247, 255)
local SKY = c(170, 220, 255)
local RED = c(240, 100, 110)
local BLUE = c(110, 170, 255)

-- Crea una pieza posicionada respecto al origen.
local function piece(model, origin, offset, size, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = opts.Material or Enum.Material.SmoothPlastic
	p.Shape = opts.Shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Transparency = opts.Transparency or 0
	p.CFrame = origin * CFrame.new(offset) * (opts.Rotation or CFrame.identity)
	p.Parent = model
	return p
end

local function textBoard(model, origin, offset, size, text, background, textColor)
	local board = piece(model, origin, offset, size, background)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.Parent = gui
	return board
end

-- Tienda: fachada amarilla con toldo de rayas y cartel.
function BuildingModels.Shop(origin)
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.WorldPivot = origin

	piece(model, origin, Vector3.new(0, 4, 0), Vector3.new(16, 8, 12), c(255, 225, 150))
	piece(model, origin, Vector3.new(0, 8.6, 0), Vector3.new(17, 1.2, 13), RED)
	for i = 0, 3 do
		piece(
			model,
			origin,
			Vector3.new(-6 + i * 4, 6.6, -7.5),
			Vector3.new(4, 0.8, 4),
			if i % 2 == 0 then RED else WHITE
		)
	end
	piece(model, origin, Vector3.new(-4, 2.5, -6.1), Vector3.new(3.4, 5, 0.5), BLUE)
	piece(model, origin, Vector3.new(4, 3.6, -6.1), Vector3.new(5, 3.6, 0.5), SKY, { Material = Enum.Material.Glass })
	textBoard(model, origin, Vector3.new(0, 11.2, -5.5), Vector3.new(9, 2.6, 0.6), "TIENDA", WHITE, RED)
	return model
end

return BuildingModels
