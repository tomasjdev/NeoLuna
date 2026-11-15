-- Conecta los remotes con el HUD y con los puntos de picado de los minerales.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("StateChanged")
local noticeRemote = remotes:WaitForChild("Notice")
local carryRemote = remotes:WaitForChild("Carry")
local openShopRemote = remotes:WaitForChild("OpenShop")
local nodeBrokenRemote = remotes:WaitForChild("NodeBroken")
local requestRemote = remotes:WaitForChild("RequestState")
local mineStartRemote = remotes:WaitForChild("MineStart")
local mineCancelRemote = remotes:WaitForChild("MineCancel")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local devRemote = remotes:WaitForChild("DevCommand")
local sellRemote = remotes:WaitForChild("SellMineral")
local placeRemote = remotes:WaitForChild("PlaceMineral")
local removeRemote = remotes:WaitForChild("RemoveMineral")

local SHOP_CLOSE_DISTANCE = 45 -- la tienda se cierra si te alejas más que esto

-- Usamos nuestra propia barra de inventario, no la de Roblox.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local scope = Fusion.scoped(Fusion)
local ui = {
	state = scope:Value({ Money = 0, Speed = 0, Strength = 0, Pickaxe = 0, Inventory = {}, Stands = {} }),
	carry = scope:Value(""), -- id del mineral que llevas ("" = ninguno)
	notice = scope:Value(""),
	shopKind = scope:Value(""), -- tienda de mejoras abierta: "Sell", "Pickaxe", "Strength" o "Speed"
	robuxKind = scope:Value(""), -- tienda de Robux abierta: "X2", "Boots", "Shield" o "Credits"
	backpackOpen = scope:Value(false),
	selected = scope:Value(0), -- espacio de la mochila elegido (0 = ninguno)
	placeStand = scope:Value(0), -- estante donde estás eligiendo un mineral para dejar (0 = ninguno)
	depth = scope:Value(0),
}

----------------------------------------------------------------------
-- Cristales de la mina. Son compartidos, pero cada jugador ve SU mineral en cada uno:
-- se calcula con la semilla del cristal (igual que en el servidor) y se pinta aquí.
-- Cada cristal tiene un prompt "Picar" (mantener E); el tiempo depende de TU fuerza y
-- TU pico. Van antes que el HUD para que un fallo de la interfaz no impida picar.
----------------------------------------------------------------------

local prompts = {} -- prompt -> estado del cristal

local function refreshPrompts()
	local state = Fusion.peek(ui.state)
	local canMine = Fusion.peek(ui.carry) == ""
	for prompt, st in prompts do
		prompt.HoldDuration = Config.GetMineTime(state.Strength, state.Pickaxe, st.Zone, st.Rarity.Id)
		prompt.Enabled = canMine and not st.Hidden
		if Config.GetMissingPickaxe(state.Pickaxe, st.Rarity.Id) > 0 then
			prompt.ActionText = ("Picar (lento: pide pico Nv %d)"):format(st.Rarity.RequiredPickaxe)
		else
			prompt.ActionText = "Picar"
		end
	end
end

-- Pinta el cristal con tu mineral y lo hace visible.
local function showNode(node, st)
	st.Mineral = Config.GetNodeMineral(st.Seed, player.UserId, st.Count, st.Zone)
	st.Rarity = Config.RaritiesById[st.Mineral.Rarity]
	st.Hidden = false

	for _, entry in st.Parts do
		entry.Part.Transparency = entry.Original
	end
	local crystal = node:FindFirstChild("Crystal")
	local small = node:FindFirstChild("CrystalSmall")
	if crystal then
		crystal.Color = st.Rarity.Color
		-- Los minerales raros o mejores brillan.
		local light = crystal:FindFirstChildOfClass("PointLight")
		if st.Rarity.Index >= 3 then
			light = light or Instance.new("PointLight")
			light.Color = st.Rarity.Color
			light.Range = 10 + st.Rarity.Index * 2
			light.Brightness = 1.2
			light.Enabled = true
			light.Parent = crystal
		elseif light then
			light:Destroy()
		end
	end
	if small then
		small.Color = st.Rarity.Color
	end

	st.Prompt.ObjectText = ("%s (%s)"):format(st.Mineral.Name, st.Rarity.Name)
	refreshPrompts()
end

-- Lo rompiste: desaparece solo para ti.
local function hideNode(node, st)
	st.Hidden = true
	for _, entry in st.Parts do
		entry.Part.Transparency = 1
	end
	local crystal = node:FindFirstChild("Crystal")
	local light = crystal and crystal:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	refreshPrompts()
end

local nodeStates = {} -- node -> estado

local function attachNode(node)
	local rock = node:WaitForChild("Rock", 10)
	local zone = node:GetAttribute("Zone")
	local seed = node:GetAttribute("Seed")
	if not (rock and zone and seed) then
		return
	end

	local parts = {}
	for _, descendant in node:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, { Part = descendant, Original = descendant.Transparency })
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = rock

	local st = { Zone = zone, Seed = seed, Count = 0, Hidden = false, Parts = parts, Prompt = prompt }
	nodeStates[node] = st
	prompts[prompt] = st

	prompt.PromptButtonHoldBegan:Connect(function()
		mineStartRemote:FireServer(node)
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		mineCancelRemote:FireServer()
	end)
	prompt.Destroying:Connect(function()
		prompts[prompt] = nil
		nodeStates[node] = nil
	end)

	showNode(node, st)
