--[[
Copyright (C) 2009 Adirelle

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

local locale = GetLocale()
local L = setmetatable({}, {__index = function(self, key)
	if key ~= nil then
		self[key] = tostring(key)
	end
	--@debug@
	print("InlineAura: missing locale:", key)
	--@end-debug@
	return tostring(key)
end})
InlineAura_L = L

--------------------------------------------------------------------------------
-- default: enUS
--------------------------------------------------------------------------------

L['Add spell'] = true
L['Application text color'] = true
L['Auras to look up'] = true
L['Aura type'] = true
L['Border colors'] = true
L['Buff'] = true
L['Check to have a more accurate countdown display instead of default Blizzard rounding.'] = true
L['Check to hide the aura application count (charges or stacks).'] = true
L['Check to hide the aura countdown.'] = true
L['Check to ignore buffs cast by other characters.'] = true
L['Check to ignore debuffs cast by other characters.'] = true
L['Check to only show aura you applied. Uncheck to always show aura, even when applied by others. Leave grayed to use default settings.'] = true
L['Check to totally disable this spell. No border highlight nor text is displayed for disabled spells.'] = true
L['Check which units you want to be scanned for the aura. Auras of the first existing unit are shown, using this order: focus, target, pet and then player.'] = true
L['Click to create specific settings for the spell.'] = true
L['Countdown text color'] = true
L['Debuff'] = true
L["%dh"] = true
L['Disable'] = true
L["%dm"] = true
L['Do you really want to remove these aura specific settings ?'] = true
L['Either OmniCC or CooldownCount is loaded so aura countdowns are displayed using small font at the bottom of action buttons.'] = true
L['Enter additional aura names to check. This allows to check for alternative or equivalent auras. Some spells also apply auras that do not have the same name as the spell.'] = true
L['Enter the name of the spell for which you want to add specific settings. Spell names are checked against your spellbook.'] = true
L['Font name'] = true
L['Friendly focus'] = true
L['Friendly target'] = true
L['Hostile focus'] = true
L['Hostile target'] = true
L['Inline Aura'] = true
L['My buffs'] = true
L["My debuffs"] = true
L['New spell name'] = true
L['No application count'] = true
L['No countdown'] = true
L['One aura name per line. Name are used as provided so watch your spelling.'] = true
L['Only my buffs'] = true
L['Only my debuffs'] = true
L['Only show mine'] = true
L["Others' buffs"] = true
L["Others' debuffs"] = true
L['Pet'] = true
L['Player'] = true
L['Precise countdown'] = true
L['Profiles'] = true
L['Remove spell specific settings.'] = true
L['Remove spell'] = true
L['Restore default settings of the selected spell.'] = true
L['Restore defaults'] = true
L['Select the aura type of this spell. This helps to look up the aura.'] = true
L['Select the colors used to highlight the action button. There are selected based on aura type and caster.'] = true
L['Select the color to use for the buffs cast by other characters.'] = true
L['Select the color to use for the buffs you cast.'] = true
L['Select the color to use for the debuffs cast by other characters.'] = true
L['Select the color to use for the debuffs you cast.'] = true
L['Select the font to be used to display both countdown and application count.'] = true
L['Select the spell to edit or to remove its specific settings. Spells with specific defaults are written in |cff77ffffcyan|r. Removed spells with specific defaults are written in |cff777777gray|r.'] = true
L['Size of large text'] = true
L['Size of small text'] = true
L['Spell specific settings'] = true
L['Spell to edit'] = true
L['Text appearance'] = true
L['The large font is used to display countdowns.'] = true
L['The small font is used to display application count (and countdown when cooldown addons are loaded).'] = true
L['Units to scan'] = true
L["Unknown spell: %s"] = true

-- Replace true values by the key
for k,v in pairs(L) do if v == true then L[k] = k end end

--------------------------------------------------------------------------------
-- Locales from localization system
--------------------------------------------------------------------------------

-- All these locales are included by the WowAce packager.
-- You can help translating this project using the WowAce localization system:
-- http://www.wowace.com/projects/inline-aura/localization/ 

if locale == "frFR" then
--@localization(locale="frFR", format="lua_additive_table")@
elseif locale == "deDE" then
--@localization(locale="deDE", format="lua_additive_table")@
elseif locale == "esMX" then
--@localization(locale="esMX", format="lua_additive_table")@
elseif locale == "ruRU" then
--@localization(locale="ruRU", format="lua_additive_table")@
elseif locale == "esES" then
--@localization(locale="esES", format="lua_additive_table")@
elseif locale == "zhTW" then
--@localization(locale="zhTW", format="lua_additive_table")@
elseif locale == 'zhCN' then
--@localization(locale="zhCN", format="lua_additive_table")@
elseif locale == 'koKR' then
--@localization(locale="koKR", format="lua_additive_table")@
end

