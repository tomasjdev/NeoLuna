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
local EMPTY_SLOT = Color3.fromRGB(236, 230, 248)
local DISABLED = Color3.fromRGB(190, 184, 208)
local FONT = Enum.Font.FredokaOne

local ROW_COLORS = {
	Speed = Color3.fromRGB(255, 150, 70),
	Strength = Color3.fromRGB(45, 190, 180),
	Pickaxe = Color3.fromRGB(150, 110, 255),
}

local function formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

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

-- ui = { state, carry, notice, shopKind, robuxKind, backpackOpen, selected, depth } (Values de Fusion)
-- handlers = { onUpgrade = function(kind), onSell = function(index) }
function HUD.mount(parent, ui, handlers)
	local scope = Fusion.scoped(Fusion)

	local function rounded(radius)
		return scope:New "UICorner" { CornerRadius = UDim.new(0, radius) }
	end

	local function closeAll()
		ui.shopKind:set("")
		ui.robuxKind:set("")
		ui.placeStand:set(0)
		ui.backpackOpen:set(false)
	end

	local function mineralInfo(use, index)
		local id = use(ui.state).Inventory[index]
		return id and Config.MineralsById[id] or nil
	end

	-- Un espacio de la mochila (se usa en la barra y en la mochila).
	local function Slot(index)
		local mineral = scope:Computed(function(use)
			return mineralInfo(use, index) or false
		end)
		local isSelected = scope:Computed(function(use)
			return use(ui.selected) == index
		end)

		return scope:New "TextButton" {
			Name = "Slot" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = scope:Computed(function(use)
				local m = use(mineral)
				return if m then Config.RaritiesById[m.Rarity].Color else EMPTY_SLOT
			end),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",

			[OnEvent "Activated"] = function()
				ui.selected:set(index)
			end,

			[Children] = {
				rounded(14),
				scope:New "UIStroke" {
					Color = scope:Computed(function(use)
						return if use(isSelected) then TEXT else BORDER
					end),
					Thickness = scope:Computed(function(use)
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
					TextColor3 = TEXT,
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
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,

		[Children] = {
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
					scope:New "TextLabel" {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Font = FONT,
						TextSize = 18,
						TextColor3 = Color3.fromRGB(235, 160, 20),
						Text = "C",
					},
				},
			},
			scope:New "TextLabel" {
				Position = UDim2.fromOffset(50, 0),
				Size = UDim2.new(1, -58, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 26,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					return formatNumber(use(moneySmooth))
				end),
			},
		},
	}

	----------------------------------------------------------------------
	-- Estado (arriba al centro): solo la zona
	----------------------------------------------------------------------

	local statusPanel = scope:New "TextLabel" {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(240, 44),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 20,
		TextColor3 = TEXT,
		Text = scope:Computed(function(use)
			local depth = use(ui.depth)
			if depth <= 0 then
				return "Base lunar"
			end
			return Config.Zones[Config.GetZone(depth)].Name
		end),

		[Children] = {
			rounded(16),
			scope:New "UIStroke" { Color = BORDER, Thickness = 3 },
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
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(460, 40),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = noticeFade,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 18,
		TextColor3 = TEXT,
		TextTransparency = noticeFade,
		Text = ui.notice,

		[Children] = {
			rounded(14),
			scope:New "UIStroke" { Color = BORDER, Thickness = 3, Transparency = noticeFade },
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
		table.insert(hotbarChildren, Slot(index))
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
		table.insert(gridChildren, Slot(index))
	end

	local selectedMineral = scope:Computed(function(use)
		return mineralInfo(use, use(ui.selected)) or false
	end)

	local canSell = scope:Computed(function(use)
		return use(ui.shopKind) == "Sell" and use(selectedMineral) ~= false
	end)
	local canPlace = scope:Computed(function(use)
		return use(ui.placeStand) > 0 and use(selectedMineral) ~= false
	end)

	local backpackPanel = scope:New "Frame" {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(ui.backpackOpen) or use(ui.shopKind) == "Sell" or use(ui.placeStand) > 0
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
				Text = scope:Computed(function(use)
					return if use(ui.placeStand) > 0 then "Elige un mineral para el estante" else "Mi mochila"
				end),
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
					return ("%s · %s · %s · Vale %s cr"):format(
						m.Name,
						Config.RaritiesById[m.Rarity].Name,
						m.Family,
						formatNumber(m.Value)
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
					return if m then ("Vender por %s cr"):format(formatNumber(m.Value)) else ""
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
				Name = "PlaceButton",
				LayoutOrder = 4,
				Size = UDim2.fromOffset(376, 44),
				BackgroundColor3 = Color3.fromRGB(150, 110, 255),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				TextSize = 20,
				TextColor3 = WHITE,
				Visible = canPlace,
				Text = scope:Computed(function(use)
					local m = use(selectedMineral)
					return if m then ("Dejar %s en el estante"):format(m.Name) else ""
				end),

				[OnEvent "Activated"] = function()
					local standIndex = peek(ui.placeStand)
					local inventoryIndex = peek(ui.selected)
					if peek(canPlace) then
						handlers.onPlace(standIndex, inventoryIndex)
						ui.selected:set(0)
						ui.placeStand:set(0)
					end
				end,

				[Children] = { rounded(14) },
			},
			scope:New "TextButton" {
				Name = "CloseButton",
				LayoutOrder = 5,
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
				return if use(affordable) then ROW_COLORS[kind] else DISABLED
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
					TextSize = 17,
					TextColor3 = WHITE,
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
					TextSize = 12,
					TextColor3 = WHITE,
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
					TextColor3 = WHITE,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = scope:Computed(function(use)
						if use(maxed) then
							return "MÁX"
						end
						return formatNumber(use(cost)) .. " cr"
					end),
				},
			},
		}
	end

	local shopPanel = scope:New "Frame" {
		Name = "Shop",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
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
			scope:New "UIStroke" { Color = BORDER, Thickness = 4 },
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
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 22,
				TextColor3 = TEXT,
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
					end
					return ""
				end),
			},
			UpgradeRow("Speed", 3),
			UpgradeRow("Strength", 4),
			UpgradeRow("Pickaxe", 5),
		},
	}

	----------------------------------------------------------------------
	-- Tiendas de Robux (por ahora informativas: falta crear los pases y productos en Roblox)
	----------------------------------------------------------------------

	local robuxPanel = scope:New "Frame" {
		Name = "RobuxShop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
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
					return product.Description .. (if product.Id == 0 then "\n\n¡Muy pronto!" else "")
				end),
			},
			scope:New "TextButton" {
				LayoutOrder = 3,
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

	scope:New "ScreenGui" {
		Name = "NeoLunaHUD",
		ResetOnSpawn = false,
		Parent = parent,
		[Children] = { moneyPanel, statusPanel, noticePanel, hotbar, backpackPanel, shopPanel, robuxPanel },
	}

	return scope
end

return HUD
