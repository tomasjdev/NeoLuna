-- Ambiente del cielo: transbordadores, un carguero, exploradores, satélites, una estación espacial
-- y asteroides que vuelan o flotan lejos y en lo alto. Todo se crea y se anima en la pantalla de
-- cada jugador (nada pesa en el servidor), no choca con nada y no se puede tocar.
-- Los modelos son de Blender (ver art/); si no cargan, simplemente no aparece nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtAssets = require(ReplicatedStorage.Shared.ArtAssets)

local Ambient = {}

local PLAZA = Vector3.new(-90, 0, 0)
local MINE_CENTER = Vector3.new(1400, 0, 0)

-- Cada plan: qué modelo, a qué escala y cómo se mueve.
--  Orbit:  vuela en una elipse (centro, radio, altura, velocidad en rad/s, fase)
--  Float:  flota en un punto, girando despacio
--  Station: fija en el cielo, girando muy despacio
local PLANS = {
	-- Transbordadores (naves blancas con alas naranjas), sobre la plaza y las bases
	{ Model = "shuttle", Scale = 2.0, Kind = "Orbit", Center = PLAZA, Radius = 520, Squash = 0.8, Height = 210, Speed = 0.050, Phase = 0.0, Bank = 0.3, Trail = true },
	{ Model = "shuttle", Scale = 2.0, Kind = "Orbit", Center = PLAZA, Radius = 760, Squash = 1.0, Height = 280, Speed = -0.038, Phase = 2.4, Bank = 0.3, Trail = true },
	{ Model = "shuttle", Scale = 2.2, Kind = "Orbit", Center = MINE_CENTER, Radius = 1000, Squash = 0.45, Height = 240, Speed = 0.030, Phase = 4.1, Bank = 0.25, Trail = true },
	-- Carguero grande y lento
	{ Model = "freighter", Scale = 2.6, Kind = "Orbit", Center = PLAZA + Vector3.new(500, 0, 0), Radius = 900, Squash = 0.6, Height = 340, Speed = 0.016, Phase = 1.2, Bank = 0.08, Trail = true },
	-- Exploradores veloces, en pareja
	{ Model = "scout", Scale = 2.6, Kind = "Orbit", Center = PLAZA, Radius = 380, Squash = 0.9, Height = 150, Speed = 0.11, Phase = 0.5, Bank = 0.55, Trail = true },
	{ Model = "scout", Scale = 2.6, Kind = "Orbit", Center = PLAZA, Radius = 400, Squash = 0.9, Height = 158, Speed = 0.11, Phase = 0.62, Bank = 0.55, Trail = true },
	{ Model = "scout", Scale = 2.6, Kind = "Orbit", Center = MINE_CENTER, Radius = 700, Squash = 0.5, Height = 170, Speed = -0.09, Phase = 3.0, Bank = 0.5, Trail = true },
	-- Satélites que giran despacio muy arriba
	{ Model = "satellite", Scale = 2.4, Kind = "Orbit", Center = PLAZA, Radius = 650, Squash = 1.0, Height = 430, Speed = 0.022, Phase = 0.8, Bank = 0, Spin = 0.4 },
	{ Model = "satellite", Scale = 2.4, Kind = "Orbit", Center = MINE_CENTER, Radius = 1100, Squash = 0.7, Height = 520, Speed = -0.015, Phase = 2.0, Bank = 0, Spin = 0.3 },
	{ Model = "satellite", Scale = 2.2, Kind = "Orbit", Center = PLAZA, Radius = 900, Squash = 0.9, Height = 480, Speed = 0.012, Phase = 4.4, Bank = 0, Spin = 0.5 },
	-- Estación espacial grande y lejana
	{ Model = "station", Scale = 3.6, Kind = "Station", Position = Vector3.new(-350, 430, -1250), Tilt = Vector3.new(0.45, 0, 0.25), Spin = 0.035 },
	-- Asteroides a lo lejos
	{ Model = "asteroid_c", Scale = 6, Kind = "Float", Position = Vector3.new(-900, 520, 900), Drift = 80, Speed = 0.010, Phase = 0.0, Tumble = 0.03 },
	{ Model = "asteroid_a", Scale = 4, Kind = "Float", Position = Vector3.new(-800, 380, -1400), Drift = 60, Speed = 0.013, Phase = 1.5, Tumble = 0.05 },
	{ Model = "asteroid_b", Scale = 5, Kind = "Float", Position = Vector3.new(700, 600, 1500), Drift = 90, Speed = 0.008, Phase = 3.0, Tumble = 0.04 },
	{ Model = "asteroid_a", Scale = 5, Kind = "Float", Position = Vector3.new(1700, 450, -1300), Drift = 70, Speed = 0.011, Phase = 4.2, Tumble = 0.035 },
	{ Model = "asteroid_c", Scale = 7, Kind = "Float", Position = Vector3.new(2400, 650, 1200), Drift = 100, Speed = 0.007, Phase = 5.1, Tumble = 0.025 },
	{ Model = "asteroid_b", Scale = 4, Kind = "Float", Position = Vector3.new(-400, 700, 1500), Drift = 60, Speed = 0.012, Phase = 2.2, Tumble = 0.06 },
}

