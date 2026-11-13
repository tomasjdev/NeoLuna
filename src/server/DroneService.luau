-- Mundo del prototipo (mina + depósito) y comportamiento de los drones.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)

local DroneService = {}

local FLY_HEIGHT = 8
local DEPOT_POS = Vector3.new(0, FLY_HEIGHT, -40)
local MINE_POS = DEPOT_POS + Vector3.new(Config.TripDistance, 0, 0)

local function makeSite(name, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(14, 1, 14)
	part.Position = Vector3.new(position.X, 0.5, position.Z)
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = workspace
end

function DroneService.BuildWorld()
	makeSite("MiningSite", MINE_POS, Color3.fromRGB(255, 120, 40))
	makeSite("Depot", DEPOT_POS, Color3.fromRGB(0, 220, 255))
end

local function makeDrone()
	local drone = Instance.new("Part")
	drone.Name = "Drone"
	drone.Size = Vector3.new(2, 1, 2)
	drone.Material = Enum.Material.Neon
	drone.Color = Color3.fromRGB(255, 0, 200)
	drone.Anchored = true
	drone.CanCollide = false
	drone.Position = DEPOT_POS
	drone.Parent = workspace
	return drone
end

local function flyTo(drone, target, speed)
	local distance = (drone.Position - target).Magnitude
	local tween = TweenService:Create(
		drone,
		TweenInfo.new(math.max(distance / speed, 0.05), Enum.EasingStyle.Linear),
		{ Position = target }
	)
	tween:Play()
	tween.Completed:Wait()
end

function DroneService.Spawn(player)
	task.spawn(function()
		local drone = makeDrone()
		-- Pequeño desfase para que los drones no se apilen en el mismo punto.
		local offset = Vector3.new(0, 0, math.random(-5, 5))

		while player.Parent and drone.Parent do
			local state = Economy.Get(player)
			if not state then
				break
			end

			flyTo(drone, MINE_POS + offset, Config.GetSpeed(state.Speed))
			task.wait(Config.Drone.MiningTime)

			-- Se lee de nuevo: las mejoras compradas durante el viaje cuentan.
			state = Economy.Get(player)
			if not state then
				break
			end
			local load = Config.GetCapacity(state.Capacity)
			flyTo(drone, DEPOT_POS + offset, Config.GetSpeed(state.Speed))
			Economy.Deliver(player, load)
		end

		drone:Destroy()
	end)
end

return DroneService
