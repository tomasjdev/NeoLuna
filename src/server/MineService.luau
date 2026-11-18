-- La mina: nodos de minerales, picado manteniendo E, ovni perseguidor y entrega.
-- El servidor decide todo, incluida la duración del picado: el cliente solo avisa
-- cuándo empieza y cuándo suelta la tecla antes de tiempo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local HeldMineral = require(script.Parent.HeldMineral)
local Props = require(script.Parent.Props)
local ArtLibrary = require(script.Parent.ArtLibrary)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MineService = {}

local MINE_REACH = 18 -- distancia máxima al nodo para empezar y mantener el picado
local CANCEL_GRACE = 0.4 -- una cancelación tan cerca del final se ignora (el picado ya casi terminó)
local SWING_INTERVAL = 0.55 -- segundos entre golpes del pico
local NODES_PER_ZONE = 16
local nextNodeId = 0 -- cada cristal tiene un número fijo para que el cliente no se confunda

local rng = Random.new()
local remotes
local nodeFolder
local nodes = {} -- set de modelos de nodo (fijos: nunca se destruyen)
local nodeInfo = {} -- node -> { Counts = { [player] = veces roto }, Until = { [player] = hora } }
local carrying = {} -- player -> { Mineral, Gem, Ufo }
local mining = {} -- player -> { Node, StartedAt, Duration, BasePivot, Tool, Dust, Alive }

local function notice(player, text)
	remotes.Notice:FireClient(player, text)
end

