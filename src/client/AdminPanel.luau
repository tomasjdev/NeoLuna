-- Panel de administrador (solo se muestra a admins; el servidor valida cada orden).
-- Se abre con el botón "ADMIN" o con la tecla ` (la de arriba del Tab).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
local peek = Fusion.peek

local WHITE = Color3.new(1, 1, 1)
local TEXT = Color3.fromRGB(50, 40, 90)
local DIM = Color3.fromRGB(110, 100, 150)
local BORDER = Color3.fromRGB(190, 165, 255)
local PURPLE = Color3.fromRGB(130, 95, 235)
local GREEN = Color3.fromRGB(45, 175, 110)
local RED = Color3.fromRGB(225, 85, 95)
local GREY = Color3.fromRGB(190, 184, 208)
local FIELD = Color3.fromRGB(240, 236, 250)
local FONT = Enum.Font.GothamBold

local AdminPanel = {}

-- ui = { isAdmin, adminOpen, adminPlayers, adminTarget, adminAmount } (Values de Fusion)
-- send(command, targetUserId, a, b): manda el comando al servidor.
function AdminPanel.mount(parent, ui, send)
	local scope = Fusion.scoped(Fusion)

	local function rounded(radius)
		return scope:New "UICorner" { CornerRadius = UDim.new(0, radius) }
	end

	local function target()
		return peek(ui.adminTarget)
	end

	local function amount()
		local digits = peek(ui.adminAmount):gsub("[^%d]", "")
		return tonumber(digits) or 0
	end

	local function Button(props)
		return scope:New "TextButton" {
			Size = props.Size or UDim2.fromOffset(92, 32),
			BackgroundColor3 = props.Color or PURPLE,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Font = FONT,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = props.TextColor or WHITE,
			Text = props.Text,
			Visible = props.Visible,

			[OnEvent "Activated"] = props.OnClick,
			[Children] = { rounded(8) },
		}
	end

	-- Fila de elementos que se acomodan en varias líneas.
	local function Wrap(items)
		local children = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
		}
		for index, item in items do
			item.LayoutOrder = index
			table.insert(children, item)
		end
		return scope:New "Frame" {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = children,
		}
	end

	local function Section(order, title, content)
		content.LayoutOrder = 2
		return scope:New "Frame" {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) },
				scope:New "TextLabel" {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 15,
					TextColor3 = TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = title,
				},
				content,
			},
		}
	end

	----------------------------------------------------------------------
	-- Secciones
	----------------------------------------------------------------------

	-- Jugador al que se aplican las acciones (máximo Config.MaxPlayers en el servidor).
	local targetButtons = {}
	for index = 1, Config.MaxPlayers do
		local player = scope:Computed(function(use)
			return use(ui.adminPlayers)[index] or false
		end)
		table.insert(
			targetButtons,
			Button({
				Size = UDim2.fromOffset(120, 32),
				Visible = scope:Computed(function(use)
					return use(player) ~= false
				end),
				Text = scope:Computed(function(use)
					local p = use(player)
					return if p then p.Name else ""
				end),
				Color = scope:Computed(function(use)
					local p = use(player)
					return if p and use(ui.adminTarget) == p.UserId then GREEN else GREY
				end),
				OnClick = function()
					local p = peek(player)
					if p then
						ui.adminTarget:set(p.UserId)
					end
				end,
			})
		)
	end

	local amountBox = scope:New "TextBox" {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = FIELD,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 16,
		TextColor3 = TEXT,
		PlaceholderText = "Cantidad de dinero (ej. 50000)",
		PlaceholderColor3 = DIM,
		Text = "",
		ClearTextOnFocus = false,

		[OnChange "Text"] = function(text)
			ui.adminAmount:set(text)
		end,
		[Children] = { rounded(8) },
	}

	local quickAmounts = {}
	for _, value in { 1000, 100000, 10000000, 1000000000 } do
		table.insert(
			quickAmounts,
			Button({
				Size = UDim2.fromOffset(88, 32),
				Text = "+" .. Config.FormatMoney(value),
				OnClick = function()
					send("AddMoney", target(), value)
				end,
			})
		)
	end

	local moneyButtons = {
		Button({
			Size = UDim2.fromOffset(190, 34),
			Text = "Dar la cantidad",
			Color = GREEN,
			OnClick = function()
				local n = amount()
				if n > 0 then
					send("AddMoney", target(), n)
				end
			end,
		}),
		Button({
			Size = UDim2.fromOffset(190, 34),
			Text = "Quitar la cantidad",
			Color = RED,
			OnClick = function()
				local n = amount()
				if n > 0 then
					send("AddMoney", target(), -n)
				end
			end,
		}),
	}

	local mineralButtons = {}
	for _, mineral in Config.Minerals do
		table.insert(
			mineralButtons,
			Button({
				Size = UDim2.fromOffset(124, 38),
				Text = mineral.Name,
				Color = Config.GetRarityColor(mineral.Id),
				TextColor = TEXT,
				OnClick = function()
					send("GiveMineral", target(), mineral.Id)
				end,
			})
		)
	end

	local upgradeRows = {}
	for _, kind in Config.UpgradeOrder do
		table.insert(
			upgradeRows,
			scope:New "TextLabel" {
				Size = UDim2.fromOffset(86, 32),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 14,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Config.Upgrades[kind].Label,
			}
		)
		for _, option in { { "-1", -1 }, { "+1", 1 }, { "+5", 5 }, { "Máx", 100 }, { "0", -100 } } do
			table.insert(
				upgradeRows,
				Button({
					Size = UDim2.fromOffset(50, 32),
					Text = option[1],
					Color = if option[2] < 0 then RED else PURPLE,
					OnClick = function()
						send("AdjustUpgrade", target(), kind, option[2])
					end,
				})
			)
		end
	end

	local zoneButtons = {}
	for zone = 1, Config.ZoneCount do
		table.insert(
			zoneButtons,
			Button({
				Size = UDim2.fromOffset(70, 32),
				Text = "Zona " .. zone,
				OnClick = function()
					send("Teleport", target(), zone)
				end,
			})
		)
	end

	local scroll = scope:New "ScrollingFrame" {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		[Children] = {
			scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) },
			scope:New "UIPadding" {
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
			},
			Section(1, "Jugador", Wrap(targetButtons)),
			Section(2, "Dinero", scope:New "Frame" {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) },
					(function()
						amountBox.LayoutOrder = 1
						return amountBox
					end)(),
					(function()
						local frame = Wrap(moneyButtons)
						frame.LayoutOrder = 2
						return frame
					end)(),
					(function()
						local frame = Wrap(quickAmounts)
						frame.LayoutOrder = 3
						return frame
					end)(),
				},
			}),
			Section(3, "Dar un mineral", Wrap(mineralButtons)),
			Section(4, "Mejoras (nivel)", Wrap(upgradeRows)),
			Section(5, "Ir a la zona", Wrap(zoneButtons)),
			Section(6, "Pisos de la fábrica", Wrap({
				Button({ Size = UDim2.fromOffset(92, 34), Text = "+1 piso", OnClick = function() send("SetFloors", target(), 1) end }),
				Button({ Size = UDim2.fromOffset(92, 34), Text = "-1 piso", Color = RED, OnClick = function() send("SetFloors", target(), -1) end }),
				Button({ Size = UDim2.fromOffset(130, 34), Text = "Todo abierto", Color = GREEN, OnClick = function() send("SetFloors", target(), "all") end }),
				Button({ Size = UDim2.fromOffset(110, 34), Text = "Solo 1 piso", Color = RED, OnClick = function() send("SetFloors", target(), "reset") end }),
			})),
			Section(7, "Renacimientos", Wrap({
				Button({ Size = UDim2.fromOffset(92, 34), Text = "+1", OnClick = function() send("AdjustRebirths", target(), 1) end }),
				Button({ Size = UDim2.fromOffset(92, 34), Text = "-1", Color = RED, OnClick = function() send("AdjustRebirths", target(), -1) end }),
				Button({ Size = UDim2.fromOffset(92, 34), Text = "Máx", Color = GREEN, OnClick = function() send("AdjustRebirths", target(), 100) end }),
				Button({ Size = UDim2.fromOffset(92, 34), Text = "A 0", Color = RED, OnClick = function() send("AdjustRebirths", target(), -100) end }),
				Button({ Size = UDim2.fromOffset(190, 34), Text = "Reiniciar máx. de ingreso", Color = RED, OnClick = function() send("ResetPeak", target()) end }),
			})),
			Section(8, "Robux (prueba sin pagar)", Wrap({
				Button({ Size = UDim2.fromOffset(100, 34), Text = "x2 dinero: sí", OnClick = function() send("GrantRobux", target(), "X2", true) end }),
				Button({ Size = UDim2.fromOffset(100, 34), Text = "x2 dinero: no", Color = RED, OnClick = function() send("GrantRobux", target(), "X2", false) end }),
				Button({ Size = UDim2.fromOffset(100, 34), Text = "Botas: sí", OnClick = function() send("GrantRobux", target(), "Boots", true) end }),
				Button({ Size = UDim2.fromOffset(100, 34), Text = "Botas: no", Color = RED, OnClick = function() send("GrantRobux", target(), "Boots", false) end }),
				Button({ Size = UDim2.fromOffset(100, 34), Text = "+1 escudo", Color = GREEN, OnClick = function() send("GrantRobux", target(), "Shield") end }),
				Button({ Size = UDim2.fromOffset(120, 34), Text = "Paquete de dinero", Color = GREEN, OnClick = function() send("GrantRobux", target(), "Credits") end }),
			})),
			Section(9, "Estantes", Wrap({
				Button({
					Size = UDim2.fromOffset(190, 34),
					Text = "Informe de mis estantes",
					OnClick = function()
						send("Report", target())
					end,
				}),
			})),
		},
	}

	local header = scope:New "Frame" {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New "TextLabel" {
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -60, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 18,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Panel de administrador",
			},
			Button({
				Size = UDim2.fromOffset(32, 28),
				Text = "X",
				Color = RED,
				OnClick = function()
					ui.adminOpen:set(false)
				end,
			}),
		},
	}
	-- El botón de cerrar va a la derecha del encabezado.
	local closeButton = header:FindFirstChildWhichIsA("TextButton")
	if closeButton then
		closeButton.AnchorPoint = Vector2.new(1, 0.5)
		closeButton.Position = UDim2.new(1, -10, 0.5, 0)
	end

	local panel = scope:New "Frame" {
		Name = "AdminPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 40),
		Size = UDim2.fromOffset(420, 520),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.isAdmin) and use(ui.adminOpen)
		end),

		[Children] = {
			rounded(16),
			scope:New "UIStroke" { Color = BORDER, Thickness = 3 },
			header,
			scroll,
		},
	}

	local openButton = Button({
		Size = UDim2.fromOffset(84, 32),
		Text = "ADMIN",
		Visible = ui.isAdmin,
		OnClick = function()
			ui.adminOpen:set(not peek(ui.adminOpen))
		end,
	})
	openButton.Position = UDim2.fromOffset(20, 70)

	scope:New "ScreenGui" {
		Name = "NeoLunaAdmin",
		ResetOnSpawn = false,
		Parent = parent,
		[Children] = { panel, openButton },
	}

	return scope
end

return AdminPanel
