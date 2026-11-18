-- Efectos de pantalla y sonido: "+$" al cobrar, bienvenida, alerta del ovni (banner, borde rojo
-- y distancia) y sonidos. Todo es opcional: si algo falla, el juego sigue funcionando.
-- Los sonidos usan los Ids de Config.Sounds (0 = sin sonido).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local gui
local chased = false
local music = {} -- nombre -> Sound en bucle
local mineSound
local banner
local edges = {} -- los 4 bordes rojos
local bannerOn = false -- el banner del ovni está parpadeando
local welcomeCard -- la tarjeta de bienvenida que está en pantalla (si hay)
local stack -- columna de avisos (arriba al centro): banner del ovni, bienvenida y avisos de texto
local noticeOrder = 0
local activeNotices = {}

local function new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function tween(instance, seconds, goal, style)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

----------------------------------------------------------------------
-- Sonidos
----------------------------------------------------------------------

local function soundId(name)
	local id = Config.Sounds[name]
	if id and id ~= 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return nil
end

-- Un sonido corto (sin bucle).
function Effects.play(name, volume)
	local id = soundId(name)
	if not id then
		return
	end
	local sound = new("Sound", { SoundId = id, Volume = volume or 0.6 }, SoundService)
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function startLoop(name, volume)
	local id = soundId(name)
	if not id then
		return nil
	end
	local sound = new("Sound", { SoundId = id, Volume = 0, Looped = true }, SoundService)
	sound:Play()
	return sound, volume
end

local musicVolumes = {}

local function fadeMusic()
	for name, sound in music do
		local target = 0
		if name == "Music" and not chased then
			target = musicVolumes[name]
		elseif name == "Chase" and chased then
			target = musicVolumes[name]
		end
		tween(sound, 0.8, { Volume = target })
	end
end

-- Pico: suena mientras se mantiene E sobre un cristal.
function Effects.mineLoop(active)
	if active then
		if not mineSound then
			local id = soundId("Mine")
			if id then
				mineSound = new("Sound", { SoundId = id, Volume = 0.5, Looped = true }, SoundService)
			end
		end
		if mineSound and not mineSound.IsPlaying then
			mineSound:Play()
		end
	elseif mineSound then
		mineSound:Stop()
	end
end

----------------------------------------------------------------------
-- Dinero ganado, bienvenida
----------------------------------------------------------------------

