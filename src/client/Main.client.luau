-- Conecta los remotes con el HUD (Fusion).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local HUD = require(script.Parent.HUD)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("Buy")
local stateRemote = remotes:WaitForChild("StateChanged")
local requestRemote = remotes:WaitForChild("RequestState")
local offlineRemote = remotes:WaitForChild("OfflineEarnings")

local scope = Fusion.scoped(Fusion)
local state = scope:Value({ Credits = 0, Drones = 1, Capacity = 0, Speed = 0 })
local toastText = scope:Value("")

HUD.mount(Players.LocalPlayer:WaitForChild("PlayerGui"), state, toastText, function(kind)
	buyRemote:FireServer(kind)
end)

stateRemote.OnClientEvent:Connect(function(newState)
	state:set(newState)
end)

local toastId = 0
offlineRemote.OnClientEvent:Connect(function(earned)
	toastId += 1
	local id = toastId
	toastText:set(("Mientras no estabas ganaste %d créditos"):format(earned))
	task.delay(6, function()
		if toastId == id then
			toastText:set("")
		end
	end)
end)

requestRemote:FireServer()
