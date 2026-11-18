-- Modelos de construcciones (cartoon, colores pastel, formas redondeadas).
-- Cada función recibe `origin`: CFrame de la base de la construcción y devuelve
-- un Model con WorldPivot en esa base. El frente mira a -Z.

local BuildingModels = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WHITE = c(235, 235, 240)
local SKY = c(120, 150, 185)
local RED = c(235, 130, 40)
local BLUE = c(70, 90, 125)

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

-- Tienda: módulo gris claro con toldo de color y cartel.
function BuildingModels.Shop(origin, text, accent)
	text = text or "TIENDA"
	accent = accent or RED
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.WorldPivot = origin

	piece(model, origin, Vector3.new(0, 4, 0), Vector3.new(16, 8, 12), c(205, 208, 216))
	piece(model, origin, Vector3.new(0, 8.6, 0), Vector3.new(17, 1.2, 13), accent)
	for i = 0, 3 do
		piece(
			model,
			origin,
			Vector3.new(-6 + i * 4, 6.6, -7.5),
			Vector3.new(4, 0.8, 4),
			if i % 2 == 0 then accent else WHITE
		)
	end
	piece(model, origin, Vector3.new(-4, 2.5, -6.1), Vector3.new(3.4, 5, 0.5), BLUE)
	piece(model, origin, Vector3.new(4, 3.6, -6.1), Vector3.new(5, 3.6, 0.5), SKY, { Material = Enum.Material.Glass })
	textBoard(model, origin, Vector3.new(0, 11.2, -5.5), Vector3.new(9, 2.6, 0.6), text, c(38, 42, 52), accent)

	-- La tienda es sólida: no se puede atravesar.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = true
		end
	end
	return model
end

local GOLD = c(255, 205, 70)
local STEEL_BLUE = c(150, 170, 215)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- tumba un cilindro (eje X -> eje Y)

local function ball(model, origin, offset, diameter, color)
	return piece(model, origin, offset, Vector3.one * diameter, color, { Shape = Enum.PartType.Ball })
end

-- Pila de monedas (cilindros verticales).
local function coinStack(model, origin, offset, count, color)
	for i = 0, count - 1 do
		piece(model, origin, offset + Vector3.new(0, i * 1.15, 0), Vector3.new(1, 5, 5), color, { Shape = Enum.PartType.Cylinder, Rotation = VERTICAL })
		piece(model, origin, offset + Vector3.new(0, i * 1.15, 0), Vector3.new(1.1, 3.6, 3.6), c(255, 235, 150), { Shape = Enum.PartType.Cylinder, Rotation = VERTICAL })
	end
end

