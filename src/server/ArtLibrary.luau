-- Modelos 3D hechos en Blender (ver art/). Carga las piezas de ArtAssets con InsertService al
-- arrancar el servidor y arma modelos con ellas. Si una pieza no carga (o su forma no
-- coincide con lo esperado), ese modelo no se usa y el juego sigue con el hecho con código.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssets = require(ReplicatedStorage.Shared.ArtAssets)
local Config = require(ReplicatedStorage.Shared.Config)

local ArtLibrary = {}

local templates = {} -- nombre del modelo -> { parte -> MeshPart plantilla }

local LOAD_TIMEOUT = 25 -- segundos máximos esperando a Roblox

-- Compara la forma cargada con la esperada (sin importar la escala ni el orden de los ejes).
local function shapeMatches(native, expected)
	local a = { native.X, native.Y, native.Z }
	local b = { expected.X, expected.Y, expected.Z }
	table.sort(a)
	table.sort(b)
	if a[3] <= 0 or b[3] <= 0 then
		return false
	end
	local scale = b[3] / a[3]
	for index = 1, 3 do
		if math.abs(a[index] * scale - b[index]) > 0.18 * b[3] then
			return false
		end
	end
	return true
end

local function loadPart(assetName, partName, info)
	local ok, container = pcall(function()
		return InsertService:LoadAsset(info.Id)
	end)
	if not ok or not container then
		warn(("[Art] No se pudo cargar %s.%s (%s)"):format(assetName, partName, tostring(container)))
		return nil
	end
	local mesh = container:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		container:Destroy()
		warn(("[Art] %s.%s no trae ninguna malla"):format(assetName, partName))
		return nil
	end
	local template = mesh:Clone()
	container:Destroy()
	if not shapeMatches(template.Size, info.Size) then
		warn(("[Art] %s.%s tiene otra forma de la esperada (%s vs %s); no se usa"):format(assetName, partName, tostring(template.Size), tostring(info.Size)))
		template:Destroy()
		return nil
	end
	return template
end

-- Carga todos los modelos (en paralelo) y espera a que terminen o se acabe el tiempo.
function ArtLibrary.Preload()
	local pendingAssets = 0
	for assetName, parts in ArtAssets do
		pendingAssets += 1
		task.spawn(function()
			local loaded, ok, remaining = {}, true, 0
			for partName, info in parts do
				remaining += 1
				task.spawn(function()
					local template = loadPart(assetName, partName, info)
					if template then
						loaded[partName] = template
					else
						ok = false
					end
					remaining -= 1
				end)
			end
			local started = os.clock()
			while remaining > 0 and os.clock() - started < LOAD_TIMEOUT do
				task.wait(0.1)
			end
			-- el modelo se publica entero o no se publica
			if ok and remaining == 0 then
				templates[assetName] = loaded
			end
			pendingAssets -= 1
		end)
	end
	while pendingAssets > 0 do
		task.wait(0.1)
	end
	for assetName in ArtAssets do
		print(("[Art] %s: %s"):format(assetName, if templates[assetName] then "modelo 3D listo" else "se usa el de código"))
	end

	-- Los jugadores arman en su pantalla el mineral que les toca en cada cristal: necesitan las
	-- plantillas de los minerales.
	if templates.minerals or templates.ambient then
		local folder = Instance.new("Folder")
		folder.Name = "ArtTemplates"
		for mineralId, mesh in templates.minerals or {} do
			local copy = mesh:Clone()
			copy.Name = mineralId
			copy.Parent = folder
		end
		-- Naves y objetos del cielo (los arma y anima cada pantalla, ver src/client/Ambient.luau).
		if templates.ambient then
			local ambientFolder = Instance.new("Folder")
			ambientFolder.Name = "ambient"
			for partName, mesh in templates.ambient do
				local copy = mesh:Clone()
				copy.Name = partName
				copy.Parent = ambientFolder
			end
			ambientFolder.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
end

function ArtLibrary.IsReady(assetName)
	return templates[assetName] ~= nil
end

-- Arma el modelo con sus piezas, colocadas respecto a `origin` (la base del modelo).
-- `overrides[parte]` puede cambiar Tint, Material, Transparency, CanCollide.
function ArtLibrary.Build(assetName, origin, overrides)
	local parts = templates[assetName]
	if not parts then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = assetName
	for partName, template in parts do
		local info = ArtAssets[assetName][partName]
		local extra = overrides and overrides[partName] or {}
		local part = template:Clone()
		part.Name = partName
		part.Anchored = true
		part.Size = info.Size
		part.CFrame = origin * CFrame.new(info.Center)
		part.Color = extra.Tint or info.Tint
		part.Material = extra.Material or Enum.Material[info.Material]
		part.Transparency = extra.Transparency or 0
		part.CanCollide = extra.CanCollide == true
		part.CanTouch = false
		part.CanQuery = extra.CanQuery ~= false
		part.CastShadow = true
		part.Parent = model
	end
	model.WorldPivot = origin
	return model
end

-- ¿Hay modelo 3D para este mineral?
function ArtLibrary.HasMineral(mineralId)
	return templates.minerals ~= nil and templates.minerals[mineralId] ~= nil
end

-- Un mineral con su diseño propio: una sola pieza, con la base en `origin`, a escala `scale`
-- y pintada del color del mineral. Devuelve nil si no hay modelo.
function ArtLibrary.BuildMineral(mineralId, origin, scale, color)
	local template = templates.minerals and templates.minerals[mineralId]
	local info = ArtAssets.minerals and ArtAssets.minerals[mineralId]
	if not template or not info then
		return nil
	end
	local part = template:Clone()
	part.Name = mineralId
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Size = info.Size * scale
	part.CFrame = origin * CFrame.new(info.Center * scale)
	part.Color = color or Config.GetMineralColor(mineralId)
	part.Material = Enum.Material[info.Material]
	part.Transparency = if info.Material == "Glass" then 0.1 else 0
	return part
end

-- Tienda con piezas 3D: techo, toldo, marco del cartel y antena del color de la tienda, y el
-- nombre escrito en el letrero. Lo que está a la altura de la cabeza no choca.
function ArtLibrary.BuildShop(origin, text, accent)
	local solid = { CanCollide = true }
	local model = ArtLibrary.Build("shop", origin, {
		base = solid,
		body = solid,
		counter = solid,
		roof = { Tint = accent },
		awning_a = { Tint = accent },
		sign_trim = { Tint = accent },
		antenna_tip = { Tint = accent },
		porthole_glass = { Transparency = 0.25 },
	})
	if not model then
		return nil
	end
	model.Name = "Shop"
	local sign = model:FindFirstChild("sign")
	if sign then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = accent
		label.Parent = gui
	end
	return model
end

return ArtLibrary
