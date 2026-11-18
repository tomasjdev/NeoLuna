-- HUD colorido y redondeado, construido con Fusion: dinero, profundidad, barra de
-- 5 espacios, mochila de 10, tienda (mejoras y venta) y avisos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local WHITE = Color3.new(1, 1, 1)
local TEXT = Color3.fromRGB(70, 50, 120)
local DIM = Color3.fromRGB(135, 120, 175)
local BORDER = Color3.fromRGB(190, 165, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local HELD_COLOR = Color3.fromRGB(255, 120, 0) -- contorno del mineral que llevas en la mano
local EMPTY_SLOT = Color3.fromRGB(236, 230, 248)
local DISABLED = Color3.fromRGB(140, 132, 172) -- botones apagados: se lee el texto blanco
local FONT = Enum.Font.FredokaOne

local ROW_COLORS = {
	Speed = Color3.fromRGB(255, 150, 70),
	Strength = Color3.fromRGB(45, 190, 180),
	Pickaxe = Color3.fromRGB(150, 110, 255),
	Capacity = Color3.fromRGB(215, 95, 205),
}

-- Qué rareza desbloquea el pico en cierto nivel (o nil).
local function unlockedRarity(pickaxeLevel)
	for _, rarity in Config.Rarities do
		if rarity.RequiredPickaxe == pickaxeLevel then
			return rarity.Name
		end
	end
	return nil
end

local HUD = {}

-- ui = { state, carry, notice, shopKind, robuxKind, backpackOpen, selected, held, depth }
-- (Values de Fusion). handlers = { onUpgrade(kind), onSell(index), onSelectSlot(slot) }
function HUD.mount(parent, ui, handlers)
	local scope = Fusion.scoped(Fusion)

	local function rounded(radius)
		return scope:New "UICorner" { CornerRadius = UDim.new(0, radius) }
	end

	local function closeAll()
		ui.shopKind:set("")
		ui.robuxKind:set("")
		ui.fuseOpen:set(false)
		ui.rebirthOpen:set(false)
		ui.giftPicking:set(false)
		ui.backpackOpen:set(false)
	end

	local function mineralInfo(use, index)
		local id = use(ui.state).Inventory[index]
		return id and Config.MineralsById[id] or nil
	end

	-- Un espacio de la mochila. `mode`: "hotbar" (barra de 5: elige qué mineral llevas en la
	-- mano) o "grid" (panel de la mochila: elige cuál ver o vender).
	local function Slot(index, mode)
		local selection = if mode == "hotbar" then ui.held else ui.selected
		local mineral = scope:Computed(function(use)
			return mineralInfo(use, index) or false
		end)
		local isSelected = scope:Computed(function(use)
			return use(selection) == index
		end)
		-- El mineral que llevas en la mano se marca igual en la barra y en la mochila.
		local isHeld = scope:Computed(function(use)
			return use(ui.held) == index
		end)
		local scale = scope:Spring(
			scope:Computed(function(use)
				return if use(isHeld) then 1.12 else 1
			end),
			40,
			0.7
		)

		return scope:New "TextButton" {
			Name = "Slot" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = scope:Computed(function(use)
				local m = use(mineral)
				return if m then Config.GetMineralColor(m.Id) else EMPTY_SLOT
			end),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",

			[OnEvent "Activated"] = function()
				if mode == "hotbar" then
					handlers.onSelectSlot(index)
				else
					ui.selected:set(index)
				end
			end,

			[Children] = {
				rounded(14),
				-- Número del espacio (arriba a la derecha): la tecla con la que se elige.
				scope:New "TextLabel" {
					Name = "Number",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -2, 0, 2),
					Size = UDim2.fromOffset(18, 16),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 14,
					TextColor3 = WHITE,
					TextStrokeTransparency = 0.3,
					TextStrokeColor3 = Color3.fromRGB(40, 30, 80),
					ZIndex = 3,
					Text = tostring(index),
				},
				scope:New "UIScale" { Scale = scale },
				scope:New "UIStroke" {
					Color = scope:Computed(function(use)
						if use(isHeld) then
							return HELD_COLOR
						end
						return if use(isSelected) then TEXT else BORDER
					end),
					Thickness = scope:Computed(function(use)
						if use(isHeld) then
							return 5
						end
						return if use(isSelected) then 4 else 2
					end),
				},
				scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				},
				scope:New "TextLabel" {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 12,
					TextWrapped = true,
					-- Texto oscuro sobre colores claros y blanco sobre colores oscuros.
					TextColor3 = scope:Computed(function(use)
						local m = use(mineral)
						if not m then
							return TEXT
						end
						local c = Config.GetMineralColor(m.Id)
						return if (c.R * 0.299 + c.G * 0.587 + c.B * 0.114) < 0.55 then WHITE else TEXT
					end),
					Text = scope:Computed(function(use)
						local m = use(mineral)
						return if m then m.Name else ""
					end),
				},
			},
		}
	end

	----------------------------------------------------------------------
	-- Dinero (arriba a la derecha)
	----------------------------------------------------------------------

	local moneySmooth = scope:Spring(
		scope:Computed(function(use)
			return use(ui.state).Money
		end),
		30,
		1
	)

	local moneyPanel = scope:New "Frame" {
		Name = "Money",
		AnchorPoint = Vector2.new(1, 0),
		Position = if game:GetService("UserInputService").TouchEnabled then UDim2.new(1, -8, 0, 4) else UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(250, 50),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,

		[Children] = {
			-- En celular el dinero es más pequeño y va pegado arriba a la derecha.
			scope:New "UIScale" { Scale = if game:GetService("UserInputService").TouchEnabled then 0.72 else 1 },
			rounded(16),
			scope:New "UIStroke" { Color = BORDER, Thickness = 3 },
			scope:New "Frame" {
				Name = "Coin",
				Position = UDim2.fromOffset(10, 9),
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				[Children] = {
					scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
					scope:New "UIStroke" { Color = Color3.fromRGB(235, 160, 20), Thickness = 3 },
				},
			},
			scope:New "TextLabel" {
				Position = UDim2.fromOffset(50, 0),
				Size = UDim2.new(1, -58, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 26,
				TextScaled = true,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					return Config.FormatMoney(use(moneySmooth))
				end),
				[Children] = scope:New "UITextSizeConstraint" { MaxTextSize = 26 },
			},
		},
	}

	----------------------------------------------------------------------
	-- Estado (arriba al centro): solo la zona
	----------------------------------------------------------------------

	-- Letrero de la zona: una cápsula con el número en el color de la zona, "MINA LUNAR" pequeño
	-- y el nombre grande. Solo dentro de la mina. En celular se agranda.
	local zoneIndex = scope:Computed(function(use)
		return Config.GetZone(use(ui.depth))
	end)
	local touchScale = if game:GetService("UserInputService").TouchEnabled then 0.72 else 1

	local statusPanel = scope:New "Frame" {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if touchScale < 1 then 4 else 16),
		Size = UDim2.fromOffset(400, 66),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.depth) > 0
		end),

		[Children] = {
			rounded(33),
			scope:New "UIScale" { Scale = touchScale },
			scope:New "UIStroke" {
				Color = scope:Computed(function(use)
					return Config.Zones[use(zoneIndex)].GemColor
				end),
				Thickness = 4,
			},
			-- Número de la zona
			scope:New "Frame" {
				Position = UDim2.fromOffset(9, 9),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = scope:Computed(function(use)
					return Config.Zones[use(zoneIndex)].GemColor
				end),
				BorderSizePixel = 0,
				[Children] = {
					scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
					scope:New "TextLabel" {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Font = FONT,
						TextSize = 26,
						TextColor3 = WHITE,
						TextStrokeColor3 = Color3.fromRGB(60, 40, 110),
						TextStrokeTransparency = 0.3,
						Text = scope:Computed(function(use)
							return tostring(use(zoneIndex))
						end),
					},
				},
			},
			scope:New "TextLabel" {
				Position = UDim2.fromOffset(70, 8),
				Size = UDim2.new(1, -84, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = DIM,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "MINA LUNAR",
			},
			scope:New "TextLabel" {
				Position = UDim2.fromOffset(70, 22),
				Size = UDim2.new(1, -84, 0, 36),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 30,
				TextScaled = true,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					return Config.Zones[use(zoneIndex)].Name
				end),
				[Children] = scope:New "UITextSizeConstraint" { MaxTextSize = 30 },
			},
		},
	}

	-- Avisos
	local noticeFade = scope:Tween(
		scope:Computed(function(use)
			return if use(ui.notice) == "" then 1 else 0
		end),
		TweenInfo.new(0.3)
	)
	local noticePanel = scope:New "TextLabel" {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100), -- debajo del letrero de la zona
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = noticeFade,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = TEXT,
		TextTransparency = noticeFade,
		Text = ui.notice,

		[Children] = {
			rounded(14),
			scope:New "UIStroke" { Color = BORDER, Thickness = 3, Transparency = noticeFade },
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 9),
				PaddingBottom = UDim.new(0, 9),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
		},
	}

	----------------------------------------------------------------------
	-- Barra de 5 espacios + botón de mochila (abajo al centro)
	----------------------------------------------------------------------

	local hotbarChildren = {
		scope:New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
	}
	for index = 1, Config.HotbarSize do
		table.insert(hotbarChildren, Slot(index, "hotbar"))
	end
	table.insert(
		hotbarChildren,
		scope:New "TextButton" {
			Name = "BackpackButton",
			LayoutOrder = 100,
			Size = UDim2.fromOffset(92, 64),
			BackgroundColor3 = Color3.fromRGB(150, 110, 255),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = FONT,
			TextSize = 16,
			TextColor3 = WHITE,
			Text = scope:Computed(function(use)
				return ("Mochila\n%d/%d"):format(#use(ui.state).Inventory, Config.InventorySize)
			end),

			[OnEvent "Activated"] = function()
				ui.backpackOpen:set(not peek(ui.backpackOpen))
			end,

			[Children] = { rounded(14) },
		}
	)

	local hotbar = scope:New "Frame" {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		[Children] = hotbarChildren,
	}

	----------------------------------------------------------------------
	-- Mochila (los 10 espacios) con detalle y botón de vender en la tienda
	----------------------------------------------------------------------

	local gridChildren = {
		scope:New "UIGridLayout" {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = Config.HotbarSize,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
	}
	for index = 1, Config.InventorySize do
		table.insert(gridChildren, Slot(index, "grid"))
	end

	local selectedMineral = scope:Computed(function(use)
		return mineralInfo(use, use(ui.selected)) or false
	end)

	local canSell = scope:Computed(function(use)
		return use(ui.shopKind) == "Sell" and use(selectedMineral) ~= false
	end)

	local backpackPanel = scope:New "Frame" {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.backpackOpen) or use(ui.shopKind) == "Sell"
		end),

		[Children] = {
			rounded(20),
			scope:New "UIStroke" { Color = BORDER, Thickness = 4 },
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			scope:New "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			},
			scope:New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(376, 24),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 22,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Mi mochila",
			},
			scope:New "Frame" {
				Name = "Grid",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(376, 136),
				BackgroundTransparency = 1,
				[Children] = gridChildren,
			},
			scope:New "TextLabel" {
				Name = "Detail",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(376, 40),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 15,
				TextWrapped = true,
				TextColor3 = DIM,
				Text = scope:Computed(function(use)
					local m = use(selectedMineral)
					if not m then
						return "Toca un mineral para ver sus datos."
					end
					return ("%s · %s · %s · Vale %s"):format(
						m.Name,
						Config.RaritiesById[m.Rarity].Name,
						m.Family,
						Config.FormatMoney(m.Value * Config.GetMoneyMultiplier(use(ui.state)))
					)
				end),
			},
			scope:New "TextButton" {
				Name = "SellButton",
				LayoutOrder = 4,
				Size = UDim2.fromOffset(376, 44),
				BackgroundColor3 = Color3.fromRGB(45, 190, 180),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 20,
				TextColor3 = WHITE,
				Visible = canSell,
				Text = scope:Computed(function(use)
					local m = use(selectedMineral)
					return if m then ("Vender por %s"):format(Config.FormatMoney(m.Value * Config.GetMoneyMultiplier(use(ui.state)))) else ""
				end),

				[OnEvent "Activated"] = function()
					local index = peek(ui.selected)
					if peek(canSell) then
						handlers.onSell(index)
						ui.selected:set(0)
					end
				end,

				[Children] = { rounded(14) },
			},
			scope:New "TextButton" {
				Name = "SellAllButton",
				LayoutOrder = 5,
				Size = UDim2.fromOffset(376, 44),
				BackgroundColor3 = Color3.fromRGB(235, 150, 40),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 20,
				TextColor3 = WHITE,
				-- Solo en la tienda de vender y si hay algo en la mochila.
				Visible = scope:Computed(function(use)
					return use(ui.shopKind) == "Sell" and #use(ui.state).Inventory > 0
				end),
				Text = scope:Computed(function(use)
					local state = use(ui.state)
					local total = 0
					for _, id in state.Inventory do
						local mineral = Config.MineralsById[id]
						total += (mineral and mineral.Value or 0) * Config.GetMoneyMultiplier(state)
					end
					return ("Vender todo por %s"):format(Config.FormatMoney(total))
				end),
				[OnEvent "Activated"] = function()
					handlers.onSellAll()
					ui.selected:set(0)
				end,
				[Children] = { rounded(14) },
			},
			scope:New "TextButton" {
				Name = "CloseButton",
				LayoutOrder = 6,
				Size = UDim2.fromOffset(376, 36),
				BackgroundColor3 = DISABLED,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 18,
				TextColor3 = WHITE,
				Text = "Cerrar",
				[OnEvent "Activated"] = closeAll,
				[Children] = { rounded(14) },
			},
		},
	}

	----------------------------------------------------------------------
	-- Tienda: mejoras
	----------------------------------------------------------------------

	local function UpgradeRow(kind, layoutOrder)
		local upgrade = Config.Upgrades[kind]
		local level = scope:Computed(function(use)
			return use(ui.state)[kind]
		end)
		local maxed = scope:Computed(function(use)
			return use(level) >= upgrade.MaxLevel
		end)
		local cost = scope:Computed(function(use)
			return Config.GetUpgradeCost(kind, use(level))
		end)
		local affordable = scope:Computed(function(use)
			return not use(maxed) and use(ui.state).Money >= use(cost)
		end)
		local detail = scope:Computed(function(use)
			local l = use(level)
			if use(maxed) then
				return "¡Nivel máximo!"
			elseif kind == "Speed" then
				return ("Correr: %.1f → %.1f"):format(Config.GetWalkSpeed(l), Config.GetWalkSpeed(l + 1))
			elseif kind == "Capacity" then
				return ("Minerales por viaje: %d → %d"):format(Config.GetCarryCapacity(l), Config.GetCarryCapacity(l + 1))
			elseif kind == "Strength" then
				return ("Tiempo de picado: %d%% → %d%%"):format(
					math.floor(Config.GetStrengthFactor(l) * 100 + 0.5),
					math.floor(Config.GetStrengthFactor(l + 1) * 100 + 0.5)
				)
			end
			local unlock = unlockedRarity(l + 1)
			return if unlock then ("Pica minerales %s más rápido"):format(unlock) else "Pico más resistente"
		end)

		local fill = scope:Tween(
			scope:Computed(function(use)
				return if use(affordable) then ROW_COLORS[kind] else ROW_COLORS[kind]:Lerp(Color3.fromRGB(75, 65, 110), 0.62)
			end),
			TweenInfo.new(0.2)
		)

		return scope:New "TextButton" {
			Name = kind,
			LayoutOrder = layoutOrder,
			Visible = scope:Computed(function(use)
				return use(ui.shopKind) == kind
			end),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",

			[OnEvent "Activated"] = function()
				if peek(affordable) then
					handlers.onUpgrade(kind)
				end
			end,

			[Children] = {
				rounded(14),
				scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				},
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.new(0.62, 0, 0, 22),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 18,
					TextColor3 = WHITE,
					TextStrokeColor3 = Color3.fromRGB(40, 25, 80),
					TextStrokeTransparency = 0.5,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = scope:Computed(function(use)
						return ("%s  Nv %d"):format(upgrade.Label, use(level))
					end),
				},
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(0.7, 0, 0, 18),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = WHITE,
					TextStrokeColor3 = Color3.fromRGB(40, 25, 80),
					TextStrokeTransparency = 0.6,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = detail,
				},
				scope:New "TextLabel" {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.38, 1),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 19,
					TextScaled = true,
					TextColor3 = WHITE,
					TextStrokeColor3 = Color3.fromRGB(40, 25, 80),
					TextStrokeTransparency = 0.45,
					TextXAlignment = Enum.TextXAlignment.Right,
					[Children] = scope:New "UITextSizeConstraint" { MaxTextSize = 19 },
					Text = scope:Computed(function(use)
						if use(maxed) then
							return "MÁX"
						end
						return Config.FormatMoney(use(cost))
					end),
				},
			},
		}
	end

	local shopPanel = scope:New "Frame" {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			local kind = use(ui.shopKind)
			return kind ~= "" and kind ~= "Sell"
		end),

		[Children] = {
			rounded(20),
			scope:New "UIStroke" {
				Color = scope:Computed(function(use)
					return ROW_COLORS[use(ui.shopKind)] or BORDER
				end),
				Thickness = 5,
			},
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			scope:New "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			},
			scope:New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 24,
				TextColor3 = scope:Computed(function(use)
					return (ROW_COLORS[use(ui.shopKind)] or TEXT):Lerp(Color3.fromRGB(50, 35, 100), 0.35)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local upgrade = Config.Upgrades[use(ui.shopKind)]
					return if upgrade then upgrade.Label else ""
				end),
			},
			scope:New "TextLabel" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = DIM,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local kind = use(ui.shopKind)
					if kind == "Speed" then
						return "Corre más rápido para escapar del Alien."
					elseif kind == "Strength" then
						return "Pica los minerales en menos tiempo."
					elseif kind == "Pickaxe" then
						return "Con un pico mejor, los minerales raros se pican más rápido."
					elseif kind == "Capacity" then
						return "Lleva más minerales por viaje. Cada uno extra te frena un poco."
					end
					return ""
				end),
			},
			UpgradeRow("Speed", 3),
			UpgradeRow("Strength", 4),
			UpgradeRow("Pickaxe", 5),
			UpgradeRow("Capacity", 6),
		},
	}

	----------------------------------------------------------------------
	-- Tiendas de Robux (por ahora informativas: falta crear los pases y productos en Roblox)
	----------------------------------------------------------------------

	local robuxPanel = scope:New "Frame" {
		Name = "RobuxShop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.robuxKind) ~= ""
		end),

		[Children] = {
			rounded(20),
			scope:New "UIStroke" { Color = Color3.fromRGB(70, 190, 110), Thickness = 4 },
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			scope:New "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			},
			scope:New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 22,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local product = Config.RobuxProducts[use(ui.robuxKind)]
					return if product then product.Name else ""
				end),
			},
			scope:New "TextLabel" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 15,
				TextWrapped = true,
				TextColor3 = DIM,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local product = Config.RobuxProducts[use(ui.robuxKind)]
					if not product then
						return ""
					end
					local state = use(ui.state)
					local extra = ""
					if product.Id == 0 then
						extra = "\n\n¡Muy pronto!"
					elseif product.Kind == "Pass" and state.Passes[use(ui.robuxKind)] then
						extra = "\n\n¡Ya lo tienes!"
					elseif use(ui.robuxKind) == "Shield" then
						extra = ("\n\nEscudos que tienes: %d"):format(state.Shields or 0)
					end
					return product.Description .. extra
				end),
			},
			scope:New "TextButton" {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Color3.fromRGB(70, 190, 110),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 19,
				TextColor3 = WHITE,
				Text = "Comprar con Robux",
				-- Solo si el producto ya existe en Roblox (Id distinto de 0) y no tienes ya el pase.
				Visible = scope:Computed(function(use)
					local kind = use(ui.robuxKind)
					local product = Config.RobuxProducts[kind]
					if not product or product.Id == 0 then
						return false
					end
					return not (product.Kind == "Pass" and use(ui.state).Passes[kind])
				end),
				[OnEvent "Activated"] = function()
					handlers.onBuyRobux(peek(ui.robuxKind))
				end,
				[Children] = { rounded(14) },
			},
			scope:New "TextButton" {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = DISABLED,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 18,
				TextColor3 = WHITE,
				Text = "Cerrar",
				[OnEvent "Activated"] = closeAll,
				[Children] = { rounded(14) },
			},
		},
	}

	----------------------------------------------------------------------
	-- Horno de fusion: 3 minerales de la misma rareza (Raro o superior) -> 1 de la siguiente
	----------------------------------------------------------------------

	local function FuseRow(rarity, layoutOrder)
		local target = Config.GetFusionTarget(rarity.Id)
		local owned = scope:Computed(function(use)
			local count = 0
			for _, id in use(ui.state).Inventory do
				local mineral = Config.MineralsById[id]
				if mineral and mineral.Rarity == rarity.Id then
					count += 1
				end
			end
			return count
		end)
		local ready = scope:Computed(function(use)
			return use(owned) >= Config.FusionCount
		end)
		return scope:New "Frame" {
			LayoutOrder = layoutOrder,
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = EMPTY_SLOT,
			BorderSizePixel = 0,
			[Children] = {
				rounded(12),
				scope:New "Frame" {
					Position = UDim2.fromOffset(8, 11),
					Size = UDim2.fromOffset(32, 32),
					BackgroundColor3 = rarity.Color,
					BorderSizePixel = 0,
					[Children] = { rounded(8) },
				},
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(48, 4),
					Size = UDim2.new(1, -150, 1, -8),
					BackgroundTransparency = 1,
					Font = FONT,
					TextSize = 14,
					TextWrapped = true,
					TextColor3 = TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = scope:Computed(function(use)
						return ("%d %s → 1 %s\nTienes %d"):format(Config.FusionCount, rarity.Name, target.Name, use(owned))
					end),
				},
				scope:New "TextButton" {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(84, 34),
					BackgroundColor3 = scope:Computed(function(use)
						return if use(ready) then Color3.fromRGB(255, 140, 60) else DISABLED
					end),
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Font = FONT,
					TextSize = 16,
					TextColor3 = WHITE,
					Text = "Fusionar",
					[OnEvent "Activated"] = function()
						if peek(ready) then
							handlers.onFuse(rarity.Id)
						end
					end,
					[Children] = { rounded(10) },
				},
			},
		}
	end

	local fuseChildren = {
		rounded(20),
		scope:New "UIStroke" { Color = Color3.fromRGB(255, 140, 60), Thickness = 4 },
		scope:New "UIPadding" {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		},
		scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) },
		scope:New "TextLabel" {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 22,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Horno de fusión",
		},
		scope:New "TextLabel" {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Junta 3 minerales de la misma rareza (Raro o superior) y obtén uno de la rareza siguiente.",
		},
	}
	local fuseOrder = 3
	for _, rarity in Config.Rarities do
		if Config.GetFusionTarget(rarity.Id) then
			table.insert(fuseChildren, FuseRow(rarity, fuseOrder))
			fuseOrder += 1
		end
	end
	table.insert(fuseChildren, scope:New "TextButton" {
		LayoutOrder = fuseOrder,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = DISABLED,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT,
		TextSize = 18,
		TextColor3 = WHITE,
		Text = "Cerrar",
		[OnEvent "Activated"] = closeAll,
		[Children] = { rounded(14) },
	})

	local fusePanel = scope:New "Frame" {
		Name = "Fusion",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = ui.fuseOpen,
		[Children] = fuseChildren,
	}

	----------------------------------------------------------------------
	-- Altar de renacimiento: solo se pierde el dinero
	----------------------------------------------------------------------

	local REBIRTH_COLOR = Color3.fromRGB(150, 110, 230)
	local rebirthDone = scope:Computed(function(use)
		return use(ui.state).Rebirths or 0
	end)
	local rebirthCost = scope:Computed(function(use)
		return Config.GetRebirthCost(use(ui.state))
	end)
	local canRebirth = scope:Computed(function(use)
		local cost = use(rebirthCost)
		return cost ~= nil and use(ui.state).Money >= cost
	end)

	local function RebirthLine(order, textFn)
		return scope:New "TextLabel" {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextWrapped = true,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = scope:Computed(textFn),
		}
	end

	local rebirthPanel = scope:New "Frame" {
		Name = "Rebirth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = ui.rebirthOpen,
		[Children] = {
			rounded(20),
			scope:New "UIStroke" { Color = REBIRTH_COLOR, Thickness = 4 },
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) },
			scope:New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 22,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Renacimiento",
			},
			scope:New "TextLabel" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = DIM,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Pierdes solo tu dinero. Conservas tus mejoras, minerales, pisos y estantes, y tus estantes generan más para siempre.",
			},
			RebirthLine(3, function(use)
				return ("Renacimientos: %d de %d"):format(use(rebirthDone), Config.Rebirth.Max)
			end),
			RebirthLine(4, function(use)
				local done = use(rebirthDone)
				if done >= Config.Rebirth.Max then
					return ("Ganancia de tus estantes: x%s (máximo)"):format(tostring(Config.GetRebirthMultiplier(done)))
				end
				return ("Ganancia de tus estantes: x%s → x%s"):format(tostring(Config.GetRebirthMultiplier(done)), tostring(Config.GetRebirthMultiplier(done + 1)))
			end),
			RebirthLine(5, function(use)
				local cost = use(rebirthCost)
				return if cost then ("Costo: %s"):format(Config.FormatMoney(cost)) else "¡Lo lograste todo!"
			end),
			scope:New "TextButton" {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(canRebirth) then REBIRTH_COLOR else DISABLED
				end),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 20,
				TextColor3 = WHITE,
				Text = "Renacer",
				[OnEvent "Activated"] = function()
					if peek(canRebirth) then
						handlers.onRebirth()
					end
				end,
				[Children] = { rounded(14) },
			},
			scope:New "TextButton" {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = DISABLED,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 18,
				TextColor3 = WHITE,
				Text = "Cerrar",
				[OnEvent "Activated"] = closeAll,
				[Children] = { rounded(14) },
			},
		},
	}

	----------------------------------------------------------------------
	-- Regalos: la oferta que te hacen (se regala acercándote a otro jugador con un mineral en la mano)
	----------------------------------------------------------------------

	local GIFT_COLOR = Color3.fromRGB(235, 100, 150)
	local GREEN_BUTTON = Color3.fromRGB(45, 175, 110)
	-- Oferta que te hacen: aceptar o rechazar.
	local giftOfferPanel = scope:New "Frame" {
		Name = "GiftOffer",
		-- A la derecha, bajo el dinero: así no se encima con la columna de avisos del centro.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 190),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.giftOffer) ~= false
		end),
		[Children] = {
			rounded(18),
			scope:New "UIStroke" { Color = GIFT_COLOR, Thickness = 4 },
			scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) },
			scope:New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 17,
				TextWrapped = true,
				TextColor3 = TEXT,
				Text = scope:Computed(function(use)
					local offer = use(ui.giftOffer)
					if not offer then
						return ""
					end
					local mineral = Config.MineralsById[offer.MineralId]
					local name = if mineral then ("%s (%s)"):format(mineral.Name, Config.RaritiesById[mineral.Rarity].Name) else "un mineral"
					return ("%s te quiere regalar %s"):format(offer.From, name)
				end),
			},
			scope:New "Frame" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					scope:New "TextButton" {
						LayoutOrder = 1,
						Size = UDim2.new(0.5, -5, 1, 0),
						BackgroundColor3 = GREEN_BUTTON,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Font = FONT,
						TextSize = 18,
						TextColor3 = WHITE,
						Text = "Aceptar",
						[OnEvent "Activated"] = function()
							local offer = peek(ui.giftOffer)
							if offer then
								handlers.onGiftAnswer(offer.Id, true)
							end
						end,
						[Children] = { rounded(12) },
					},
					scope:New "TextButton" {
						LayoutOrder = 2,
						Size = UDim2.new(0.5, -5, 1, 0),
						BackgroundColor3 = DISABLED,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Font = FONT,
						TextSize = 18,
						TextColor3 = WHITE,
						Text = "Rechazar",
						[OnEvent "Activated"] = function()
							local offer = peek(ui.giftOffer)
							if offer then
								handlers.onGiftAnswer(offer.Id, false)
							end
						end,
						[Children] = { rounded(12) },
					},
				},
			},
		},
	}

	-- Paneles centrados y, en celular, más pequeños para no chocar con la mochila de abajo.
	if game:GetService("UserInputService").TouchEnabled then
		for _, panel in { shopPanel, robuxPanel, fusePanel, rebirthPanel, backpackPanel } do
			scope:New "UIScale" { Scale = 0.72, Parent = panel }
		end
	end

	scope:New "ScreenGui" {
		Name = "NeoLunaHUD",
		ResetOnSpawn = false,
		-- En celular se usa toda la pantalla, para que la zona y el dinero queden bien arriba.
		IgnoreGuiInset = game:GetService("UserInputService").TouchEnabled,
		Parent = parent,
		[Children] = { moneyPanel, statusPanel, noticePanel, hotbar, backpackPanel, shopPanel, robuxPanel, fusePanel, rebirthPanel, giftOfferPanel },
	}

	return scope
end

return HUD
