-- Compras con Robux: pases (x2 dinero, botas VIP) y productos (escudo, paquete de dinero).
-- Cada uno se configura con su Id en Config.RobuxProducts (Id = 0 significa "aún no creado":
-- el botón dice "¡Muy pronto!"). El servidor revisa todo; el cliente solo pide la compra.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)

local Robux = {}

local remotes

local function notice(player, text)
	if player.Parent == Players then
		remotes.Notice:FireClient(player, text)
	end
end

-- Qué producto es un Id de producto (Developer Product), o nil.
local function productByDeveloperId(productId)
	for kind, product in Config.RobuxProducts do
		if product.Kind == "Product" and product.Id ~= 0 and product.Id == productId then
			return kind, product
		end
	end
	return nil
end

-- Qué pase es un Id de pase (Game Pass), o nil.
local function passById(passId)
	for kind, product in Config.RobuxProducts do
		if product.Kind == "Pass" and product.Id ~= 0 and product.Id == passId then
			return kind, product
		end
	end
	return nil
end

-- El cliente pide comprar algo: se abre la ventana de compra de Roblox.
local function requestPurchase(player, kind)
	local product = type(kind) == "string" and Config.RobuxProducts[kind]
	if not product then
		return
	end
	if product.Id == 0 then
		notice(player, "¡Muy pronto!")
		return
	end
	local data = Economy.Get(player)
	if not data then
		return
	end
	if product.Kind == "Pass" then
		if data.Passes[kind] then
			notice(player, "¡Ya tienes este pase!")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, product.Id)
	else
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end
end

-- Pases: se vuelve a comprobar al entrar (por si lo compró en otro servidor o antes).
function Robux.CheckPasses(player)
	for kind, product in Config.RobuxProducts do
		if product.Kind == "Pass" and product.Id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.Id)
				end)
				-- Roblox es quien decide: si tiene el pase se activa, y si no, se quita (así los pases
				-- que se dieron desde el panel de admin para probar no quedan guardados para siempre).
				if ok and player.Parent == Players then
					Economy.GrantPass(player, kind, owns == true)
				end
			end)
		end
	end
end

function Robux.Init(remoteFolder)
	remotes = remoteFolder
	remotes.BuyRobux.OnServerEvent:Connect(requestPurchase)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local kind, product = passById(passId)
		if kind and Economy.GrantPass(player, kind, true) then
			notice(player, ("¡Ya tienes: %s!"):format(product.Name))
		end
	end)

	-- Productos: Roblox exige responder siempre. Solo se confirma cuando ya se entregó el
	-- producto en los datos del jugador.
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not Economy.Get(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local kind, product = productByDeveloperId(receipt.ProductId)
		if kind == "Shield" then
			Economy.AddShield(player, 1)
			notice(player, "¡Tienes un escudo anti-Alien!")
		elseif kind == "Credits" then
			local amount = Economy.GrantCredits(player)
			notice(player, "+" .. Config.FormatMoney(amount))
		else
			warn("[Robux] Producto desconocido:", receipt.ProductId, product)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Robux
