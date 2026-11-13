-- HUD mínimo de texto (la UI con Fusion llega en la Fase 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("Buy")
local stateRemote = remotes:WaitForChild("StateChanged")
local requestRemote = remotes:WaitForChild("RequestState")

local gui = Instance.new("ScreenGui")
gui.Name = "NeoLunaHUD"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local credits = Instance.new("TextLabel")
credits.Size = UDim2.fromOffset(260, 40)
credits.Position = UDim2.fromOffset(20, 20)
credits.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
credits.TextColor3 = Color3.fromRGB(0, 255, 220)
credits.Font = Enum.Font.Code
credits.TextSize = 22
credits.Parent = gui

local buttons = {}
for i, kind in Config.UpgradeOrder do
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(260, 36)
	button.Position = UDim2.fromOffset(20, 20 + 46 * i)
	button.BackgroundColor3 = Color3.fromRGB(30, 10, 50)
	button.TextColor3 = Color3.fromRGB(255, 0, 200)
	button.Font = Enum.Font.Code
	button.TextSize = 18
	button.Parent = gui
	button.Activated:Connect(function()
		buyRemote:FireServer(kind)
	end)
	buttons[kind] = button
end

local function render(state)
	credits.Text = ("Créditos: %d"):format(state.Credits)
	for kind, button in buttons do
		local level = if kind == "Drone" then state.Drones else state[kind] + 1
		local cost = Config.GetCost(kind, state)
		button.Text = ("%s (Nv %d) - %d"):format(Config.Upgrades[kind].Label, level, cost)
		button.TextTransparency = if state.Credits >= cost then 0 else 0.5
	end
end

stateRemote.OnClientEvent:Connect(render)
requestRemote:FireServer()
