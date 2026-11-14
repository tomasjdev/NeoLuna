-- Conecta los remotes con el HUD y envía los lanzamientos del pico.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("StateChanged")
local noticeRemote = remotes:WaitForChild("Notice")
local carryRemote = remotes:WaitForChild("Carry")
local openShopRemote = remotes:WaitForChild("OpenShop")
local requestRemote = remotes:WaitForChild("RequestState")
local throwRemote = remotes:WaitForChild("Throw")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local sellRemote = remotes:WaitForChild("SellMineral")

local SHOP_CLOSE_DISTANCE = 45 -- la tienda se cierra si te alejas más que esto

local scope = Fusion.scoped(Fusion)
local ui = {
	state = scope:Value({ Money = 0, Speed = 0, Strength = 0, Pickaxe = 0, Inventory = {} }),
	carry = scope:Value(""), -- id del mineral que llevas ("" = ninguno)
	notice = scope:Value(""),
	shopOpen = scope:Value(false),
	backpackOpen = scope:Value(false),
	selected = scope:Value(0), -- espacio de la mochila elegido (0 = ninguno)
	depth = scope:Value(0),
}

HUD.mount(player:WaitForChild("PlayerGui"), ui, {
	onUpgrade = function(kind)
		buyUpgradeRemote:FireServer(kind)
	end,
	onSell = function(index)
		sellRemote:FireServer(index)
	end,
})

stateRemote.OnClientEvent:Connect(function(newState)
	ui.state:set(newState)
end)

carryRemote.OnClientEvent:Connect(function(mineralId)
	ui.carry:set(mineralId)
end)

local noticeId = 0
noticeRemote.OnClientEvent:Connect(function(text)
	noticeId += 1
	local id = noticeId
	ui.notice:set(text)
	task.delay(4, function()
		if noticeId == id then
			ui.notice:set("")
		end
	end)
end)

local shopPosition = nil
openShopRemote.OnClientEvent:Connect(function(position)
	shopPosition = position
	ui.selected:set(0)
	ui.shopOpen:set(true)
end)

-- Profundidad (distancia a la línea de inicio) y cierre de la tienda al alejarse.
task.spawn(function()
	while true do
		task.wait(0.2)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			ui.depth:set(math.floor(math.max(hrp.Position.X, 0)))
			if shopPosition and Fusion.peek(ui.shopOpen) and (hrp.Position - shopPosition).Magnitude > SHOP_CLOSE_DISTANCE then
				ui.shopOpen:set(false)
			end
		end
	end
end)

-- Lanzar el pico: clic del ratón o toque en pantalla, apuntando al mundo.
UserInputService.InputBegan:Connect(function(input, processedByUi)
	if processedByUi then
		return
	end
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	if not (isMouse or isTouch) then
		return
	end
	if Fusion.peek(ui.shopOpen) or Fusion.peek(ui.backpackOpen) then
		return
	end

	local camera = workspace.CurrentCamera
	local ray
	if isTouch then
		ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	else
		local location = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(location.X, location.Y)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	throwRemote:FireServer(if result then result.Position else ray.Origin + ray.Direction * 200)
end)

requestRemote:FireServer()