end

local nodeFolder = workspace:WaitForChild("MineNodes")
for _, node in nodeFolder:GetChildren() do
	task.spawn(attachNode, node)
end
nodeFolder.ChildAdded:Connect(function(node)
	task.spawn(attachNode, node)
end)

nodeBrokenRemote.OnClientEvent:Connect(function(node, count)
	local st = nodeStates[node]
	if not st then
		return
	end
	st.Count = count
	hideNode(node, st)
	task.delay(Config.NodeRespawn, function()
		if nodeStates[node] == st then
			showNode(node, st)
		end
	end)
end)

----------------------------------------------------------------------
-- Estantes de TU base: un prompt en cada uno para dejar o retirar un mineral. La placa
-- verde del suelo (cobrar) la maneja el servidor al pisarla.
----------------------------------------------------------------------

local standPrompts = {} -- índice de estante -> { Prompt, Position }
local standPosition = nil -- estante cuyo panel de colocar está abierto

local function refreshStandPrompts()
	local stands = Fusion.peek(ui.state).Stands or {}
	for index, info in standPrompts do
		info.Prompt.ActionText = if (stands[index] or "") ~= "" then "Retirar mineral" else "Dejar mineral"
	end
end

local function attachStandPrompts(baseIndex)
	local basesFolder = workspace.World.Bases
	for _, child in basesFolder:GetChildren() do
		if child.Name == "Stand" and child:GetAttribute("BaseIndex") == baseIndex then
			local standIndex = child:GetAttribute("StandIndex")
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = ("Estante %d"):format(standIndex)
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = child
			prompt.Triggered:Connect(function()
				local stands = Fusion.peek(ui.state).Stands or {}
				if (stands[standIndex] or "") ~= "" then
					removeRemote:FireServer(standIndex)
				else
					ui.selected:set(0)
					standPosition = child.Position
					ui.placeStand:set(standIndex)
				end
			end)
			standPrompts[standIndex] = { Prompt = prompt, Position = child.Position }
		end
	end
	refreshStandPrompts()
end

-- Espera a que el servidor te asigne tu base (atributo OwnerUserId de su placa).
task.spawn(function()
	local basesFolder = workspace:WaitForChild("World"):WaitForChild("Bases")
	while true do
		for _, child in basesFolder:GetChildren() do
			if child:GetAttribute("OwnerUserId") == player.UserId then
				attachStandPrompts(child:GetAttribute("Index"))
				return
			end
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- Remotes del servidor
----------------------------------------------------------------------

stateRemote.OnClientEvent:Connect(function(newState)
	ui.state:set(newState)
	refreshPrompts()
	refreshStandPrompts()
end)

carryRemote.OnClientEvent:Connect(function(mineralId)
	ui.carry:set(mineralId)
	refreshPrompts()
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
openShopRemote.OnClientEvent:Connect(function(kind, id, position)
	shopPosition = position
	if kind == "Robux" then
		ui.shopKind:set("")
		ui.robuxKind:set(id)
	else
		ui.selected:set(0)
		ui.robuxKind:set("")
		ui.shopKind:set(id)
	end
end)

-- Profundidad (distancia a la línea de inicio) y cierre de la tienda al alejarse.
task.spawn(function()
	while true do
		task.wait(0.2)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			ui.depth:set(math.floor(math.max(hrp.Position.X, 0)))
			local shopIsOpen = Fusion.peek(ui.shopKind) ~= "" or Fusion.peek(ui.robuxKind) ~= ""
			if shopPosition and shopIsOpen and (hrp.Position - shopPosition).Magnitude > SHOP_CLOSE_DISTANCE then
				ui.shopKind:set("")
				ui.robuxKind:set("")
			end
			if standPosition and Fusion.peek(ui.placeStand) > 0 and (hrp.Position - standPosition).Magnitude > 30 then
				ui.placeStand:set(0)
			end
		end
	end
end)

-- Atajos de prueba (solo en Studio): teclas 1 a 5 = ir a esa zona, tecla 0 = +10.000 créditos.
if RunService:IsStudio() then
	local zoneKeys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
	}
	UserInputService.InputBegan:Connect(function(input, processedByUi)
		if processedByUi then
			return
		end
		local zone = zoneKeys[input.KeyCode]
		if zone then
			devRemote:FireServer("Zone", zone)
		elseif input.KeyCode == Enum.KeyCode.Zero then
			devRemote:FireServer("Money")
		elseif input.KeyCode == Enum.KeyCode.Nine then
			devRemote:FireServer("Mineral")
		end
	end)
end

requestRemote:FireServer()

HUD.mount(player:WaitForChild("PlayerGui"), ui, {
	onUpgrade = function(kind)
		buyUpgradeRemote:FireServer(kind)
	end,
	onSell = function(index)
		sellRemote:FireServer(index)
	end,
	onPlace = function(standIndex, inventoryIndex)
		placeRemote:FireServer(standIndex, inventoryIndex)
	end,
})
