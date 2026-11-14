-- La mina: nodos de minerales, lanzamiento del pico, ovni perseguidor y entrega.
-- El servidor decide todo; el cliente solo envía a dónde apuntó.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local Props = require(script.Parent.Props)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MineService = {}

local AIM_RADIUS = 9 -- studs alrededor del punto apuntado donde se busca un nodo
local THROW_SPEED = 90 -- studs/s del pico
local NODE_RESPAWN = 10 -- segundos hasta que reaparece un nodo roto
local NODES_PER_ZONE = 16

local rng = Random.new()
local remotes
local nodeFolder
local nodes = {} -- set de modelos de nodo
local carrying = {} -- player -> { Mineral, Gem, Ufo }
local busy = {} -- player -> true mientras el pico está en el aire

local function notice(player, text)
	remotes.Notice:FireClient(player, text)
end

local function isFiniteVector(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5
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

----------------------------------------------------------------------
-- Nodos
----------------------------------------------------------------------

local function spawnNode(zone)
	local length = Config.ZoneLength
	local x = rng:NextNumber((zone - 1) * length + (if zone == 1 then 50 else 12), zone * length - 12)
	local z = rng:NextNumber(-Config.MineHalfWidth + 15, Config.MineHalfWidth - 15)
	local ground = Vector3.new(x, 0, z)
	local gemColor = Config.Zones[zone].GemColor

	local model = Instance.new("Model")
	model.Name = "Node"

	local function piece(shape, size, offset, rotation, color, material, transparency)
		local p = Instance.new("Part")
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

	local rock = piece(Enum.PartType.Ball, Vector3.one * 5, Vector3.new(0, 1.2, 0), nil, Color3.fromRGB(178, 168, 205))
	piece(Enum.PartType.Block, Vector3.new(2.2, 5, 2.2), Vector3.new(0, 4, 0), CFrame.Angles(0, math.rad(45), math.rad(8)), gemColor, Enum.Material.Glass, 0.1)
	piece(Enum.PartType.Block, Vector3.new(1.4, 3, 1.4), Vector3.new(1.8, 3, 0.5), CFrame.Angles(0, math.rad(20), math.rad(-18)), gemColor, Enum.Material.Glass, 0.1)

	model.PrimaryPart = rock
	model:SetAttribute("Zone", zone)
	model.Parent = nodeFolder
	nodes[model] = true
	return model
end

local function breakNode(node)
	local zone = node:GetAttribute("Zone")
	nodes[node] = nil
	node:Destroy()
	task.delay(NODE_RESPAWN, function()
		spawnNode(zone)
	end)
end

-- Nodo libre más cercano al punto apuntado y al alcance del jugador.
local function findNode(target, from, range)
	local best, bestDistance = nil, AIM_RADIUS
	for node in nodes do
		if not node:GetAttribute("Claimed") then
			local position = node.PrimaryPart.Position
			local aimDistance = (position - target).Magnitude
			if aimDistance < bestDistance and (position - from).Magnitude <= range then
				best, bestDistance = node, aimDistance
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- Mineral cargado y ovni
----------------------------------------------------------------------

local function clearCarry(player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	if carry.Gem then
		carry.Gem:Destroy()
	end
	if carry.Ufo then
		carry.Ufo:Destroy()
	end
	if player.Parent then
		remotes.Carry:FireClient(player, "")
	end
end

local function startCarry(player, mineral)
	local character = player.Character
	local color = Config.GetRarityColor(mineral.Id)
	local carry = {
		Mineral = mineral,
		Gem = character and Props.CarriedGem(character, color),
		Ufo = nil,
	}
	carrying[player] = carry
	remotes.Carry:FireClient(player, mineral.Id)
	notice(player, ("¡Sacaste %s! ¡Corre a la línea!"):format(mineral.Name))

	task.delay(Config.Ufo.SpawnDelay, function()
		if carrying[player] ~= carry then
			return
		end
		local currentCharacter = player.Character
		local hrp = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local ufo = Props.Ufo()
		ufo:PivotTo(CFrame.new(hrp.Position + Vector3.new(Config.Ufo.SpawnDistance, Config.Ufo.HoverHeight + 6, 0)))
		ufo.Parent = workspace
		carry.Ufo = ufo
		notice(player, "¡Un ovni te persigue!")
	end)
end

local function deliver(player, carry)
	local mineral = carry.Mineral
	local saved = Economy.AddMineral(player, mineral.Id)
	clearCarry(player)
	if saved then
		notice(player, ("¡Guardaste %s en tu mochila!"):format(mineral.Name))
	else
		notice(player, "¡Tu mochila estaba llena y se perdió el mineral!")
	end
end

local function caught(player, carry, hrp)
	local ufo = carry.Ufo
	carry.Ufo = nil -- que clearCarry no lo destruya: se va volando
	clearCarry(player)
	hrp.CFrame = CFrame.new(WorldBuilder.ReturnPosition)
	notice(player, "¡El ovni se llevó tu mineral! Entra a la mina otra vez.")
	if ufo then
		task.spawn(function()
			flyModel(ufo, ufo:GetPivot() + Vector3.new(0, 80, 0), 1.5)
			ufo:Destroy()
		end)
	end
end

local function step(dt)
	for player, carry in carrying do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not hrp or not humanoid or humanoid.Health <= 0 then
			clearCarry(player)
			continue
		end

		local position = hrp.Position
		if position.X < 0 then
			deliver(player, carry)
			continue
		end

		local ufo = carry.Ufo
		if ufo then
			local current = ufo:GetPivot().Position
			local goal = Vector3.new(position.X, position.Y + Config.Ufo.HoverHeight, position.Z)
			local offset = goal - current
			local travel = Config.GetUfoSpeed(position.X) * dt
			local nextPosition = if offset.Magnitude <= travel then goal else current + offset.Unit * travel
			ufo:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(0, os.clock() * 2, 0))

			local flat = Vector3.new(nextPosition.X - position.X, 0, nextPosition.Z - position.Z).Magnitude
			if flat < Config.Ufo.CatchDistance then
				caught(player, carry, hrp)
			end
		end
	end
end

----------------------------------------------------------------------
-- Lanzamiento del pico
----------------------------------------------------------------------

function MineService.Throw(player, target)
	if typeof(target) ~= "Vector3" or not isFiniteVector(target) then
		return
	end
	if busy[player] or carrying[player] then
		return
	end

	local data = Economy.Get(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (data and hrp and humanoid and humanoid.Health > 0) then
		return
	end
	if #data.Inventory >= Config.InventorySize then
		notice(player, "¡Mochila llena! Vende o guarda algo primero.")
		return
	end

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local range = Config.GetThrowRange(data.Strength)
	local node = findNode(target, hrp.Position, range)

	local destination
	if node then
		destination = node.PrimaryPart.Position + Vector3.new(0, 3, 0)
	else
		local direction = target - origin
		if direction.Magnitude < 1 then
			return
		end
		destination = origin + direction.Unit * math.min(direction.Magnitude, range)
	end

	busy[player] = true
	if node then
		node:SetAttribute("Claimed", true)
	end

	task.spawn(function()
		local aim = CFrame.lookAt(origin, destination)
		local pickaxe = Props.Pickaxe()
		pickaxe:PivotTo(aim)
		pickaxe.Parent = workspace

		local duration = math.max((destination - origin).Magnitude / THROW_SPEED, 0.15)
		flyModel(pickaxe, CFrame.new(destination) * aim.Rotation, duration)

		if not node then
			flyModel(pickaxe, aim, duration) -- no alcanzó nada: vuelve
			pickaxe:Destroy()
			busy[player] = nil
			return
		end

		pickaxe:Destroy()
		local depth = node.PrimaryPart.Position.X
		breakNode(node)
		busy[player] = nil

		local currentData = Economy.Get(player)
		if player.Parent and currentData and not carrying[player] then
			startCarry(player, Config.RollMineral(depth, currentData.Pickaxe, rng))
		end
	end)
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

	remotes.Throw.OnServerEvent:Connect(MineService.Throw)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		clearCarry(player)
		busy[player] = nil
	end)
end

return MineService