-- Emblemas que flotan sobre el techo de cada tienda; `origin` es su centro.
-- Kinds: Pickaxe, Strength, Speed, Capacity, Sell, X2, Boots, Shield, Credits.
function BuildingModels.Emblem(kind, origin)
	local model = Instance.new("Model")
	model.Name = "Emblem" .. kind
	model.WorldPivot = origin

	if kind == "Pickaxe" then
		piece(model, origin, Vector3.new(0, 0, 0), Vector3.new(1, 10, 1), c(200, 145, 100))
		piece(model, origin, Vector3.new(-2.6, 4.4, 0), Vector3.new(5.6, 1.3, 1.1), STEEL_BLUE, { Rotation = CFrame.Angles(0, 0, math.rad(18)) })
		piece(model, origin, Vector3.new(2.6, 4.4, 0), Vector3.new(5.6, 1.3, 1.1), STEEL_BLUE, { Rotation = CFrame.Angles(0, 0, math.rad(-18)) })
		ball(model, origin, Vector3.new(-5.3, 3.3, 0), 1.4, GOLD)
		ball(model, origin, Vector3.new(5.3, 3.3, 0), 1.4, GOLD)
	elseif kind == "Strength" then
		piece(model, origin, Vector3.new(0, 0, 0), Vector3.new(9, 1, 1), c(120, 125, 140), { Shape = Enum.PartType.Cylinder })
		for _, side in { -1, 1 } do
			piece(model, origin, Vector3.new(side * 3.4, 0, 0), Vector3.new(1.3, 6, 6), c(230, 90, 90), { Shape = Enum.PartType.Cylinder })
			piece(model, origin, Vector3.new(side * 4.8, 0, 0), Vector3.new(1.3, 4, 4), c(70, 70, 82), { Shape = Enum.PartType.Cylinder })
		end
	elseif kind == "Speed" then
		-- Rayo en zigzag: tres tramos (arriba, travesaño y punta) con el mismo grosor.
		local yellow = c(255, 215, 60)
		local function bar(from, to, thickness)
			local delta = to - from
			local mid = (from + to) / 2
			piece(
				model,
				origin,
				Vector3.new(mid.X, mid.Y, 0),
				Vector3.new(delta.Magnitude + thickness * 0.9, thickness, 1.2),
				yellow,
				{ Rotation = CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X)), Material = Enum.Material.Neon }
			)
		end
		bar(Vector3.new(2.2, 5.2, 0), Vector3.new(-1.2, 0.8, 0), 2.2) -- tramo de arriba
		bar(Vector3.new(-2.6, 0.4, 0), Vector3.new(2.6, 0.4, 0), 2) -- travesaño
		bar(Vector3.new(1.2, -0.2, 0), Vector3.new(-2.2, -5.4, 0), 2.2) -- punta de abajo
	elseif kind == "Capacity" then
		-- Mochila: cuerpo morado, bolsillo, correas y gemita.
		local purple = c(150, 110, 230)
		piece(model, origin, Vector3.new(0, 0, 0), Vector3.new(6, 8, 3.4), purple)
		piece(model, origin, Vector3.new(0, -1.6, -2), Vector3.new(4.4, 3.4, 1.2), c(120, 85, 200))
		piece(model, origin, Vector3.new(0, 4.4, 0), Vector3.new(3, 1.2, 2.4), c(120, 85, 200))
		ball(model, origin, Vector3.new(0, -1.6, -2.8), 1.2, GOLD)
	elseif kind == "Sell" then
		coinStack(model, origin, Vector3.new(0, -2.5, 0), 5, GOLD)
	elseif kind == "X2" then
		textBoard(model, origin, Vector3.new(0, 0, 0), Vector3.new(9, 6, 0.8), "x2", c(38, 42, 52), GOLD)
	elseif kind == "Boots" then
		local green = c(70, 190, 110)
		piece(model, origin, Vector3.new(-0.6, 1.6, 0), Vector3.new(2.6, 5, 2.6), green)
		piece(model, origin, Vector3.new(0.8, -1.7, 0), Vector3.new(5.6, 2.2, 2.8), green)
		piece(model, origin, Vector3.new(0.8, -3, 0), Vector3.new(5.8, 0.7, 3), WHITE)
		ball(model, origin, Vector3.new(-0.6, 4.6, 0), 1.6, GOLD)
	elseif kind == "Shield" then
		local face = CFrame.Angles(0, math.rad(90), 0) -- el disco mira a -Z
		piece(model, origin, Vector3.new(0, 0, 0.4), Vector3.new(0.5, 9.2, 9.2), WHITE, { Shape = Enum.PartType.Cylinder, Rotation = face })
		piece(model, origin, Vector3.new(0, 0, 0), Vector3.new(0.8, 8, 8), c(90, 150, 235), { Shape = Enum.PartType.Cylinder, Rotation = face })
		ball(model, origin, Vector3.new(0, 0, -0.7), 2.8, GOLD)
	elseif kind == "Credits" then
		coinStack(model, origin, Vector3.new(-3.2, -2.5, 0), 3, GOLD)
		coinStack(model, origin, Vector3.new(0, -2.5, 0), 5, GOLD)
		coinStack(model, origin, Vector3.new(3.2, -2.5, 0), 2, GOLD)
	end
	return model
end


return BuildingModels
