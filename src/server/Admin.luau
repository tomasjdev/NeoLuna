-- Panel de administrador: quién es admin y los comandos que puede dar.
-- El servidor revisa SIEMPRE que quien manda el comando sea admin; el menú del cliente solo
-- es una comodidad y no da ningún permiso por sí mismo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)

local Admin = {}

local remotes

-- Admin: quien prueba en Studio, el dueño del juego publicado y los UserIds de Config.AdminUserIds.
function Admin.IsAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function notice(player, text)
	remotes.Notice:FireClient(player, text)
end

local function isAmount(value)
	return type(value) == "number" and value == value and math.abs(value) <= 1e13
end

-- El objetivo del comando: el jugador con ese UserId si está en el servidor, si no el propio admin.
local function resolveTarget(admin, userId)
	if type(userId) == "number" then
		local target = Players:GetPlayerByUserId(userId)
		if target then
			return target
		end
	end
	return admin
end

local function describe(admin, target)
	return if target == admin then "tú" else target.DisplayName
end

local commands = {}

-- Dar (o quitar, si es negativo) dinero.
function commands.AddMoney(admin, target, amount)
	if not isAmount(amount) or amount == 0 then
		return
	end
	Economy.AddMoney(target, amount)
	local text = (if amount > 0 then "+" else "-") .. Config.FormatMoney(math.abs(amount))
	notice(target, "[Admin] " .. text)
	if target ~= admin then
		notice(admin, ("[Admin] %s para %s"):format(text, describe(admin, target)))
	end
end

-- Dar un mineral a la mochila.
function commands.GiveMineral(admin, target, mineralId)
	local mineral = type(mineralId) == "string" and Config.MineralsById[mineralId]
	if not mineral then
		return
	end
	local ok = Economy.AddMineral(target, mineralId)
	local text = if ok then ("+1 %s"):format(mineral.Name) else "La mochila está llena"
	notice(admin, ("[Admin] %s (%s)"):format(text, describe(admin, target)))
	if ok and target ~= admin then
		notice(target, "[Admin] " .. text)
	end
end

-- Sube o baja el nivel de una mejora (delta puede ser grande: se limita al mínimo y máximo).
function commands.AdjustUpgrade(admin, target, kind, delta)
	if type(kind) ~= "string" or not Config.Upgrades[kind] or not isAmount(delta) then
		return
	end
	local level = Economy.AdjustUpgrade(target, kind, delta)
	if level then
		notice(admin, ("[Admin] %s: nivel %d (%s)"):format(Config.Upgrades[kind].Label, level, describe(admin, target)))
	end
end

-- Cambia cuántos pisos tiene el jugador (delta: +1, -1, o "todo" = todos los pisos y estantes).
function commands.SetFloors(admin, target, mode)
	local data = Economy.Get(target)
	if not data then
		return
	end
	local current = Config.CountFloors(data.FloorStands)
	local ok, message
	if mode == "all" then
		ok, message = Economy.AdminSetFloors(target, Config.MaxFloors, true)
	elseif mode == "reset" then
		ok, message = Economy.AdminSetFloors(target, 1, false)
	elseif isAmount(mode) then
		ok, message = Economy.AdminSetFloors(target, current + mode, false)
	else
		return
	end
	local text = if ok then ("%d pisos"):format(Config.CountFloors(data.FloorStands)) else message
	notice(admin, ("[Admin] %s (%s)"):format(text, describe(admin, target)))
end

-- Sube o baja los renacimientos del jugador (para probar).
function commands.AdjustRebirths(admin, target, delta)
	if not isAmount(delta) then
		return
	end
	local count = Economy.AdminAdjustRebirths(target, delta)
	if count then
		notice(admin, ("[Admin] %d renacimientos (%s)"):format(count, describe(admin, target)))
	end
end

-- Prueba de Robux sin comprar: activa o quita un pase, da un escudo o un paquete de dinero.
function commands.GrantRobux(admin, target, kind, value)
	local text
	if kind == "X2" or kind == "Boots" then
		local owned = value == true
		Economy.GrantPass(target, kind, owned)
		text = ("%s %s"):format(Config.RobuxProducts[kind].Name, if owned then "activado" else "quitado")
	elseif kind == "Shield" then
		Economy.AddShield(target, 1)
		text = "+1 escudo"
	elseif kind == "Credits" then
		text = "+" .. Config.FormatMoney(Economy.GrantCredits(target))
	else
		return
	end
	notice(admin, ("[Admin] %s (%s)"):format(text, describe(admin, target)))
end

-- Reinicia el máximo de ingreso de estantes (afecta al costo del renacimiento).
function commands.ResetPeak(admin, target)
	if Economy.AdminResetPeak(target) then
		notice(admin, ("[Admin] Máximo de ingreso reiniciado (%s)"):format(describe(admin, target)))
	end
end

-- Lleva al jugador al inicio de una zona de la mina.
function commands.Teleport(admin, target, zone)
	if not isAmount(zone) then
		return
	end
	local character = target.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local clamped = math.clamp(math.floor(zone), 1, Config.ZoneCount)
		hrp.CFrame = CFrame.new((clamped - 1) * Config.ZoneLength + 25, 5, 0)
		notice(admin, ("[Admin] Zona %d (%s)"):format(clamped, describe(admin, target)))
	end
end

-- Informe de los estantes del propio admin (cuánto genera cada uno y cuánto ha juntado).
function commands.Report(admin)
	local data = Economy.Get(admin)
	if not data then
		return
	end
	local now = os.time()
	local count, rate, pending = 0, 0, 0
	for index, mineralId in data.Stands do
		if mineralId ~= "" then
			local standRate = Config.GetMineralIncome(mineralId) * Config.GetRebirthMultiplier(data.Rebirths)
			local standPending = Config.GetStandPending(mineralId, data.StandSince[index], now, Config.GetRebirthMultiplier(data.Rebirths))
			count += 1
			rate += standRate
			pending += standPending
			print(("[Admin] Estante %d: %s genera %s por segundo y lleva %s"):format(index, mineralId, Config.FormatMoney(standRate), Config.FormatMoney(standPending)))
		end
	end
	notice(admin, ("[Admin] %d estantes · %s por segundo · juntado %s"):format(count, Config.FormatMoney(rate), Config.FormatMoney(pending)))
end

function Admin.Init(remoteFolder)
	remotes = remoteFolder
	remotes.AdminCommand.OnServerEvent:Connect(function(player, command, targetUserId, a, b)
		if not Admin.IsAdmin(player) then
			warn(("[Admin] %s (%d) intentó usar el panel sin permiso"):format(player.Name, player.UserId))
			return
		end
		local handler = type(command) == "string" and commands[command]
		if handler then
			handler(player, resolveTarget(player, targetUserId), a, b)
		end
	end)
end

return Admin
