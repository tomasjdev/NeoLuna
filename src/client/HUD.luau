-- HUD holográfico (estilo C): panel translúcido con esquinas marcadas.
-- Construido con Fusion: todo se actualiza solo cuando cambia `state`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local CYAN = Color3.fromRGB(0, 240, 208)
local MAGENTA = Color3.fromRGB(255, 43, 214)
local DIM = Color3.fromRGB(111, 122, 154)
local DARK = Color3.fromRGB(8, 14, 24)
local FONT = Enum.Font.RobotoMono

local function hex(color)
	local function byte(x)
		return math.floor(x * 255 + 0.5)
	end
	return ("#%02x%02x%02x"):format(byte(color.R), byte(color.G), byte(color.B))
end

local function formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local HUD = {}

-- state: Value con { Credits, Drones, Capacity, Speed }
-- toastText: Value con texto del aviso ("" = oculto)
-- onBuy: function(kind)
function HUD.mount(parent, state, toastText, onBuy)
	local scope = Fusion.scoped(Fusion)

	-- Créditos con conteo suave hacia el valor real
	local creditsTarget = scope:Computed(function(use)
		return use(state).Credits
	end)
	local creditsSmooth = scope:Spring(creditsTarget, 30, 1)
	local creditsText = scope:Computed(function(use)
		return formatNumber(use(creditsSmooth))
	end)

	local function Row(kind)
		local cost = scope:Computed(function(use)
			return Config.GetCost(kind, use(state))
		end)
		local affordable = scope:Computed(function(use)
			return use(state).Credits >= use(cost)
		end)
		local level = scope:Computed(function(use)
			local s = use(state)
			return if kind == "Drone" then s.Drones else s[kind] + 1
		end)

		local hovered = scope:Value(false)
		local flash = scope:Value(false)

		local fill = scope:Tween(
			scope:Computed(function(use)
				if use(flash) then
					return 0.55
				elseif use(hovered) and use(affordable) then
					return 0.85
				end
				return 1
			end),
			TweenInfo.new(0.12)
		)
		local textFade = scope:Tween(
			scope:Computed(function(use)
				return if use(affordable) then 0 else 0.55
			end),
			TweenInfo.new(0.2)
		)

		local labels = {
			Drone = "Drones",
			Capacity = "Capacidad",
			Speed = "Velocidad",
		}

		return scope:New "TextButton" {
			Name = kind,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = MAGENTA,
			BackgroundTransparency = fill,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",

			[OnEvent "MouseEnter"] = function()
				hovered:set(true)
			end,
			[OnEvent "MouseLeave"] = function()
				hovered:set(false)
			end,
			[OnEvent "Activated"] = function()
				if peek(affordable) then
					flash:set(true)
					task.delay(0.15, function()
						flash:set(false)
					end)
				end
				onBuy(kind)
			end,

			[Children] = {
				scope:New "TextLabel" {
					Name = "Name",
					Size = UDim2.fromScale(0.62, 1),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 14,
					TextColor3 = Color3.new(1, 1, 1),
					TextTransparency = textFade,
					TextXAlignment = Enum.TextXAlignment.Left,
					RichText = true,
					Text = scope:Computed(function(use)
						return ("%s <font color=\"%s\">%s%d</font>"):format(
							labels[kind],
							hex(MAGENTA),
							kind == "Drone" and "x" or "Nv",
							use(level)
						)
					end),
				},
				scope:New "TextLabel" {
					Name = "Cost",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.38, 1),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 14,
					TextColor3 = CYAN,
					TextTransparency = textFade,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = scope:Computed(function(use)
						return "+ " .. formatNumber(use(cost))
					end),
				},
				scope:New "Frame" { -- línea inferior
					Name = "Divider",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = CYAN,
					BackgroundTransparency = 0.75,
					BorderSizePixel = 0,
				},
			},
		}
	end

	local function Bracket(corner)
		-- corner: "TL" (arriba-izquierda) o "BR" (abajo-derecha)
		local anchor = if corner == "TL" then Vector2.new(0, 0) else Vector2.new(1, 1)
		local position = if corner == "TL" then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 1)
		local function bar(size, name)
			return scope:New "Frame" {
				Name = name,
				AnchorPoint = anchor,
				Position = position,
				Size = size,
				BackgroundColor3 = CYAN,
				BorderSizePixel = 0,
			}
		end
		return {
			bar(UDim2.fromOffset(14, 2), corner .. "H"),
			bar(UDim2.fromOffset(2, 14), corner .. "V"),
		}
	end

	local panel = scope:New "Frame" {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1), -- el color real lo da el degradado
		BackgroundTransparency = 0, -- opaco: el texto siempre se lee
		BorderSizePixel = 0,

		[Children] = {
			scope:New "UIGradient" {
				Color = ColorSequence.new(Color3.fromRGB(8, 22, 34), Color3.fromRGB(26, 10, 40)),
				Rotation = 45,
			},
			scope:New "Frame" {
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,

				[Children] = {
					scope:New "UIPadding" {
						PaddingTop = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 12),
						PaddingLeft = UDim.new(0, 14),
						PaddingRight = UDim.new(0, 14),
					},
					scope:New "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					},
					scope:New "TextLabel" {
						Name = "Caption",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						Font = FONT,
						TextSize = 11,
						TextColor3 = DIM,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "C R É D I T O S",
					},
					scope:New "TextLabel" {
						Name = "Credits",
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						Font = FONT,
						TextSize = 28,
						TextColor3 = Color3.new(1, 1, 1),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = creditsText,

						[Children] = scope:New "UIStroke" {
							Color = CYAN,
							Transparency = 0.6,
							Thickness = 1.2,
						},
					},
					scope:New "Frame" { -- espacio antes de las filas
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 4),
						BackgroundTransparency = 1,
					},
					(function()
						local row = Row("Drone")
						row.LayoutOrder = 4
						return row
					end)(),
					(function()
						local row = Row("Capacity")
						row.LayoutOrder = 5
						return row
					end)(),
					(function()
						local row = Row("Speed")
						row.LayoutOrder = 6
						return row
					end)(),
				},
			},
			Bracket("TL"),
			Bracket("BR"),
		},
	}

	-- Aviso de ganancias offline
	local toastFade = scope:Tween(
		scope:Computed(function(use)
			return if use(toastText) == "" then 1 else 0
		end),
		TweenInfo.new(0.3)
	)
	local toast = scope:New "TextLabel" {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = DARK,
		BackgroundTransparency = scope:Computed(function(use)
			return use(toastFade) -- opaco mientras se ve, se desvanece al ocultarse
		end),
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 16,
		TextColor3 = CYAN,
		TextTransparency = toastFade,
		Text = toastText,

		[Children] = scope:New "UIStroke" {
			Color = CYAN,
			Transparency = scope:Computed(function(use)
				return 0.4 + 0.6 * use(toastFade)
			end),
			Thickness = 1,
		},
	}

	scope:New "ScreenGui" {
		Name = "NeoLunaHUD",
		ResetOnSpawn = false,
		Parent = parent,
		[Children] = { panel, toast },
	}

	return scope
end

return HUD
