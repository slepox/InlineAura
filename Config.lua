--[[
Copyright (C) 2009-2010 Adirelle

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
--]]

-----------------------------------------------------------------------------
-- Configuration panel
-----------------------------------------------------------------------------
if not InlineAura then return end

local InlineAura = InlineAura
local L, new, del = InlineAura.L, InlineAura.new, InlineAura.del

-- This is used to prevent AceDB to load the default values for a spell
-- when it has been explictly removed by the user. I'd rather use "false",
-- but it seems AceDB has some issue with it.
local REMOVED = '**REMOVED**'

local SPELL_DEFAULTS = InlineAura.DEFAULT_OPTIONS.profile.spells

-----------------------------------------------------------------------------
-- Default option handler
-----------------------------------------------------------------------------

local handler = {}

function handler:GetDatabase(info)
	local db = InlineAura.db.profile
	local key = info.arg or info[#info]
	if type(key) == "table" then
		for i = 1, #key-1 do
			db = db[key[i]]
		end
		key = key[#key]
	end
	return db, key
end

function handler:Set(info, ...)
	local db, key = self:GetDatabase(info)
	if info.type == 'color' then
		local color = db[key]
		color[1], color[2], color[3], color[4] = ...
	elseif info.type == 'multiselect' then
		local subKey, value = ...
		db[key][subKey] = value
	else
		db[key] = ...
	end
	InlineAura:RequireUpdate(true)
end

function handler:Get(info, subKey)
	local db, key = self:GetDatabase(info)
	if info.type == 'color' then
		return unpack(db[key])
	elseif info.type == 'multiselect' then
		return db[key][subKey]
	else
		return db[key]
	end
end

local positions = {
	TOPLEFT = L['Top left'],
	TOP = L['Top'],
	TOPRIGHT = L['Top right'],
	LEFT = L['Left'],
	CENTER = L['Center'],
	RIGHT = L['Right'],
	BOTTOMLEFT = L['Bottom left'],
	BOTTOM = L['Bottom'],
	BOTTOMRIGHT = L['Bottom right'],
}
local tmp = {}
function handler:ListTextPositions(info, exclude)
	local exclude2 = InlineAura.bigCountdown or 'CENTER'
	wipe(tmp)
	for pos, label in pairs(positions) do
		if pos ~= exclude and pos ~= exclude2 then
			tmp[pos] = label
		end
	end
	return tmp
end

-----------------------------------------------------------------------------
-- Main options
-----------------------------------------------------------------------------

local options = {
	name = format("%s %s", L['Inline-Aura'], GetAddOnMetadata("InlineAura", "Version")),
	type = 'group',
	handler = handler,
	set = 'Set',
	get = 'Get',
	args = {
		onlyMyBuffs = {
			name = L['Only my buffs'],
			desc = L['Check to ignore buffs cast by other characters.'],
			type = 'toggle',
			order = 10,
		},
		onlyMyDebuffs = {
			name = L['Only my debuffs'],
			desc = L['Check to ignore debuffs cast by other characters.'],
			type = 'toggle',
			order = 20,
		},
		hideCountdown = {
			name = L['No countdown'],
			desc = L['Check to hide the aura countdown.'],
			type = 'toggle',
			order = 30,
		},
		hideStack = {
			name = L['No application count'],
			desc = L['Check to hide the aura application count (charges or stacks).'],
			type = 'toggle',
			order = 40,
		},
		preciseCountdown = {
			name = L['Precise countdown'],
			desc = L['Check to have a more accurate countdown display instead of default Blizzard rounding.'],
			type = 'toggle',
			disabled = function(info) return InlineAura.db.profile.hideCountdown end,
			order = 45,
		},
		decimalCountdownThreshold = {
			name = L['Decimal countdown threshold'],
			desc = L['Select the remaining time threshold under which tenths of second are displayed.'],
			type = 'range',
			min = 1,
			max = 10,
			step = 0.5,
			disabled = function(info) return InlineAura.db.profile.hideCountdown or not InlineAura.db.profile.preciseCountdown end,
			order = 46,
		},
		targeting = {
			name = L['Targeting settings'],
			desc = L['Options related to the units to watch and the way to select them depending on the spells.'],
			type = 'group',
			inline = true,
			order = 49,
			args = {
				focus = {
					name = L['Watch focus'],
					desc = L['Watch aura changes on your focus. Required only to properly update macros that uses @focus targeting.'],
					type = 'toggle',
					order = 10,
					arg = {'enabledUnits', 'focus'},
				},
				mouseover = {
					name = L['Watch unit under mouse cursor'],
					desc = L['Watch aura changes on the unit under the mouse cursor. Required only to properly update macros that uses @mouseover targeting.'],
					type = 'toggle',
					order = 20,
					arg = {'enabledUnits', 'mouseover'},
				},
				emulateAutoSelfCast = {
					name = L['Emulate auto self cast'],
					desc = L['Behave as if the interface option "Auto self cast" was enabled, e.g. look for friendly auras on yourself when you are not targeting a friendly unit.\nNote: this enables the old Inline Aura behavior with friendly spells.'],
					type = 'toggle',
					order = 30,
				},
			},
		},
		colors = {
			name = L['Border highlight colors'],
			desc = L['Select the colors used to highlight the action button. There are selected based on aura type and caster.'],
			type = 'group',
			inline = true,
			order = 50,
			args = {
				buffMine = {
					name = L['My buffs'],
					desc = L['Select the color to use for the buffs you cast.'],
					type = 'color',
					arg = 'colorBuffMine',
					order = 10,
				},
				buffOthers = {
					name = L["Others' buffs"],
					desc = L['Select the color to use for the buffs cast by other characters.'],
					type = 'color',
					arg = 'colorBuffOthers',
					order = 20,
				},
				debuffMine = {
					name = L["My debuffs"],
					desc = L['Select the color to use for the debuffs you cast.'],
					type = 'color',
					arg = 'colorDebuffMine',
					order = 30,
				},
				debuffOthers = {
					name = L["Others' debuffs"],
					desc = L['Select the color to use for the debuffs cast by other characters.'],
					type = 'color',
					arg = 'colorDebuffOthers',
					order = 40,
				},
			},
		},
		text = {
			name = L['Text appearance'],
			type = 'group',
			inline = true,
			order = 60,
			args = {
				smallCountdownExplanation = {
					name = L['Either OmniCC or CooldownCount is loaded so aura countdowns are displayed using small font at the bottom of action buttons.'],
					type = 'description',
					hidden = function() return InlineAura.bigCountdown end,
					order = 5,
				},
				fontName = {
					name = L['Font name'],
					desc = L['Select the font to be used to display both countdown and application count.'],
					type = 'select',
					dialogControl = 'LSM30_Font',
					values = AceGUIWidgetLSMlists.font,
					order = 10,
				},
				smallFontSize = {
					name = L['Size of small text'],
					desc = L['The small font is used to display application count (and countdown when cooldown addons are loaded).'],
					type = 'range',
					min = 5,
					max = 30,
					step = 1,
					order = 20,
				},
				largeFontSize = {
					name = L['Size of large text'],
					desc = L['The large font is used to display countdowns.'],
					type = 'range',
					min = 5,
					max = 30,
					step = 1,
					disabled = function() return not InlineAura.bigCountdown end,
					order = 30,
				},
				dynamicCountdownColor = {
					name = L['Dynamic countdown'],
					desc = L['Make the countdown color, and size if possible, depends on remaining time.'],
					type = 'toggle',
					order = 35,
					disabled = function() return InlineAura.db.profile.hideCountdown end,
				},
				colorCountdown = {
					name = L['Countdown text color'],
					type = 'color',
					hasAlpha = true,
					order = 40,
					disabled = function() return InlineAura.db.profile.hideCountdown or InlineAura.db.profile.dynamicCountdownColor end,
				},
				colorStack = {
					name = L['Application text color'],
					type = 'color',
					hasAlpha = true,
					order = 50,
				},
			},
		},
		layout = {
			name = L['Text Position'],
			type = 'group',
			inline = true,
			order = 70,
			args = {
				_desc = {
					type = 'description',
					name = L['Select where to display countdown and application count in the button. When only one value is displayed, the "single value position" is used instead of the regular one.'],
					order = 10,
				},
				twoTextFirst = {
					name = L['Countdown position'],
					desc = L['Select where to place the countdown text when both values are shown.'],
					type = 'select',
					arg = 'twoTextFirstPosition',
					values = function(info) return info.handler:ListTextPositions(info, InlineAura.db.profile.twoTextSecondPosition) end,
					disabled = function(info) return InlineAura.db.profile.hideCountdown or InlineAura.db.profile.hideStack end,
					order = 20,
				},
				twoTextSecond = {
					name = L['Application count position'],
					desc = L['Select where to place the application count text when both values are shown.'],
					type = 'select',
					arg = 'twoTextSecondPosition',
					values = function(info) return info.handler:ListTextPositions(info, InlineAura.db.profile.twoTextFirstPosition) end,
					disabled = function(info) return InlineAura.db.profile.hideCountdown or InlineAura.db.profile.hideStack end,
					order = 30,
				},
				oneText = {
					name = L['Single value position'],
					desc = L['Select where to place a single value.'],
					type = 'select',
					arg = 'singleTextPosition',
					values = "ListTextPositions",
					disabled = function(info) return InlineAura.db.profile.hideCountdown and InlineAura.db.profile.hideStack end,
					order = 40,
				},
			},
		},
	},
}

-----------------------------------------------------------------------------
-- Class specific options
-----------------------------------------------------------------------------

local _, playerClass = UnitClass("player")
local isPetClass = (playerClass == "WARLOCK" or playerclass == "MAGE" or playerClass == "DEATHKNIGHT" or playerClass == "HUNTER")

local SPECIALS = InlineAura.SPECIALS
if next(SPECIALS) then
	specialValues = {}
	for name in pairs(SPECIALS) do
		specialValues[name] = L[name]
	end
end

-----------------------------------------------------------------------------
-- Spell specific options
-----------------------------------------------------------------------------

local ValidateName

---- Main panel options

local spellPanelHandler = {}
local spellSpecificHandler = {}

local spellToAdd

local spellOptions = {
	name = L['Spell specific settings'],
	type = 'group',
	handler = spellPanelHandler,
	args = {
		addInput = {
			name = L['New spell name'],
			desc = L['Enter the name of the spell for which you want to add specific settings. Non-existent spell or item names are rejected.'],
			type = 'input',
			get = function(info) return spellToAdd end,
			set = function(info, value)
				if value and value:trim() ~= "" then
					spellToAdd = ValidateName(value)
				else
					spellToAdd = nil
				end
			end,
			validate = function(info, value)
				if not value or value:trim() == "" then
					return true
				else
					return ValidateName(value) and true or L["Unknown spell: %s"]:format(tostring(value))
				end
			end,
			order = 10,
		},
		addButton = {
			name = L['Add spell'],
			desc = L['Click to create specific settings for the spell.'],
			type = 'execute',
			order = 20,
			func = function(info)
				if spellPanelHandler:IsDefined(spellToAdd) then
					spellSpecificHandler:SelectSpell(spellToAdd)
				else
					info.handler:AddSpell(spellToAdd)
				end
				spellToAdd = nil
			end,
			disabled = function() return not spellToAdd end,
		},
		editList = {
			name = L['Spell to edit'],
			desc = L['Select the spell to edit or to remove its specific settings. Spells with specific defaults are written in |cff77ffffcyan|r. Removed spells with specific defaults are written in |cff777777gray|r.'],
			type = 'select',
			get = function(info) return spellSpecificHandler:GetSelectedSpell() end,
			set = function(info, value) spellSpecificHandler:SelectSpell(value) end,
			disabled = 'HasNoSpell',
			values = 'GetSpellList',
			order = 30,
		},
		removeButton = {
			name = L['Remove spell'],
			desc = L['Remove spell specific settings.'],
			type = 'execute',
			func = function(info)
				info.handler:RemoveSpell(spellSpecificHandler:GetSelectedSpell())
			end,
			disabled = function()
				return not spellPanelHandler:IsDefined(spellSpecificHandler:GetSelectedSpell())
			end,
			confirm = true,
			confirmText = L['Do you really want to remove these aura specific settings ?'],
			order = 40,
		},
		restoreDefaults = {
			name = function()
				return spellPanelHandler:HasDefault(spellSpecificHandler:GetSelectedSpell()) and L['Restore defaults'] or L['Reset settings']
			end,
			desc = function()
				return spellPanelHandler:HasDefault(spellSpecificHandler:GetSelectedSpell()) and L['Restore default settings of the selected spell.'] or L['Reset settings to global defaults.']
			end,
			type = 'execute',
			func = function(info)
				spellPanelHandler:RestoreDefaults(spellSpecificHandler:GetSelectedSpell())
			end,
			order = 45,
		},
		settings = {
			name = function(info) return spellSpecificHandler:GetSelectedSpellName() end,
			type = 'group',
			hidden = 'IsNoSpellSelected',
			handler = spellSpecificHandler,
			get = 'Get',
			set = 'Set',
			inline = true,
			order = 50,
			args = {
				disable = {
					name = L['Disable'],
					desc = L['Check to totally disable this spell. No border highlight nor text is displayed for disabled spells.'],
					type = 'toggle',
					arg = 'disabled',
					order = 10,
				},
				auraType = {
					name = L['Aura type'],
					desc = L['Select the aura type of this spell. This helps to look up the aura.'],
					type = 'select',
					arg = 'auraType',
					disabled = 'IsSpellDisabled',
					values = {
						regular = L['Regular buff or debuff'],
						self = L['Self buff or debuff'],
						pet = isPetClass and L['Pet buff or debuff'] or nil,
						special = specialValues and L['Special'] or nil,
					},
					order = 20,
				},
				specialAlias = specialValues and {
					name = L['Value to display'],
					desc = L['Select which special value should be displayed.'],
					type = 'select',
					arg = 'aliases',
					disabled = 'IsSpellDisabled',
					get = function(info) return info.handler.db.aliases and info.handler.db.aliases[1] end,
					set = function(info, value)
						if not info.handler.db.aliases then
							info.handler.db.aliases = { value }
						else
							info.handler.db.aliases[1] = value
						end
						InlineAura:RequireUpdate(true)
					end,
					values = specialValues,
					hidden = function(info) return not info.handler:IsSpecial() end,
					order = 30,
				} or nil,
				onlyMine = {
					name = L['Only show mine'],
					desc = L['Check to only show aura you applied. Uncheck to always show aura, even when applied by others. Leave grayed to use default settings.'],
					type = 'toggle',
					arg = 'onlyMine',
					tristate = true,
					disabled = 'IsSpellDisabled',
					hidden = 'IsSpecial',
					order = 30,
				},
				hideCountdown = {
					name = L['No countdown'],
					desc = L['Check to hide the aura duration countdown.'],
					type = 'toggle',
					arg = 'hideCountdown',
					tristate = true,
					disabled = 'IsSpellDisabled',
					hidden = 'IsSpecial',
					order = 35,
				},
				hideStack = {
					name = L['No application count'],
					desc = L['Check to hide the aura application count (charges or stacks).'],
					type = 'toggle',
					arg = 'hideStack',
					tristate = true,
					disabled = 'IsSpellDisabled',
					hidden = 'IsSpecial',
					order = 40,
				},
				highlight = {
					name = L['Highlight effect'],
					desc = L['Select how to highlight the button.'],
					type = 'select',
					arg = 'highlight',
					disabled = 'IsSpellDisabled',
					order = 50,
					values = {
						none = L['None'],
						border = L['Colored border'],
						glowing = L['Glowing animation'],
					}
				},
				invertHighlight = {
					name = L['Invert highlight'],
					desc = L["Check to invert highlight display. Countdown and application count display aren't affected by this setting."],
					type = 'toggle',
					arg = 'invertHighlight',
					disabled = function(info) return info.handler:IsSpellDisabled(info) or info.handler.db.highlight == "none" end,
					order = 55,
				},
				aliases = {
					name = L['Auras to look up'],
					desc = L['Enter additional aura names to check. This allows to check for alternative or equivalent auras. Some spells also apply auras that do not have the same name as the spell.'],
					usage = L['Enter one aura name per line. They are spell-checked ; errors will prevents you to validate.'],
					type = 'input',
					arg = 'aliases',
					disabled = 'IsSpellDisabled',
					multiline = true,
					get = 'GetAliases',
					set = 'SetAliases',
					validate = 'ValidateAliases',
					hidden = 'IsSpecial',
					order = 60,
				},
			},
		},
	},
}

do
	local spellList = {}
	function spellPanelHandler:GetSpellList()
		wipe(spellList)
		for name, data in pairs(InlineAura.db.profile.spells) do
			if type(data) == 'table' then
				if self:HasDefault(name) and data.default then
					if GetSpellInfo(name) then
						spellList[name] = '|cff77ffff'..name..'|r'
					end
				else
					spellList[name] = name
				end
			elseif data == REMOVED then
				if GetSpellInfo(name) then
					spellList[name] = '|cff777777'..name..'|r'
				end
			end
		end
		return spellList
	end
end

function spellPanelHandler:HasNoSpell()
	return not next(self:GetSpellList())
end

function spellPanelHandler:IsDefined(name)
	return name and type(rawget(InlineAura.db.profile.spells, name)) == "table"
end

function spellPanelHandler:HasDefault(name)
	return name and SPELL_DEFAULTS[name]
end

local function copyDefaults(dst, src, enforceTables)
	for k,v in pairs(src) do
		if type(v) == "table" then
			local dv = dst[k]
			if dv == nil or (type(dv) ~= "table" and enforceTables) then
				dv = {}
				dst[k] = dv
			end
			if type(dv) == 'table' then
				copyDefaults(dv, v, enforceTables)
			end
		else
			dst[k] = v
		end
	end
end

local function createSpellwithDefaults(name)
	local spell = {}
	copyDefaults(spell, SPELL_DEFAULTS['**'], true)
	if SPELL_DEFAULTS[name] then
		copyDefaults(spell, SPELL_DEFAULTS[name], false)
	end
	InlineAura.db.profile.spells[name] = spell
end

function spellPanelHandler:AddSpell(name)
	createSpellwithDefaults(name)
	spellSpecificHandler:SelectSpell(name)
	InlineAura:RequireUpdate(true)
end

function spellPanelHandler:RemoveSpell(name)
	if SPELL_DEFAULTS[name] then
		InlineAura.db.profile.spells[name] = REMOVED
	else
		InlineAura.db.profile.spells[name] = nil
	end
	InlineAura:RequireUpdate(true)
	spellSpecificHandler:ListUpdated()
end

function spellPanelHandler:RestoreDefaults(name)
	createSpellwithDefaults(name)
	InlineAura:RequireUpdate(true)
	spellSpecificHandler:ListUpdated()
end

---- Specific aura options

function spellSpecificHandler:ListUpdated()
	if self.name and type(rawget(InlineAura.db.profile.spells, self.name)) == 'table' then
		return self:SelectSpell(self.name)
	end
	for name, data in pairs(InlineAura.db.profile.spells) do
		if type(data) == 'table' then
			return self:SelectSpell(name)
		end
	end
	self:SelectSpell(nil)
end

function spellSpecificHandler:GetSelectedSpell()
	return self.name
end

function spellSpecificHandler:GetSelectedSpellName()
	return self.name or "???"
end

function spellSpecificHandler:SelectSpell(name)
	local db = name and rawget(InlineAura.db.profile.spells, name)
	if type(db) == 'table' then
		self.name, self.db = name, db
	elseif db == REMOVED then
		self.name, self.db = name, nil
	else
		self.name, self.db = nil, nil
	end
end

function spellSpecificHandler:IsNoSpellSelected()
	return not self.db
end

function spellSpecificHandler:IsSpellDisabled()
	return not self.db or self.db.disabled
end

function spellSpecificHandler:IsSpecial()
	return not self.db or self.db.auraType == "special"
end

function spellSpecificHandler:Set(info, ...)
	if info.type == 'color' then
		local color = self.db[info.arg]
		color[1], color[2], color[3], color[4] = ...
	elseif info.type == 'multiselect' then
		local key, value = ...
		value = value and true or false
		if type(self.db[info.arg]) ~= 'table' then
			self.db[info.arg] = { key = value }
		else
			self.db[info.arg][key] = value
		end
	else
		self.db[info.arg] = ...
	end
	self.db.default = nil
	InlineAura:RequireUpdate(true)
end

function spellSpecificHandler:Get(info, key)
	if info.type == 'color' then
		return unpack(self.db[info.arg])
	elseif info.type == 'multiselect' then
		return type(self.db[info.arg]) == "table" and self.db[info.arg][key]
	else
		return self.db[info.arg]
	end
end

function spellSpecificHandler:GetAliases(info)
	local aliases = self.db.aliases
	return type(aliases) == 'table' and table.concat(aliases, "\n") or nil
end

function spellSpecificHandler:SetAliases(info, value)
	local aliases = self.db.aliases
	if aliases then
		wipe(aliases)
	else
		aliases = {}
	end
	for name in tostring(value):gmatch("[^\n]+") do
		name = name:trim()
		if name ~= "" then
			table.insert(aliases, ValidateName(name))
		end
	end
	if #aliases > 0 then
		self.db.aliases = aliases
	else
		self.db.aliases = nil
	end
	self.db.default = nil
	InlineAura:RequireUpdate(true)
end

function spellSpecificHandler:ValidateAliases(info, value)
	for name in tostring(value):gmatch("[^\n]+") do
		name = name:trim()
		if name ~= "" and not ValidateName(name) then
			return L["Unknown spell: %s"]:format(name)
		end
	end
	return true
end

-----------------------------------------------------------------------------
-- Spell name validation
-----------------------------------------------------------------------------

do
	local GetSpellInfo, GetItemInfo = GetSpellInfo, GetItemInfo
	local validNames = setmetatable({}, {
		__mode = 'kv',
		__index = function(self, key)
			local result = false
			if SPECIALS[key] then
				result = key
			else
				local rawId = tonumber(string.match(tostring(key), '^#(%d+)$'))
				if rawId then
					if GetSpellInfo(rawId) then
						result = '#'..rawId
					end
				else
					result = GetSpellInfo(key) or GetItemInfo(key)
					if not result then
						local id = rawget(self, '__id') or 0
						while id < 100000 do -- Arbitrary high spell id
							local name = GetSpellInfo(id)
							id = id + 1
							if name then
								if name:lower() == key:lower() then
									result = name
									break
								else
									self[name] = name
								end
							end
						end
						self.__id = id
					end
				end
			end
			self[key] = result
			return result
		end
	})

	function ValidateName(name)
		return type(name) == "string" and validNames[name]
	end
end

-----------------------------------------------------------------------------
-- Setup
-----------------------------------------------------------------------------

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Register main options
AceConfig:RegisterOptionsTable('InlineAura-main', options)

-- Register spell specific options
AceConfig:RegisterOptionsTable('InlineAura-spells', spellOptions)

-- Register profile options
local dbOptions = LibStub('AceDBOptions-3.0'):GetOptionsTable(InlineAura.db)
LibStub('LibDualSpec-1.0'):EnhanceOptions(dbOptions, InlineAura.db)
AceConfig:RegisterOptionsTable('InlineAura-profiles', dbOptions)

-- Create Blizzard AddOn option frames
local mainTitle = L['Inline Aura']
local mainPanel = AceConfigDialog:AddToBlizOptions('InlineAura-main', mainTitle)
AceConfigDialog:AddToBlizOptions('InlineAura-spells', L['Spell specific settings'], mainTitle)
AceConfigDialog:AddToBlizOptions('InlineAura-profiles', L['Profiles'], mainTitle)

-- Update selected spell on database change
InlineAura.db.RegisterCallback(spellSpecificHandler, 'OnProfileChanged', 'ListUpdated')
InlineAura.db.RegisterCallback(spellSpecificHandler, 'OnProfileCopied', 'ListUpdated')
InlineAura.db.RegisterCallback(spellSpecificHandler, 'OnProfileReset', 'ListUpdated')
spellSpecificHandler:ListUpdated()
