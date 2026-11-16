-- Regalos de minerales entre jugadores. Solo regalos (nada de intercambio por dinero) y el
-- receptor tiene que aceptar. Mientras el regalo está pendiente el mineral sale de la mochila
-- del que regala y su espacio queda apartado, para que siempre pueda volver (si el otro
-- rechaza, no responde en 30 s o se va).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)

local Gifts = {}

local OFFER_SECONDS = 30
local MAX_DISTANCE = 18 -- studs entre los dos jugadores
local COOLDOWN_SECONDS = 3 -- entre un regalo y el siguiente del mismo jugador

local remotes
local offers = {} -- id -> { Id, From, To, MineralId, Expires }
local outgoing = {} -- player -> offer (un regalo pendiente a la vez)
local incoming = {} -- player -> offer (una oferta a la vez)
local lastSent = {} -- player -> os.clock() del último regalo
local nextId = 0

local function notice(player, text)
	if player and player.Parent == Players then
		remotes.Notice:FireClient(player, text)
	end
end

local function mineralName(id)
	local mineral = Config.MineralsById[id]
	return if mineral then mineral.Name else id
end

-- Cierra la oferta: la quita de las listas y avisa al receptor para que cierre su ventana.
local function close(offer)
	offers[offer.Id] = nil
	if outgoing[offer.From] == offer then
		outgoing[offer.From] = nil
	end
	if incoming[offer.To] == offer then
		incoming[offer.To] = nil
	end
	if offer.To.Parent == Players then
		remotes.GiftClose:FireClient(offer.To, offer.Id)
	end
	Economy.Reserve(offer.From, -1)
end

-- El regalo no se hizo: el mineral vuelve al que lo regalaba.
local function giveBack(offer, reason)
	close(offer)
	Economy.ReturnMineral(offer.From, offer.MineralId)
	if reason then
		notice(offer.From, reason)
	end
end

local function request(sender, targetUserId, index)
	if type(targetUserId) ~= "number" or type(index) ~= "number" or index % 1 ~= 0 then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == sender or not Economy.Get(target) then
		return
	end
	-- Solo se regala cara a cara: los dos tienen que estar cerca.
	local senderRoot = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not senderRoot or not targetRoot or (senderRoot.Position - targetRoot.Position).Magnitude > MAX_DISTANCE then
		notice(sender, "Acércate más a " .. target.DisplayName .. " para regalarle.")
		return
	end
	if outgoing[sender] then
		notice(sender, "Ya tienes un regalo esperando respuesta.")
		return
	end
	if incoming[target] then
		notice(sender, target.DisplayName .. " está atendiendo otro regalo. Prueba en un momento.")
		return
	end
	if os.clock() - (lastSent[sender] or -100) < COOLDOWN_SECONDS then
		return
	end
	local mineralId = Economy.TakeMineral(sender, index)
	if not mineralId then
		return
	end
	Economy.Reserve(sender, 1)
	lastSent[sender] = os.clock()

	nextId += 1
	local offer = { Id = nextId, From = sender, To = target, MineralId = mineralId, Expires = os.clock() + OFFER_SECONDS }
	offers[offer.Id] = offer
	outgoing[sender] = offer
	incoming[target] = offer
	remotes.GiftOffer:FireClient(target, offer.Id, sender.DisplayName, mineralId)
	notice(sender, ("Le ofreciste %s a %s."):format(mineralName(mineralId), target.DisplayName))
end

local function answer(player, offerId, accept)
	local offer = type(offerId) == "number" and offers[offerId]
	if not offer or offer.To ~= player then
		return
	end
	if accept ~= true then
		giveBack(offer, player.DisplayName .. " no quiso el regalo.")
		return
	end
	if Economy.FreeSlots(player) <= 0 then
		notice(player, "¡Mochila llena! Vende algo y vuelve a pedirlo.")
		giveBack(offer, player.DisplayName .. " tiene la mochila llena. Te devolvimos el mineral.")
		return
	end
	close(offer)
	Economy.AddMineral(player, offer.MineralId)
	notice(player, ("¡Recibiste %s de %s!"):format(mineralName(offer.MineralId), offer.From.DisplayName))
	notice(offer.From, ("%s recibió tu regalo."):format(player.DisplayName))
end

-- Al irse un jugador se cancelan sus regalos (el mineral vuelve a quien lo regalaba).
function Gifts.PlayerLeaving(player)
	local sent = outgoing[player]
	if sent then
		giveBack(sent)
	end
	local received = incoming[player]
	if received then
		giveBack(received, player.DisplayName .. " se fue. Te devolvimos el mineral.")
	end
	lastSent[player] = nil
end

function Gifts.Init(remoteFolder)
	remotes = remoteFolder
	remotes.GiftRequest.OnServerEvent:Connect(request)
	remotes.GiftAnswer.OnServerEvent:Connect(answer)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, offer in offers do
				if os.clock() >= offer.Expires then
					giveBack(offer, "Nadie respondió a tu regalo. Te devolvimos el mineral.")
				end
			end
		end
	end)
end

return Gifts
