-- Conecta los remotes con el HUD y con los puntos de picado de los minerales.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local HUD = require(script.Parent.HUD)
local AdminPanel = require(script.Parent.AdminPanel)

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
local sellRemote = remotes:WaitForChild("SellMineral")
local adminRemote = remotes:WaitForChild("AdminCommand")
local adminStatusRemote = remotes:WaitForChild("AdminStatus")
local placeRemote = remotes:WaitForChild("PlaceMineral")
local removeRemote = remotes:WaitForChild("RemoveMineral")
local selectSlotRemote = remotes:WaitForChild("SelectSlot")
local selectedRemote = remotes:WaitForChild("Selected")
local fuseRemote = remotes:WaitForChild("FuseMinerals")
local rebirthRemote = remotes:WaitForChild("RebirthRequest")
local giftOfferRemote = remotes:WaitForChild("GiftOffer")
local giftCloseRemote = remotes:WaitForChild("GiftClose")
local giftRequestRemote = remotes:WaitForChild("GiftRequest")
local giftAnswerRemote = remotes:WaitForChild("GiftAnswer")
local sellAllRemote = remotes:WaitForChild("SellAll")
local buyRobuxRemote = remotes:WaitForChild("BuyRobux")

local SHOP_CLOSE_DISTANCE = 18 -- la tienda se cierra si te alejas más que esto

