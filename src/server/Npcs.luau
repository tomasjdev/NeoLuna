-- Vendedores de las tiendas: personajes con cuerpo de jugador de Roblox (cabeza, torso,
-- brazos y piernas) vestidos de astronauta, armados con piezas y anclados junto a la tienda.
-- Saludan con la mano o se mecen. El frente mira a -Z de `origin`.

local TweenService = game:GetService("TweenService")

local Npcs = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local SKINS = {
	c(255, 214, 178),
	c(234, 184, 140),
	c(190, 130, 90),
	c(130, 88, 62),
}

local SUIT = c(240, 242, 248)
local GLOVE = c(150, 156, 170)
local PACK = c(170, 176, 190)

-- def = { Skin = 1..4, Hair = Color3, Hairstyle = "Short" | "Long" | "Ponytail" | "Bun",
--         Accent = Color3 (detalles del traje), Antenna = boolean, Item = "Pickaxe" | "Gem",
--         ItemColor = Color3, Wave = boolean }
function Npcs.Build(origin, def)
	local model = Instance.new("Model")
	model.Name = "Vendedor"

	local skin = SKINS[def.Skin or 1]
	local hair = def.Hair or c(60, 40, 30)
	local accent = def.Accent or c(70, 140, 220)

	local root
	local function piece(name, offset, size, color, opts)
		opts = opts or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = opts.Material or Enum.Material.SmoothPlastic
		p.Shape = opts.Shape or Enum.PartType.Block
		p.Transparency = opts.Transparency or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = origin * CFrame.new(offset) * (opts.Rotation or CFrame.identity)
		p.Anchored = root == nil
		p.Parent = model
		if root then
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = p
			weld.C0 = root.CFrame:ToObjectSpace(p.CFrame)
			weld.Parent = p
		end
		return p
	end

	local function ball(name, offset, diameter, color, opts)
		opts = opts or {}
		opts.Shape = Enum.PartType.Ball
		return piece(name, offset, Vector3.one * diameter, color, opts)
	end

	-- Torso (pieza principal) y piernas.
	root = piece("Torso", Vector3.new(0, 3.4, 0), Vector3.new(2, 2, 1), SUIT)
	model.PrimaryPart = root
	piece("LegL", Vector3.new(-0.5, 1.2, 0), Vector3.new(0.95, 2.4, 1), SUIT)
	piece("LegR", Vector3.new(0.5, 1.2, 0), Vector3.new(0.95, 2.4, 1), SUIT)
	piece("KneeL", Vector3.new(-0.5, 1.3, -0.05), Vector3.new(1.05, 0.35, 1.1), accent)
	piece("KneeR", Vector3.new(0.5, 1.3, -0.05), Vector3.new(1.05, 0.35, 1.1), accent)
	piece("BootL", Vector3.new(-0.5, 0.35, -0.1), Vector3.new(1.1, 0.7, 1.3), GLOVE)
	piece("BootR", Vector3.new(0.5, 0.35, -0.1), Vector3.new(1.1, 0.7, 1.3), GLOVE)
	piece("Belt", Vector3.new(0, 2.55, 0), Vector3.new(2.1, 0.3, 1.1), accent)

	-- Panel del pecho, mochila de aire y antena.
	piece("ChestPanel", Vector3.new(0, 3.7, -0.52), Vector3.new(1.3, 0.8, 0.1), accent)
	ball("ButtonA", Vector3.new(-0.3, 3.7, -0.6), 0.25, c(255, 235, 120), { Material = Enum.Material.Neon })
	ball("ButtonB", Vector3.new(0.3, 3.7, -0.6), 0.25, c(120, 255, 170), { Material = Enum.Material.Neon })
	piece("Backpack", Vector3.new(0, 3.5, 0.9), Vector3.new(1.6, 2.1, 0.8), PACK)
	piece("BackpackStripe", Vector3.new(0, 3.9, 1.31), Vector3.new(1.3, 0.35, 0.05), accent)

	-- Cabeza de jugador: cilindro redondeado con cara.
	local headY = 5.2
	piece("Head", Vector3.new(0, headY, 0), Vector3.new(1.3, 1.7, 1.7), skin, { Shape = Enum.PartType.Cylinder, Rotation = VERTICAL })
	ball("EyeL", Vector3.new(-0.38, headY + 0.1, -0.83), 0.3, c(30, 30, 40))
	ball("EyeR", Vector3.new(0.38, headY + 0.1, -0.83), 0.3, c(30, 30, 40))
	ball("ShineL", Vector3.new(-0.42, headY + 0.18, -0.96), 0.1, c(255, 255, 255))
	ball("ShineR", Vector3.new(0.34, headY + 0.18, -0.96), 0.1, c(255, 255, 255))
	piece("Smile", Vector3.new(0, headY - 0.33, -0.84), Vector3.new(0.55, 0.11, 0.16), c(150, 60, 70))
	ball("CheekL", Vector3.new(-0.68, headY - 0.15, -0.7), 0.3, c(255, 150, 150))
	ball("CheekR", Vector3.new(0.68, headY - 0.15, -0.7), 0.3, c(255, 150, 150))

	-- Pelo (se ve a través del casco).
	local style = def.Hairstyle or "Short"
	piece("HairTop", Vector3.new(0, headY + 0.72, 0.05), Vector3.new(0.5, 1.8, 1.8), hair, { Shape = Enum.PartType.Cylinder, Rotation = VERTICAL })
	if style == "Long" then
		piece("HairBack", Vector3.new(0, headY - 0.3, 0.68), Vector3.new(1.9, 2.1, 0.5), hair)
		piece("HairSideL", Vector3.new(-0.92, headY - 0.1, 0.1), Vector3.new(0.35, 1.5, 1.2), hair)
		piece("HairSideR", Vector3.new(0.92, headY - 0.1, 0.1), Vector3.new(0.35, 1.5, 1.2), hair)
	elseif style == "Ponytail" then
		piece("HairBack", Vector3.new(0, headY + 0.1, 0.7), Vector3.new(1.8, 1.2, 0.4), hair)
		ball("Ponytail", Vector3.new(0, headY + 0.1, 1.05), 0.8, hair)
		piece("PonytailTip", Vector3.new(0, headY - 0.55, 1.1), Vector3.new(0.5, 1.2, 0.5), hair)
	elseif style == "Bun" then
		ball("Bun", Vector3.new(0, headY + 1.2, 0.1), 0.8, hair)
		piece("HairBack", Vector3.new(0, headY + 0.05, 0.7), Vector3.new(1.8, 1.2, 0.4), hair)
	else
		piece("HairBack", Vector3.new(0, headY + 0.15, 0.7), Vector3.new(1.8, 1.0, 0.4), hair)
	end

	-- Casco de vidrio, anillo del cuello y antena.
	ball("Helmet", Vector3.new(0, headY + 0.05, 0), 3.0, c(190, 225, 255), { Transparency = 0.6, Material = Enum.Material.Glass })
	piece("Collar", Vector3.new(0, 4.5, 0), Vector3.new(0.4, 2.3, 2.3), accent, { Shape = Enum.PartType.Cylinder, Rotation = VERTICAL })
	if def.Antenna then
		piece("Antenna", Vector3.new(0.9, headY + 1.9, 0.3), Vector3.new(0.12, 0.9, 0.12), GLOVE)
		ball("AntennaTip", Vector3.new(0.9, headY + 2.4, 0.3), 0.3, accent, { Material = Enum.Material.Neon })
	end

	-- Brazos: giran desde el hombro con un Motor6D; el guante va soldado al brazo.
	local function arm(name, side)
		local shoulder = Vector3.new(side * 1.5, 4.4, 0)
		local limb = piece(name, shoulder + Vector3.new(0, -1.0, 0), Vector3.new(1, 2, 1), SUIT)
		local patch = piece(name .. "Patch", shoulder + Vector3.new(side * 0.52, -0.4, 0), Vector3.new(0.08, 0.7, 0.7), accent)
		local glove = ball(name .. "Glove", shoulder + Vector3.new(0, -2.1, 0), 1.05, GLOVE)
		local shoulderCF = origin * CFrame.new(shoulder)

		limb:FindFirstChildOfClass("Weld"):Destroy()
		local motor = Instance.new("Motor6D")
		motor.Part0 = root
		motor.Part1 = limb
		motor.C0 = root.CFrame:ToObjectSpace(shoulderCF)
		motor.C1 = limb.CFrame:ToObjectSpace(shoulderCF)
		motor.Parent = limb

		for _, extra in { patch, glove } do
			extra:FindFirstChildOfClass("Weld"):Destroy()
			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = extra
			weld.C0 = limb.CFrame:ToObjectSpace(extra.CFrame)
			weld.Parent = extra
		end
		return motor
	end

	arm("ArmL", -1)
	local armR = arm("ArmR", 1)

	-- Objeto en la mano izquierda según el oficio.
	if def.Item == "Pickaxe" then
		piece("PickHandle", Vector3.new(-1.5, 2.3, -0.7), Vector3.new(0.3, 3.8, 0.3), c(140, 95, 55))
		piece("PickHead", Vector3.new(-1.5, 4.1, -0.7), Vector3.new(2.0, 0.45, 0.4), GLOVE, { Material = Enum.Material.Metal })
	elseif def.Item == "Gem" then
		ball("Gem", Vector3.new(-1.5, 1.9, -0.8), 0.9, def.ItemColor or c(120, 220, 255), { Material = Enum.Material.Neon })
	end

	-- Animación: saluda con el brazo derecho; todos se mecen suavemente.
	if def.Wave then
		local base = armR.C0
		armR.C0 = base * CFrame.Angles(0, 0, math.rad(140))
		TweenService:Create(
			armR,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ C0 = base * CFrame.Angles(0, 0, math.rad(175)) }
		):Play()
	end
	local sway = root.CFrame
	root.CFrame = sway * CFrame.new(0, -0.08, 0)
	TweenService:Create(
		root,
		TweenInfo.new(1.1 + (def.Skin or 1) * 0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = sway * CFrame.new(0, 0.1, 0) }
	):Play()

	return model
end

return Npcs