-- "+$1,200" flotando bajo el dinero, en verde y sin cajas blancas.
function Effects.gain(text)
	if not gui then
		return
	end
	Effects.play("Gain", 0.5)
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 114), -- debajo del panel de dinero (la pantalla de efectos no tiene margen superior)
		Size = UDim2.fromOffset(240, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(95, 235, 125),
		TextStrokeColor3 = Color3.fromRGB(10, 70, 40),
		TextStrokeTransparency = 0,
		Text = text,
	}, gui)
	local scale = new("UIScale", { Scale = 0.5 }, label)
	tween(scale, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.2, function()
		tween(scale, 0.15, { Scale = 1 })
	end)
	task.delay(0.9, function()
		tween(label, 0.9, {
			Position = UDim2.new(1, -34, 0, 138),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	end)
	task.delay(2, function()
		label:Destroy()
	end)
end

-- Todo aviso del centro de arriba (banner del ovni, bienvenida y avisos de texto) va en una
-- misma columna, uno debajo del otro, así que nunca se encima nada.

-- Tarjeta de "bienvenido de vuelta".
-- Quita la tarjeta de bienvenida al instante (cuando sale otro aviso).
local function dismissWelcome()
	local old = welcomeCard
	welcomeCard = nil
	if old and old.Parent then
		tween(old, 0.25, { GroupTransparency = 1 })
		task.delay(0.3, function()
			old:Destroy()
		end)
	end
end

function Effects.welcome(amountText)
	if not stack then
		return
	end
	local card = new("CanvasGroup", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(380, 72),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, stack)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
	local stroke = new("UIStroke", { Color = Color3.fromRGB(255, 200, 60), Thickness = 4, Transparency = 1 }, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(70, 50, 120),
		Text = "¡Bienvenido de vuelta!",
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(40, 175, 90),
		Text = amountText,
	}, card)
	welcomeCard = card
	tween(card, 0.4, { GroupTransparency = 0 })
	tween(stroke, 0.4, { Transparency = 0 })
	task.delay(7, function()
		if welcomeCard ~= card then
			return
		end
		welcomeCard = nil
		tween(card, 0.5, { GroupTransparency = 1 })
		tween(stroke, 0.5, { Transparency = 1 })
		task.delay(0.6, function()
			card:Destroy()
		end)
	end)
end

-- Aviso de texto (hasta 3 a la vez, apilados). Devuelve false si la pantalla de efectos no existe.
function Effects.notice(text)
	if not stack then
		return false
	end
	dismissWelcome()
	noticeOrder += 1
	local group = new("CanvasGroup", {
		LayoutOrder = 10 + noticeOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, stack)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, group)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, group)
	local label = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(70, 50, 120),
		Text = text,
	}, group)
	new("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }, label)
	local stroke = new("UIStroke", { Color = Color3.fromRGB(190, 165, 255), Thickness = 3, Transparency = 1 }, group)

	table.insert(activeNotices, group)
	if #activeNotices > 3 then
		local oldest = table.remove(activeNotices, 1)
		oldest:Destroy()
	end

	tween(group, 0.25, { GroupTransparency = 0 })
	tween(stroke, 0.25, { Transparency = 0 })
	task.delay(4, function()
		if group.Parent then
			tween(group, 0.5, { GroupTransparency = 1 })
			tween(stroke, 0.5, { Transparency = 1 })
			task.delay(0.6, function()
				local index = table.find(activeNotices, group)
				if index then
					table.remove(activeNotices, index)
				end
				group:Destroy()
			end)
		end
	end)
	return true
end

----------------------------------------------------------------------
-- Ovni: banner, borde rojo y distancia
----------------------------------------------------------------------

local function nearestUfo()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, 0
	end
	local best, count = math.huge, 0
	for _, child in workspace:GetChildren() do
		if child.Name == "Ufo" and child:IsA("Model") then
			count += 1
			local distance = (child:GetPivot().Position - root.Position).Magnitude
			if distance < best then
				best = distance
			end
		end
	end
	return if count > 0 then best else nil, count
end

-- Aparecen ovnis: el banner rojo se queda parpadeando hasta que cruzas la línea de meta.
function Effects.ufoAlert(count, wanted)
	if not banner then
		return
	end
	Effects.play("Alarm", 0.8)
	local total = wanted or count
	banner.Text = if total > 1 then ("¡%d OVNIS TE PERSIGUEN!"):format(total) else "¡UN OVNI TE PERSIGUE!"
	bannerOn = true
	dismissWelcome()
	banner.Visible = true
end

-- Se llama cuando cambia cuántos minerales llevas (0 = ya no te persigue nadie).
function Effects.setChased(isChased)
	if chased == isChased then
		return
	end
	chased = isChased
	fadeMusic()
	if not chased then
		bannerOn = false
		if banner then
			banner.Visible = false
		end
		for _, edge in edges do
			edge.BackgroundTransparency = 1
		end
	end
end

local function updateChase()
	if not chased then
		return
	end
	local t = os.clock()
	-- El banner parpadea (rojo y amarillo) y late un poco.
	if bannerOn and banner then
		local scale = banner:FindFirstChildOfClass("UIScale")
		scale.Scale = 1 + 0.07 * math.abs(math.sin(t * 6))
		banner.TextColor3 = if math.floor(t * 4) % 2 == 0 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 215, 80)
	end
	-- Los bordes se ponen rojos mientras más cerca está el ovni (empieza a los 90 studs).
	local distance = nearestUfo()
	-- Mientras el ovni aún no aparece, los bordes ya parpadean en rojo (aviso inmediato).
	local danger = if distance then math.clamp(1 - distance / 90, 0.4, 1) else 0.5
	local pulse = 0.5 + 0.5 * math.sin(t * (4 + danger * 8))
	for _, edge in edges do
		edge.BackgroundTransparency = 1 - danger * (0.35 + 0.35 * pulse)
	end
end

----------------------------------------------------------------------
-- Montaje
----------------------------------------------------------------------

function Effects.mount(playerGui)
	gui = new("ScreenGui", { Name = "NeoLunaFx", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, playerGui)

	-- Bordes rojos (efecto de peligro): 4 franjas con degradado hacia adentro.
	local function edge(anchor, position, size, rotation)
		local frame = new("Frame", {
			AnchorPoint = anchor,
			Position = position,
			Size = size,
			BackgroundColor3 = Color3.fromRGB(255, 30, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		}, gui)
		new("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		}, frame)
		table.insert(edges, frame)
	end
	edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.18, 0), 90) -- arriba
	edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0.18, 0), -90) -- abajo
	edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(0.12, 0, 1, 0), 0) -- izquierda
	edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0.12, 0, 1, 0), 180) -- derecha

	-- Columna de avisos arriba al centro, justo debajo del letrero de la zona (que mide hasta 138
	-- píxeles con el tamaño de celular).
	local touch = game:GetService("UserInputService").TouchEnabled
	stack = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if touch then 190 else 160),
		Size = UDim2.fromOffset(720, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, stack)

	banner = new("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(640, 58),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 70, 70),
		TextStrokeColor3 = Color3.fromRGB(60, 0, 0),
		TextStrokeTransparency = 0,
		Visible = false,
		Text = "",
	}, stack)
	new("UIScale", { Scale = 1 }, banner)

	-- Música de fondo y de persecución (si hay Ids en Config.Sounds).
	for name, volume in { Music = 0.25, Chase = 0.3 } do
		local sound = startLoop(name, volume)
		if sound then
			music[name] = sound
			musicVolumes[name] = volume
		end
	end
	fadeMusic()

	RunService.Heartbeat:Connect(function()
		pcall(updateChase)
	end)
end

return Effects