-- Usamos nuestra propia barra de inventario, no la de Roblox.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local scope = Fusion.scoped(Fusion)
local ui = {
	state = scope:Value({ Money = 0, Speed = 0, Strength = 0, Pickaxe = 0, Inventory = {}, Stands = {}, Rebirths = 0, Passes = {}, Shields = 0 }),
	carry = scope:Value(""), -- id del mineral que llevas ("" = ninguno)
	notice = scope:Value(""),
	shopKind = scope:Value(""), -- tienda de mejoras abierta: "Sell", "Pickaxe", "Strength" o "Speed"
	robuxKind = scope:Value(""), -- tienda de Robux abierta: "X2", "Boots", "Shield" o "Credits"
	fuseOpen = scope:Value(false), -- panel del horno de fusión
	rebirthOpen = scope:Value(false), -- panel del altar de renacimiento
	giftOffer = scope:Value(false), -- regalo que te ofrecen: { Id, From, MineralId } o false
	giftPicking = scope:Value(false), -- eligiendo a quién regalar el mineral seleccionado
	backpackOpen = scope:Value(false),
	selected = scope:Value(0), -- espacio de la mochila elegido en el panel (0 = ninguno)
	held = scope:Value(0), -- espacio de la barra cuyo mineral llevas en la mano (0 = ninguno)
	depth = scope:Value(0),
	isAdmin = scope:Value(false), -- lo decide el servidor
	adminOpen = scope:Value(false),
	adminPlayers = scope:Value({}), -- { { UserId, Name } } de los jugadores del servidor
	adminTarget = scope:Value(player.UserId), -- a quién se aplican las acciones del panel
	adminAmount = scope:Value(""),
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
	node:WaitForChild("Crystal", 10)
	node:WaitForChild("CrystalSmall", 10)
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
-- Estantes de TU base.
--  * Dejar un mineral: elegirlo con 1 a 5 (el personaje lo lleva en la mano) y mantener E
--    junto a un estante vacío.
--  * Retirarlo: mantener E junto a un estante ocupado.
-- La placa verde del suelo (cobrar) la maneja el servidor al pisarla.
----------------------------------------------------------------------

local standPrompts = {} -- índice de estante -> { Prompt, Position }

local noticeId = 0
local function showNotice(text)
	noticeId += 1
	local id = noticeId
	ui.notice:set(text)
	task.delay(4, function()
		if noticeId == id then
			ui.notice:set("")
		end
	end)
end

local function isStandEmpty(index)
	local stands = Fusion.peek(ui.state).Stands or {}
	return (stands[index] or "") == ""
end

local function refreshStandPrompts()
	for index, info in standPrompts do
		info.Prompt.ActionText = if isStandEmpty(index) then "Dejar mineral" else "Retirar mineral"
	end
end

-- Deja en el estante el mineral que llevas en la mano.
local function placeHeldMineral(standIndex)
	local slot = Fusion.peek(ui.held)
	if slot < 1 then
		showNotice("Debes tener un mineral en la mano para dejarlo.")
		return
	end
	placeRemote:FireServer(standIndex, slot)
end

local function attachStandPrompts(baseIndex)
	local basesFolder = workspace.World.Bases
	for _, child in basesFolder:GetChildren() do
		if child.Name == "Stand" and child:GetAttribute("BaseIndex") == baseIndex then
			local standIndex = child:GetAttribute("StandIndex")
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = ("Piso %d · Estante %d"):format((standIndex - 1) // 8 + 1, (standIndex - 1) % 8 + 1)
			prompt.Enabled = not child:GetAttribute("Locked")
			child:GetAttributeChangedSignal("Locked"):Connect(function()
				prompt.Enabled = not child:GetAttribute("Locked")
			end)
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = child
			prompt.Triggered:Connect(function()
				if not isStandEmpty(standIndex) then
					removeRemote:FireServer(standIndex)
					return
				end
				placeHeldMineral(standIndex)
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

-- Carteles y prompts de las bases (bloqueado, costos, nuevo piso) solo se ven en TU base:
-- el servidor los muestra para quien los necesite y aquí se ocultan los de las demás.
task.spawn(function()
	local basesFolder = workspace:WaitForChild("World"):WaitForChild("Bases")
	while true do
		local myBase = nil
		for _, child in basesFolder:GetChildren() do
			if child:GetAttribute("OwnerUserId") == player.UserId then
				myBase = child:GetAttribute("Index")
				break
			end
		end
		for _, descendant in basesFolder:GetDescendants() do
			if string.sub(descendant.Name, 1, 9) == "OwnerOnly" and (descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt")) then
				local holder = descendant.Parent
				if holder and holder:GetAttribute("BaseIndex") ~= myBase and descendant.Enabled then
					descendant.Enabled = false
				end
			end
		end
		task.wait(0.3)
	end
end)

-- Regalar: con un mineral en la mano, aparece "Regalar" sobre los demás jugadores (con E, o
-- tocando el botón en celular). El servidor revisa todo; el otro jugador acepta o rechaza.
local giftPrompts = {} -- jugador -> prompt

local function refreshGiftPrompts()
	local holding = Fusion.peek(ui.held) > 0
	for _, prompt in giftPrompts do
		prompt.Enabled = holding
	end
end

local function attachGiftPrompt(other)
	if other == player then
		return
	end
	local function onCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Regalar mineral"
		prompt.ObjectText = other.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = Fusion.peek(ui.held) > 0
		prompt.Parent = root
		giftPrompts[other] = prompt
		prompt.Triggered:Connect(function()
			local slot = Fusion.peek(ui.held)
			if slot > 0 then
				giftRequestRemote:FireServer(other.UserId, slot)
			end
		end)
	end
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
	other.CharacterAdded:Connect(onCharacter)
end

for _, other in Players:GetPlayers() do
	attachGiftPrompt(other)
end
Players.PlayerAdded:Connect(attachGiftPrompt)
Players.PlayerRemoving:Connect(function(other)
	giftPrompts[other] = nil
end)
scope:Observer(ui.held):onChange(refreshGiftPrompts)

-- Elige (o suelta) el mineral de un espacio de la barra: el personaje lo lleva en la mano.
-- Pulsar el mismo espacio otra vez lo suelta.
local function selectSlot(slot)
	local inventory = Fusion.peek(ui.state).Inventory
	local newSlot = if slot > #inventory or Fusion.peek(ui.held) == slot then 0 else slot
	ui.held:set(newSlot)
	selectSlotRemote:FireServer(newSlot)
end

local SLOT_KEYS = {
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
	local slot = SLOT_KEYS[input.KeyCode]
	if not slot then
		return
	end
	selectSlot(slot)
end)

----------------------------------------------------------------------
-- Remotes del servidor
----------------------------------------------------------------------

stateRemote.OnClientEvent:Connect(function(newState)
	ui.state:set(newState)
	refreshPrompts()
	refreshStandPrompts()
end)

selectedRemote.OnClientEvent:Connect(function(slot)
	ui.held:set(slot)
end)

carryRemote.OnClientEvent:Connect(function(mineralId)
	ui.carry:set(mineralId)
	refreshPrompts()
end)

noticeRemote.OnClientEvent:Connect(showNotice)

giftOfferRemote.OnClientEvent:Connect(function(id, fromName, mineralId)
	ui.giftOffer:set({ Id = id, From = fromName, MineralId = mineralId })
end)
giftCloseRemote.OnClientEvent:Connect(function(id)
	local offer = Fusion.peek(ui.giftOffer)
	if offer and offer.Id == id then
		ui.giftOffer:set(false)
	end
end)

local shopPosition = nil
openShopRemote.OnClientEvent:Connect(function(kind, id, position)
	shopPosition = position
	if kind == "Fusion" or kind == "Rebirth" then
		ui.shopKind:set("")
		ui.robuxKind:set("")
		ui.fuseOpen:set(kind == "Fusion")
		ui.rebirthOpen:set(kind == "Rebirth")
		return
	end
	ui.fuseOpen:set(false)
	ui.rebirthOpen:set(false)
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
			local shopIsOpen = Fusion.peek(ui.shopKind) ~= "" or Fusion.peek(ui.robuxKind) ~= "" or Fusion.peek(ui.fuseOpen) or Fusion.peek(ui.rebirthOpen)
			if shopPosition and shopIsOpen and (hrp.Position - shopPosition).Magnitude > SHOP_CLOSE_DISTANCE then
				ui.shopKind:set("")
				ui.robuxKind:set("")
				ui.fuseOpen:set(false)
				ui.rebirthOpen:set(false)
			end
		end
	end
end)

-- Panel de administrador: el servidor decide quién es admin y valida cada orden.
local function refreshAdminPlayers()
	local list = {}
	local targetStillHere = false
	for _, other in Players:GetPlayers() do
		table.insert(list, { UserId = other.UserId, Name = other.DisplayName })
		if other.UserId == Fusion.peek(ui.adminTarget) then
			targetStillHere = true
		end
	end
	ui.adminPlayers:set(list)
	if not targetStillHere then
		ui.adminTarget:set(player.UserId)
	end
end
refreshAdminPlayers()
Players.PlayerAdded:Connect(refreshAdminPlayers)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshAdminPlayers)
end)

adminStatusRemote.OnClientEvent:Connect(function(isAdmin)
	ui.isAdmin:set(isAdmin == true)
end)

UserInputService.InputBegan:Connect(function(input, processedByUi)
	if not processedByUi and input.KeyCode == Enum.KeyCode.Backquote and Fusion.peek(ui.isAdmin) then
		ui.adminOpen:set(not Fusion.peek(ui.adminOpen))
	end
end)

requestRemote:FireServer()

HUD.mount(player:WaitForChild("PlayerGui"), ui, {
	onUpgrade = function(kind)
		buyUpgradeRemote:FireServer(kind)
	end,
	onSell = function(index)
		sellRemote:FireServer(index)
	end,
	onSelectSlot = selectSlot,
	onFuse = function(rarityId)
		fuseRemote:FireServer(rarityId)
	end,
	onRebirth = function()
		rebirthRemote:FireServer()
	end,
	onSellAll = function()
		sellAllRemote:FireServer()
	end,
	onBuyRobux = function(kind)
		buyRobuxRemote:FireServer(kind)
	end,
	onGift = function(userId, index)
		giftRequestRemote:FireServer(userId, index)
	end,
	onGiftAnswer = function(offerId, accept)
		giftAnswerRemote:FireServer(offerId, accept)
		ui.giftOffer:set(false)
	end,
})

-- El panel va al final: si fallara, no impide jugar.
local adminOk, adminError = pcall(function()
	AdminPanel.mount(player:WaitForChild("PlayerGui"), ui, function(command, targetUserId, a, b)
		adminRemote:FireServer(command, targetUserId, a, b)
	end)
end)
if not adminOk then
	warn("[AdminPanel] No se pudo crear el panel:", adminError)
end