-- Arma un modelo con las piezas cuyo nombre empieza por `prefix` (centradas en el origen).
local function buildModel(templates, prefix, scale)
	local model = Instance.new("Model")
	model.Name = prefix
	local engines = {}
	local count = 0
	for partName, info in ArtAssets.ambient do
		if partName == prefix or string.sub(partName, 1, #prefix + 1) == prefix .. "_" then
			local template = templates:FindFirstChild(partName)
			if not template then
				model:Destroy()
				return nil
			end
			local part = template:Clone()
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
			part.Size = info.Size * scale
			part.CFrame = CFrame.new(info.Center * scale)
			part.Color = info.Tint
			part.Material = Enum.Material[info.Material]
			part.Transparency = if info.Material == "Glass" then 0.15 else 0
			part.Parent = model
			count += 1
			if string.find(partName, "engine", 1, true) then
				table.insert(engines, part)
			end
		end
	end
	if count == 0 then
		model:Destroy()
		return nil
	end
	model.WorldPivot = CFrame.identity
	return model, engines
end

-- Estela luminosa detrás de cada motor.
local function addTrail(engine, scale)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, engine.Size.Y / 2, 0)
	a.Parent = engine
	local b = Instance.new("Attachment")
	b.Position = Vector3.new(0, -engine.Size.Y / 2, 0)
	b.Parent = engine
	local trail = Instance.new("Trail")
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Lifetime = 1.6
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail.LightEmission = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(90, 150, 255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Parent = engine
end

function Ambient.start()
	local templatesRoot = ReplicatedStorage:WaitForChild("ArtTemplates", 30)
	local templates = templatesRoot and templatesRoot:WaitForChild("ambient", 10)
	if not templates or not ArtAssets.ambient then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "NeoLunaAmbient"
	folder.Parent = workspace

	local actors = {}
	for _, plan in PLANS do
		local model, engines = buildModel(templates, plan.Model, plan.Scale)
		if model then
			model.Parent = folder
			if plan.Trail then
				for _, engine in engines do
					addTrail(engine, plan.Scale)
				end
			end
			table.insert(actors, { Plan = plan, Model = model })
		end
	end

	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		for _, actor in actors do
			local plan = actor.Plan
			if plan.Kind == "Orbit" then
				local a = plan.Phase + plan.Speed * clock
				local sign = if plan.Speed >= 0 then 1 else -1
				local position = plan.Center
					+ Vector3.new(math.cos(a) * plan.Radius, plan.Height + math.sin(a * 3) * 10, math.sin(a) * plan.Radius * plan.Squash)
				if plan.Spin then
					-- satélite: da vueltas sobre sí mismo
					actor.Model:PivotTo(CFrame.new(position) * CFrame.Angles(0, clock * plan.Spin, 0))
				else
					local heading = Vector3.new(-math.sin(a) * sign, 0, math.cos(a) * plan.Squash * sign)
					-- se ladea un poco en las curvas
					actor.Model:PivotTo(CFrame.lookAt(position, position + heading) * CFrame.Angles(0, 0, -plan.Bank * sign * 0.5))
				end
			elseif plan.Kind == "Station" then
				actor.Model:PivotTo(
					CFrame.new(plan.Position) * CFrame.Angles(plan.Tilt.X, 0, plan.Tilt.Z) * CFrame.Angles(0, clock * plan.Spin, 0)
				)
			else -- Float
				local a = plan.Phase + plan.Speed * clock
				local position = plan.Position + Vector3.new(math.cos(a) * plan.Drift, math.sin(a * 1.7) * plan.Drift * 0.3, math.sin(a) * plan.Drift)
				actor.Model:PivotTo(CFrame.new(position) * CFrame.Angles(clock * plan.Tumble, clock * plan.Tumble * 0.7, clock * plan.Tumble * 0.4))
			end
		end
	end)
end

return Ambient