-- Mueve un modelo en línea recta hasta `goal` (yield mientras dura).
local function flyModel(model, goal, duration)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	local connection = value.Changed:Connect(function(cframe)
		model:PivotTo(cframe)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
end

local function getCharacterParts(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if hrp and humanoid and humanoid.Health > 0 then
		return character, hrp, humanoid
	end
	return nil
end

----------------------------------------------------------------------
-- Nodos: fijos y compartidos. Cada jugador ve su propio mineral en cada uno (se calcula
-- con la semilla del nodo) y el nodo que rompes solo desaparece para ti.
----------------------------------------------------------------------

local NEUTRAL_CRYSTAL = Color3.fromRGB(150, 150, 165)

local function spawnNode(zone)
	local length = Config.ZoneLength
	local x = rng:NextNumber((zone - 1) * length + (if zone == 1 then 50 else 12), zone * length - 12)
	local z = rng:NextNumber(-Config.MineHalfWidth + 15, Config.MineHalfWidth - 15)
	local ground = Vector3.new(x, 0, z)

	local model = Instance.new("Model")
	model.Name = "Node"

	local function piece(name, shape, size, offset, rotation, color, material, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Shape = shape
		p.Size = size
		p.CFrame = CFrame.new(ground + offset) * (rotation or CFrame.identity)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Parent = model
		return p
	end

	-- Con el modelo 3D de Blender si cargó: solo la roca; el mineral de cada jugador lo coloca su
	-- propia pantalla encima (cada mineral tiene su diseño). Si no, con piezas de código.
	local rock
	local artModel = ArtLibrary.IsReady("crystal_node")
		and ArtLibrary.IsReady("minerals")
		and ArtLibrary.Build("crystal_node", CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	if artModel then
		rock = artModel:FindFirstChild("rock")
		rock.Name = "Rock"
		rock.Parent = model
		artModel:Destroy()
		model:SetAttribute("ArtMinerals", true)
	else
		rock = piece("Rock", Enum.PartType.Ball, Vector3.one * 5, Vector3.new(0, 1.2, 0), nil, Color3.fromRGB(120, 118, 125), Enum.Material.Slate)
		piece("Crystal", Enum.PartType.Block, Vector3.new(2.2, 5, 2.2), Vector3.new(0, 4, 0), CFrame.Angles(0, math.rad(45), math.rad(8)), NEUTRAL_CRYSTAL, Enum.Material.Glass, 0.1)
		piece("CrystalSmall", Enum.PartType.Block, Vector3.new(1.4, 3, 1.4), Vector3.new(1.8, 3, 0.5), CFrame.Angles(0, math.rad(20), math.rad(-18)), NEUTRAL_CRYSTAL, Enum.Material.Glass, 0.1)
	end

	model.PrimaryPart = rock
	-- Con streaming, el cristal llega completo (no pieza por pieza) y el cliente lo pinta bien.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	nextNodeId += 1
	model:SetAttribute("NodeId", nextNodeId)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("Seed", rng:NextInteger(1, 1000000))
	model.Parent = nodeFolder
	nodes[model] = true
	nodeInfo[model] = { Counts = {}, Until = {} }
	return model
end

-- El mineral de este nodo para este jugador (el cliente calcula el mismo).
local function playerMineral(node, player)
	local count = nodeInfo[node].Counts[player] or 0
	return Config.GetNodeMineral(node:GetAttribute("Seed"), player.UserId, count, node:GetAttribute("Zone"))
end

-- El jugador rompió el nodo: desaparece para él un rato y luego trae otro mineral.
local function markBroken(node, player)
	local info = nodeInfo[node]
	local count = (info.Counts[player] or 0) + 1
	info.Counts[player] = count
	info.Until[player] = os.clock() + Config.NodeRespawn
	remotes.NodeBroken:FireClient(player, node:GetAttribute("NodeId"), count)
end

----------------------------------------------------------------------
-- Mineral cargado y ovni
----------------------------------------------------------------------

-- Lo llama Main para recalcular la velocidad (llevar varios minerales o un rayo te frenan).
MineService.OnCarryChanged = function(_player) end

local capacityHintShown = {} -- player -> ya se le explicó la mejora de Capacidad
local slowedUntil = {} -- player -> hora (os.clock) hasta la que va frenado por un rayo

function MineService.GetCarryCount(player)
	local carry = carrying[player]
	return if carry then #carry.Minerals else 0
end

function MineService.IsSlowed(player)
	return (slowedUntil[player] or 0) > os.clock()
end

local function capacityFor(player)
	local data = Economy.Get(player)
	return Config.GetCarryCapacity(data and data.Capacity or 0)
end

local function destroyUfos(carry)
	for _, ufo in carry.Ufos do
		ufo:Destroy()
	end
	table.clear(carry.Ufos)
end

local function clearCarry(player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	if carry.Gem then
		carry.Gem:Destroy()
	end
	destroyUfos(carry)
	if player.Parent then
		remotes.Carry:FireClient(player, 0)
		MineService.OnCarryChanged(player)
	end
end

-- Hace aparecer los ovnis que faltan (1 desde el inicio, 2 y 3 en las zonas profundas).
local function ensureUfos(player, carry, zone)
	local wanted = Config.GetUfoCount(zone)
	if wanted <= carry.UfosWanted then
		return
	end
	carry.UfosWanted = wanted
	for index = #carry.Ufos + carry.UfosPending + 1, wanted do
		carry.UfosPending += 1
		task.delay(Config.Ufo.SpawnDelay + (index - 1) * 1.2, function()
			carry.UfosPending -= 1
			if carrying[player] ~= carry then
				return
			end
			local _, hrp = getCharacterParts(player)
			if not hrp then
				return
			end
			local side = if index == 1 then 0 else (if index % 2 == 0 then 1 else -1) * 28
			local ufo = Props.Ufo()
			ufo:PivotTo(CFrame.new(hrp.Position + Vector3.new(Config.Ufo.SpawnDistance + (index - 1) * 22, Config.Ufo.HoverHeight + 6, side)))
			ufo.Parent = workspace
			table.insert(carry.Ufos, ufo)
			carry.NextShot[ufo] = os.clock() + Config.Ufo.ShotCooldown * 0.6
			remotes.UfoAlert:FireClient(player, #carry.Ufos, wanted)
		end)
	end
end

-- Recoge un mineral. El primero crea el ovni; los siguientes se suman al mismo viaje.
local function startCarry(player, mineral, zone)
	local existing = carrying[player]
	if existing then
		table.insert(existing.Minerals, mineral)
		remotes.Carry:FireClient(player, #existing.Minerals)
		MineService.OnCarryChanged(player)
		notice(player, ("Llevas %d minerales. ¡Cuidado con el ovni!"):format(#existing.Minerals))
		ensureUfos(player, existing, zone) -- más profundo = más ovnis
		return
	end

	local character = player.Character
	local color = Config.GetMineralColor(mineral.Id)
	local carry = {
		Minerals = { mineral },
		Gem = character and Props.CarriedGem(character, mineral.Id, color),
		Ufos = {},
		UfosWanted = 0,
		UfosPending = 0,
		NextShot = {}, -- ovni -> hora del próximo disparo
	}
	carrying[player] = carry
	remotes.Carry:FireClient(player, 1)
	MineService.OnCarryChanged(player)
	ensureUfos(player, carry, zone)
	-- Una vez por sesión: cómo llevar más minerales por viaje.
	if capacityFor(player) <= 1 and not capacityHintShown[player] then
		capacityHintShown[player] = true
		notice(player, "Solo puedes llevar 1 mineral por viaje. Mejora Capacidad en la tienda morada.")
	end
end

local function deliver(player, carry)
	local savedCount, lost = 0, 0
	local lastName = ""
	for _, mineral in carry.Minerals do
		if Economy.AddMineral(player, mineral.Id) then
			savedCount += 1
			lastName = mineral.Name
		else
			lost += 1
		end
	end
	clearCarry(player)
	if savedCount == 1 and lost == 0 then
		notice(player, ("¡Guardaste %s en tu mochila!"):format(lastName))
	elseif savedCount > 0 then
		local text = ("¡Guardaste %d minerales en tu mochila!"):format(savedCount)
		if lost > 0 then
			text ..= (" (mochila llena: se perdieron %d)"):format(lost)
		end
		notice(player, text)
	else
		notice(player, "¡Tu mochila estaba llena y se perdió el mineral!")
	end
end

-- Los ovnis se van volando (cuando atrapan al jugador o lo salva el escudo).
local function sendUfosAway(ufos)
	for _, ufo in ufos do
		task.spawn(function()
			flyModel(ufo, ufo:GetPivot() + Vector3.new(0, 80, 0), 1.5)
			ufo:Destroy()
		end)
	end
end

local function caught(player, carry, hrp)
	local ufos = table.clone(carry.Ufos)
	table.clear(carry.Ufos) -- que clearCarry no los destruya: se van volando
	if Economy.UseShield(player) then
		-- El escudo anti-Alien: los minerales se salvan y se guardan en la mochila.
		deliver(player, carry)
		notice(player, "¡Tu escudo te salvó del ovni!")
		sendUfosAway(ufos)
		return
	end
	clearCarry(player)
	hrp.CFrame = CFrame.new(WorldBuilder.ReturnPosition)
	notice(player, "¡El ovni se llevó tus minerales! Entra a la mina otra vez.")
	sendUfosAway(ufos)
end

-- Un ovni dispara un rayo al jugador: si le da, lo frena un momento.
local function shoot(player, ufo, hrp)
	local target = hrp.Position + hrp.AssemblyLinearVelocity * 0.5
	local bolt = Instance.new("Part")
	bolt.Name = "UfoBolt"
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.one * 2.2
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(255, 70, 70)
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.CanTouch = false
	bolt.Position = ufo:GetPivot().Position - Vector3.new(0, 2, 0)
	bolt.Parent = workspace
	local tween = TweenService:Create(bolt, TweenInfo.new(0.6, Enum.EasingStyle.Linear), { Position = target })
	tween.Completed:Connect(function()
		bolt:Destroy()
		local _, current = getCharacterParts(player)
		if current and (current.Position - target).Magnitude < 7 then
			slowedUntil[player] = os.clock() + Config.Ufo.SlowSeconds
			MineService.OnCarryChanged(player)
			task.delay(Config.Ufo.SlowSeconds + 0.05, function()
				MineService.OnCarryChanged(player)
			end)
			notice(player, "¡Un rayo del ovni te frenó!")
		end
	end)
	tween:Play()
end

----------------------------------------------------------------------
-- Picado (mantener E junto al mineral)
----------------------------------------------------------------------

local function stopMining(player)
	local session = mining[player]
	if not session then
		return
	end
	mining[player] = nil
	session.Alive = false
	if session.Node.Parent then
		session.Node:PivotTo(session.BasePivot)
	end
	if session.Dust then
		session.Dust:Destroy()
	end
	if session.Tool then
		session.Tool:Destroy()
	end
end

-- Pico en la mano, polvo y temblor del mineral. Si algo de esto falla, el picado
-- sigue funcionando: solo se pierde el adorno.
local function startVisuals(player, session, humanoid)
	local node = session.Node
	local ok, err = pcall(function()
		local tool = Props.PickaxeTool()
		tool.Parent = player:FindFirstChildOfClass("Backpack") or player.Character
		humanoid:EquipTool(tool)
		session.Tool = tool

		local dust = Instance.new("ParticleEmitter")
		dust.Rate = 24
		dust.Lifetime = NumberRange.new(0.5, 0.9)
		dust.Speed = NumberRange.new(4, 8)
		dust.SpreadAngle = Vector2.new(60, 60)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		dust.Color = ColorSequence.new(Color3.fromRGB(190, 188, 184))
		dust.Acceleration = Vector3.new(0, -6, 0)
		dust.Parent = node.PrimaryPart
		session.Dust = dust
	end)
	if not ok then
		warn("[MineService] No se pudo mostrar el pico o el polvo:", err)
	end

	task.spawn(function()
		while session.Alive and mining[player] == session do
			if session.Tool and session.Tool.Parent then
				local swing = Instance.new("StringValue")
				swing.Name = "toolanim"
				swing.Value = "Slash"
				swing.Parent = session.Tool
			end
			for _ = 1, 5 do
				if not session.Alive or not node.Parent then
					break
				end
				node:PivotTo(session.BasePivot * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3))))
				task.wait(SWING_INTERVAL / 5)
			end
		end
	end)
end

function MineService.StartMining(player, node)
	if typeof(node) ~= "Instance" or not nodes[node] or not node.PrimaryPart then
		return
	end
	-- Se pueden llevar varios minerales por viaje (mejora de capacidad).
	if MineService.GetCarryCount(player) >= capacityFor(player) then
		notice(player, "Ya no puedes llevar más minerales. ¡Vuelve a la entrada!")
		return
	end
	-- Una sesión vieja del mismo jugador (p. ej. se soltó la tecla sin aviso) se reemplaza.
	if mining[player] then
		stopMining(player)
	end
	if (nodeInfo[node].Until[player] or 0) > os.clock() then
		return -- ya lo rompiste: para ti todavía no ha vuelto a aparecer
	end

	local data = Economy.Get(player)
	local _, hrp, humanoid = getCharacterParts(player)
	if not (data and hrp and humanoid) then
		return
	end
	if Economy.FreeSlots(player) <= MineService.GetCarryCount(player) then
		notice(player, "¡Mochila llena! Vende algo primero.")
		return
	end
	local nodePosition = node.PrimaryPart.Position
	if (hrp.Position - nodePosition).Magnitude > MINE_REACH then
		return
	end

	local mineral = playerMineral(node, player)
	local rarity = Config.RaritiesById[mineral.Rarity]

	local session = {
		Node = node,
		Mineral = mineral,
		StartedAt = os.clock(),
		Duration = Config.GetMineTime(data.Strength, data.Pickaxe, node:GetAttribute("Zone"), rarity.Id),
		BasePivot = node:GetPivot(),
		Alive = true,
	}
	mining[player] = session
	HeldMineral.Clear(player) -- las manos son para el pico

	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(nodePosition.X, hrp.Position.Y, nodePosition.Z))
	startVisuals(player, session, humanoid)
end

-- El cliente soltó la tecla (o se alejó). Si ya casi terminaba, se deja terminar.
function MineService.CancelMining(player)
	local session = mining[player]
	if session and os.clock() - session.StartedAt < session.Duration - CANCEL_GRACE then
		stopMining(player)
	end
end

local function finishMining(player, session)
	local node, mineral = session.Node, session.Mineral
	stopMining(player)
	markBroken(node, player)
	if player.Parent and Economy.Get(player) then
		startCarry(player, mineral, node:GetAttribute("Zone"))
	end
end

----------------------------------------------------------------------
-- Bucle principal
----------------------------------------------------------------------

local function step(dt)
	for player, session in mining do
		local _, hrp = getCharacterParts(player)
		if not hrp or not session.Node.Parent then
			stopMining(player)
		elseif (hrp.Position - session.Node.PrimaryPart.Position).Magnitude > MINE_REACH + 4 then
			stopMining(player)
		elseif os.clock() - session.StartedAt >= session.Duration then
			finishMining(player, session)
		end
	end

	for player, carry in carrying do
		local _, hrp = getCharacterParts(player)
		if not hrp then
			clearCarry(player)
			continue
		end

		local position = hrp.Position
		if position.X < 0 then
			deliver(player, carry)
			continue
		end

		local zone = Config.GetZone(position.X)
		for _, ufo in carry.Ufos do
			local current = ufo:GetPivot().Position
			local goal = Vector3.new(position.X, position.Y + Config.Ufo.HoverHeight, position.Z)
			local offset = goal - current
			local travel = Config.GetUfoSpeed(position.X) * dt
			local nextPosition = if offset.Magnitude <= travel then goal else current + offset.Unit * travel
			ufo:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(0, os.clock() * 2, 0))

			local flat = Vector3.new(nextPosition.X - position.X, 0, nextPosition.Z - position.Z).Magnitude
			if flat < Config.Ufo.CatchDistance then
				caught(player, carry, hrp)
				break
			end

			-- Desde las zonas profundas, los ovnis disparan.
			if zone >= Config.Ufo.ShootFromZone and flat < Config.Ufo.ShotRange and os.clock() >= (carry.NextShot[ufo] or 0) then
				carry.NextShot[ufo] = os.clock() + Config.Ufo.ShotCooldown
				shoot(player, ufo, hrp)
			end
		end
	end
end

function MineService.Init(remoteFolder)
	remotes = remoteFolder

	nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "MineNodes"
	nodeFolder.Parent = workspace
	for zone = 1, Config.ZoneCount do
		for _ = 1, NODES_PER_ZONE do
			spawnNode(zone)
		end
	end

	remotes.MineStart.OnServerEvent:Connect(MineService.StartMining)
	remotes.MineCancel.OnServerEvent:Connect(MineService.CancelMining)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		stopMining(player)
		clearCarry(player)
		for _, info in nodeInfo do
			info.Counts[player] = nil
			info.Until[player] = nil
		end
	end)
end

return MineService
