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

local addonName, ns = ...

------------------------------------------------------------------------------
-- Our main frame
------------------------------------------------------------------------------

local InlineAura = CreateFrame('Frame', 'InlineAura')

------------------------------------------------------------------------------
-- Retrieve the localization table
------------------------------------------------------------------------------

local L = ns.L
InlineAura.L = L

------------------------------------------------------------------------------
-- Locals
------------------------------------------------------------------------------

local db

local auraChanged = {}
local unitGUIDs = {}
local timerFrames = {}
local needUpdate = false
local configUpdated = false

local buttons = {}
local newButtons = {}
local activeButtons = {}
InlineAura.buttons = buttons

------------------------------------------------------------------------------
-- Libraries and helpers
------------------------------------------------------------------------------

local LSM = LibStub('LibSharedMedia-3.0')

local function dprint() end
--@debug@
if tekDebug then
	local frame = tekDebug:GetFrame(addonName)
	local type, tostring, format = type, tostring, format
	local function mytostringall(a, ...)
		local str
		if type(a) == "table" and type(a.GetName) == "function" then
			str = format("|cffff8844[%s]|r", tostring(a:GetName()))
		else
			str = tostring(a)
		end
		if select('#', ...) > 0 then
			return str, mytostringall(...)
		else
			return str
		end
	end
	dprint = function(...)
		return frame:AddMessage(strjoin(" ", mytostringall(...)):gsub("= ", "="))
	end
end
--@end-debug@
InlineAura.dprint = dprint

------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------
local FONTMEDIA = LSM.MediaType.FONT

local FONT_NAME = LSM:GetDefault(FONTMEDIA)
local FONT_FLAGS = "OUTLINE"
local FONT_SIZE_SMALL = 13
local FONT_SIZE_LARGE = 20

local DEFAULT_OPTIONS = {
	profile = {
		onlyMyBuffs = true,
		onlyMyDebuffs = true,
		hideCountdown = false,
		hideStack = false,
		showStackAtTop = false,
		preciseCountdown = false,
		decimalCountdownThreshold = 10,
		singleTextPosition = 'BOTTOM',
		twoTextFirstPosition = 'BOTTOMLEFT',
		twoTextSecondPosition = 'BOTTOMRIGHT',
		fontName = FONT_NAME,
		smallFontSize     = FONT_SIZE_SMALL,
		largeFontSize     = FONT_SIZE_LARGE,
		colorBuffMine     = { 0.0, 1.0, 0.0, 1.0 },
		colorBuffOthers   = { 0.0, 1.0, 1.0, 1.0 },
		colorDebuffMine   = { 1.0, 0.0, 0.0, 1.0 },
		colorDebuffOthers = { 1.0, 1.0, 0.0, 1.0 },
		colorCountdown    = { 1.0, 1.0, 1.0, 1.0 },
		colorStack        = { 1.0, 1.0, 0.0, 1.0 },
		spells = {
			['**'] = {
				disabled = false,
				auraType = 'regular',
			},
		},
		enabledUnits = {
			player = true,
			pet = true,
			target = true,
			focus = true,
			mouseover = false,
		}
	},
}
InlineAura.DEFAULT_OPTIONS = DEFAULT_OPTIONS

-- Events only needed if the unit is enabled
local UNIT_EVENTS = {
	focus = 'PLAYER_FOCUS_CHANGED',
	mouseover = 'UPDATE_MOUSEOVER_UNIT',
}

------------------------------------------------------------------------------
-- Table recycling stub
------------------------------------------------------------------------------

local new, del
do
	local heap = setmetatable({}, {__mode='k'})
	function new()
		local t = next(heap)
		if t then
			heap[t] = nil
		else
			t = {}
		end
		return t
	end
	function del(t)
		if type(t) == "table" then
			wipe(t)
			heap[t] = true
		end
	end
end
InlineAura.new, InlineAura.del = new, del

------------------------------------------------------------------------------
-- Some Unit helpers
------------------------------------------------------------------------------

local UnitCanAssist, UnitCanAttack, UnitIsUnit = UnitCanAssist, UnitCanAttack, UnitIsUnit

local MY_UNITS = { player = true, pet = true, vehicle = true }

-- These two functions return nil when unit does not exist
local UnitIsBuffable = function(unit) return MY_UNITS[unit] or UnitCanAssist('player', unit) end
local UnitIsDebuffable = function(unit) return UnitCanAttack('player', unit) end

------------------------------------------------------------------------------
-- Special "auras" handling
------------------------------------------------------------------------------

local SPECIALS = {}
local SPECIALS_EVENTS = {}
InlineAura.SPECIALS = SPECIALS

function InlineAura:RegisterSpecial(name, testFunc, event, handler)
	SPECIALS[name] = testFunc
	SPECIALS_EVENTS[name] = event
	if event and handler then
		if self[event] then
			hooksecurefunc(self, event, handler)
		else
			self[event] = handler
		end
	end
end

local UpdateSpecialListeners
do
	local t = {}
	function UpdateSpecialListeners()
		wipe(t)
		for special, event in pairs(SPECIALS_EVENTS) do
			t[event] = false
		end
		for name, spell in pairs(db.profile.spells) do
			if not spell.disabled and spell.aliases then
				for i, alias in pairs(spell.aliases) do
					local event = SPECIALS_EVENTS[alias]
					if event then
						t[event] = alias
					end
				end
			end
		end
		for event, enabled in pairs(t) do
			if enabled then
				if not InlineAura:IsEventRegistered(event) then
					--@debug@
					dprint("Starting listening for event", event, "for special", enabled)
					--@end-debug@
					InlineAura:RegisterEvent(event)
					InlineAura[event](InlineAura, "UpdateSpecialListeners")
				end
			elseif InlineAura:IsEventRegistered(event) then
				--@debug@
				dprint("Stopping listening for", event)
				--@end-debug@
				InlineAura:UnregisterEvent(event)
				InlineAura[event](InlineAura, "UpdateSpecialListeners")
			end
		end
	end
end

------------------------------------------------------------------------------
-- Countdown formatting
------------------------------------------------------------------------------

local floor, ceil = math.floor, math.ceil

local function GetPreciseCountdownText(timeLeft, threshold)
	if timeLeft >= 3600 then
		return L["%dh"]:format(floor(timeLeft/3600)), 1 + floor(timeLeft) % 3600
	elseif timeLeft >= 600 then
		return L["%dm"]:format(floor(timeLeft/60)), 1 + floor(timeLeft) % 60
	elseif timeLeft >= 60 then
		return ("%d:%02d"):format(floor(timeLeft/60), floor(timeLeft%60)), timeLeft % 1
	elseif timeLeft >= threshold then
		return tostring(floor(timeLeft)), timeLeft % 1
	elseif timeLeft >= 0 then
		return ("%.1f"):format(floor(timeLeft*10)/10), 0
	else
		return "0"
	end
end

local function GetImpreciseCountdownText(timeLeft)
	if timeLeft >= 3600 then
		return L["%dh"]:format(ceil(timeLeft/3600)), ceil(timeLeft) % 3600
	elseif timeLeft >= 60 then
		return L["%dm"]:format(ceil(timeLeft/60)), ceil(timeLeft) % 60
	elseif timeLeft > 0 then
		return tostring(floor(timeLeft)), timeLeft % 1
	else
		return "0"
	end
end

local function GetCountdownText(timeLeft, precise, threshold)
	return (precise and GetPreciseCountdownText or GetImpreciseCountdownText)(timeLeft, threshold)
end

------------------------------------------------------------------------------
-- Home-made bucketed timers
------------------------------------------------------------------------------
-- This is mainly a simplified version of AceTimer-3.0, credits goes to Ace3 authors

local ScheduleTimer, CancelTimer, FireTimers, TimerCallback
do
	local BUCKETS = 131
	local HZ = 20
	local buckets = {}
	local targets = {}
	for i = 1, BUCKETS do buckets[i] = {} end

	local lastIndex = floor(GetTime()*HZ)

	function ScheduleTimer(target, delay)
		assert(target and type(delay) == "number" and delay >= 0)
		if targets[target] then
			buckets[targets[target]][target] = nil
		end
		local when = GetTime() + delay
		local index = floor(when*HZ) + 1
		local bucketNum = 1 + (index % BUCKETS)
		buckets[bucketNum][target] = when
		targets[target] = bucketNum
	end

	function CancelTimer(target)
		assert(target)
		local bucketNum = targets[target]
		if bucketNum then
			buckets[bucketNum][target] = nil
			targets[target] = nil
		end
	end

	function ProcessTimers()
		local now = GetTime()
		local newIndex = floor(now*HZ)
		for index = lastIndex + 1, newIndex do
			local bucketNum = 1 + (index % BUCKETS)
			local bucket = buckets[bucketNum]
			for target, when in pairs(bucket) do
				if when <= now then
					bucket[target] = nil
					targets[target] = nil
					TimerCallback(target)
				end
			end
		end
		lastIndex = newIndex
	end
end

------------------------------------------------------------------------------
-- Timer frame handling
------------------------------------------------------------------------------

local TimerFrame_OnUpdate, TimerFrame_Skin, TimerFrame_Display, TimerFrame_UpdateCountdown

local function SetTextPosition(text, position)
	text:SetJustifyH(position:match('LEFT') or position:match('RIGHT') or 'MIDDLE')
	text:SetJustifyV(position:match('TOP') or position:match('BOTTOM') or 'CENTER')
end

function TimerFrame_UpdateTextLayout(self)
	local stackText, countdownText = self.stackText, self.countdownText
	if countdownText:IsShown() and stackText:IsShown() then
		SetTextPosition(countdownText, InlineAura.db.profile.twoTextFirstPosition)
		SetTextPosition(stackText, InlineAura.db.profile.twoTextSecondPosition)
	elseif countdownText:IsShown() then
		SetTextPosition(countdownText, InlineAura.db.profile.singleTextPosition)
	elseif stackText:IsShown() then
		SetTextPosition(stackText, InlineAura.db.profile.singleTextPosition)
	end
end

function TimerFrame_Skin(self)
	local font = LSM:Fetch(FONTMEDIA, db.profile.fontName)

	local countdownText = self.countdownText
	countdownText.fontName = font
	countdownText.baseFontSize = db.profile[InlineAura.bigCountdown and "largeFontSize" or "smallFontSize"]
	countdownText:SetFont(font, countdownText.baseFontSize, FONT_FLAGS)
	countdownText:SetTextColor(unpack(db.profile.colorCountdown))

	local stackText = self.stackText
	stackText:SetFont(font, db.profile.smallFontSize, FONT_FLAGS)
	stackText:SetTextColor(unpack(db.profile.colorStack))

	TimerFrame_UpdateTextLayout(self)
end

function TimerFrame_OnUpdate(self)
	TimerFrame_UpdateCountdown(self, GetTime())
end

-- Compat
TimerFrame_CancelTimer = CancelTimer
TimerCallback = TimerFrame_OnUpdate

function TimerFrame_UpdateCountdown(self, now)
	local timeLeft = self.expirationTime - now
	local displayTime, delay = GetCountdownText(timeLeft, db.profile.preciseCountdown, db.profile.decimalCountdownThreshold)
	self.countdownText:SetText(displayTime)
	if delay then
		ScheduleTimer(self, math.min(delay, timeLeft))
	end
end

function TimerFrame_Display(self, expirationTime, count, now)
	local stackText, countdownText = self.stackText, self.countdownText

	if count then
		stackText:SetText(count)
		stackText:Show()
	else
		stackText:Hide()
	end

	if expirationTime then
		self.expirationTime = expirationTime
		TimerFrame_UpdateCountdown(self, now)
		countdownText:Show()
		countdownText:SetFont(countdownText.fontName, countdownText.baseFontSize, FONT_FLAGS)
		local sizeRatio = countdownText:GetStringWidth() / (self:GetWidth()-4)
		if sizeRatio > 1 then
			countdownText:SetFont(countdownText.fontName, countdownText.baseFontSize / sizeRatio, FONT_FLAGS)
		end
	else
		TimerFrame_CancelTimer(self)
		countdownText:Hide()
	end

	if stackText:IsShown() or countdownText:IsShown() then
		self:Show()
		TimerFrame_UpdateTextLayout(self)
	else
		self:Hide()
	end
end

local function CreateTimerFrame(button)
	local timer = CreateFrame("Frame", nil, button)
	local cooldown = _G[button:GetName()..'Cooldown']
	timer:SetFrameLevel(cooldown:GetFrameLevel() + 5)
	timer:SetAllPoints(cooldown)
	timer:SetToplevel(true)
	timer:Hide()
	timer:SetScript('OnHide', TimerFrame_CancelTimer)
	timerFrames[button] = timer

	local countdownText = timer:CreateFontString(nil, "OVERLAY")
	countdownText:SetAllPoints(timer)
	countdownText:Show()
	timer.countdownText = countdownText

	local stackText = timer:CreateFontString(nil, "OVERLAY")
	stackText:SetAllPoints(timer)
	timer.stackText = stackText

	TimerFrame_Skin(timer)

	return timer
end

------------------------------------------------------------------------------
-- LibButtonFacade compatibility
------------------------------------------------------------------------------

local function SetVertexColor(texture, r, g, b, a)
	texture:SetVertexColor(r, g, b, a)
end

local function LBF_SetVertexColor(texture, r, g, b, a)
	local R, G, B, A = texture:GetVertexColor()
	texture:SetVertexColor(r*R, g*G, b*B, a*(A or 1))
end

local function LBF_Callback()
	configUpdated = true
end

------------------------------------------------------------------------------
-- Aura lookup
------------------------------------------------------------------------------

local function GetModifiedTarget(spell, target)
	if not spell then return end
	local auraType = "regular"
	local specific = rawget(db.profile.spells, spell)
	if specific then
		if specific.disabled then
			return
		end
		auraType = specific.auraType or "regular"
		if auraType == "self" or auraType == "special" then
			target = "player"
		elseif auraType == "pet" then
			target = "pet"
		end
	end
	if auraType == "regular" and target then
		if IsHarmfulSpell(spell) and not UnitIsDebuffable(target) then
			return
		elseif IsHelpfulSpell(spell) and not UnitIsBuffable(target) then
			return
		end
	end
	return auraType, target
end

local isShaman = select(2, UnitClass("player")) == "SHAMAN"
local function AuraLookup(unit, onlyMyBuffs, onlyMyDebuffs, ...)
	local helpfulFilter = onlyMyBuffs and "HELPFUL PLAYER" or "HELPFUL"
	local harmfulFilter = onlyMyDebuffs and "HARMFUL PLAYER" or "HARMFUL"
	for i = 1, select('#', ...) do
		local aura = select(i, ...)
		if SPECIALS[aura] then
			-- Specials only exists on player
			if unit == "player" then
				local count, glowing = SPECIALS[aura]()
				if count and count ~= 0 then
					return aura, count, nil, false, true, glowing
				end
			end
		else
			-- Look for debuff or buff
			local isDebuff = false
			local name, _, _, count, _, duration, expirationTime, caster = UnitAura(unit, aura, nil, harmfulFilter)
			if name then
				isDebuff = true
			else
				name, _, _, count, _, duration, expirationTime, caster = UnitAura(unit, aura, nil, helpfulFilter)
			end
			if name then
				return name, count ~= 0 and count or nil, duration and duration ~= 0 and expirationTime or nil, isDebuff, caster and MY_UNITS[caster]
			end
			if unit == "player" then
				-- Look for tracking
				for index = 1, GetNumTrackingTypes() do
					local name, _, active = GetTrackingInfo(index)
					if name == aura and active then
						return name, nil, nil, false, true
					end
				end
				if isShaman then
					-- Look for totems
					for slot = 1, 4 do
						local haveTotem, name, startTime, duration = GetTotemInfo(slot)
						if haveTotem and name == aura then
							local expirationTime = startTime and duration and (startTime + duration) or nil
							return name, nil, expirationTime, false, true
						end
					end
				end
			end
		end
	end
end

local EMPTY_TABLE = {}
local function GetAuraToDisplay(spell, target)
	local aliases
	local hideStack = db.profile.hideStack
	local hideCountdown = db.profile.hideCountdown
	local onlyMyBuffs = db.profile.onlyMyBuffs
	local onlyMyDebuffs = db.profile.onlyMyDebuffs
	local glowing = false

	-- Specific spell overrides global settings and targeting
	local specific = rawget(db.profile.spells, spell) -- Bypass AceDB auto-creation
	if type(specific) == 'table' then
		glowing = specific.alternateColor
		aliases = specific.aliases
		if specific.hideStack ~= nil then
			hideStack = specific.hideStack
		end
		if specific.hideCountdown ~= nil then
			hideCountdown = specific.hideCountdown
		end
		if specific.auraType == "self" then
			onlyMyBuffs, onlyMyDebuffs = true, true
		elseif specific.auraType == "special" then
			onlyMyBuffs, onlyMyDebuffs, hideStack, hideCountdown = true, true, false, false
		elseif specific.onlyMine ~= nil then
			onlyMyBuffs, onlyMyDebuffs = specific.onlyMine, specific.onlyMine
		end
	end

	-- Look for the aura or its aliases
	local name, count, expirationTime, isDebuff, isMine, specGlowing = AuraLookup(target, onlyMyBuffs, onlyMyDebuffs, spell, unpack(aliases or EMPTY_TABLE)) 
	if name then
		return name, (not hideStack) and count or nil, (not hideCountdown) and expirationTime or nil, isDebuff, isMine, glowing or specGlowing
	end
end

------------------------------------------------------------------------------
-- Visual feedback hooks
------------------------------------------------------------------------------

local function UpdateTimer(self)
	local state = buttons[self]
	if state.name and (state.expirationTime or state.count) then
		local now = GetTime()
		local expirationTime = state.expirationTime
		if expirationTime and expirationTime <= now then
			expirationTime = nil
		end
		local count = state.count
		if count == 0 then
			count = nil
		end
		if expirationTime or count then
			local frame = timerFrames[self] or CreateTimerFrame(self)
			return TimerFrame_Display(frame, expirationTime, count, now)
		end
	end
	if timerFrames[self] then
		timerFrames[self]:Hide()
	end
end

local ActionButton_ShowOverlayGlow = ActionButton_ShowOverlayGlow

local function ActionButton_HideOverlayGlow_Hook(self)
	local state = buttons[self] 
	if not state then return end
	if state.name and state.glowing then
		--@debug@
		self:Debug("Enforcing glowing for", state.name)
		--@end-debug@
		return ActionButton_ShowOverlayGlow(self)
	end
end

local function UpdateButtonState_Hook(self)
	local state = buttons[self] 
	if not state then return end
	local texture = self:GetCheckedTexture()
	if state.name and not state.glowing then
		--@debug@
		self:Debug("Showing border for", state.name)
		--@end-debug@
		local color = db.profile['color'..(state.isDebuff and "Debuff" or "Buff")..(state.isMine and 'Mine' or 'Others')]
		self:__IA_SetChecked(true)
		SetVertexColor(texture, unpack(color))
	else
		texture:SetVertexColor(1, 1, 1)
	end
	return UpdateTimer(self)
end

------------------------------------------------------------------------------
-- Aura updating
------------------------------------------------------------------------------

local function FindMacroOptions(...)
	for i = 1, select('#', ...) do
		local line = select(i, ...)
		local prefix, suffix = strsplit(" ", line:trim(), 2)
		if suffix and (prefix == '#show' or prefix == '#showtooltip' or prefix:sub(1,1) ~= "#") then
			return suffix
		end
	end
end

local function GuessMacroTarget(index)
	local options = FindMacroOptions(strsplit("\n", GetMacroBody(index)))
	if options then
		local action, target = SecureCmdOptionParse(options)
		if action and action ~= "" and target and target ~= "" then
			return target
		end
	end
end

local function GuessSpellTarget(spell)
	if IsModifiedClick("SELFCAST") then
		return "player"
	elseif IsModifiedClick("FOCUSCAST") then
		return "focus"
	elseif spell and IsHelpfulSpell(spell) and not UnitIsBuffable("target") and GetCVarBool("autoSelfCast") then
		return "player"
	else
		return "target"
	end
end

local ActionButton_UpdateOverlayGlow = ActionButton_UpdateOverlayGlow

local function UpdateButtonAura(self, force)
	local state = buttons[self] 
	if not state then return end
	
	local action, param = state.action, state.param
	local spell, target = param, SecureButton_GetModifiedUnit(self)
	
	if target == "" then target = nil end
	if action == "macro" then
		spell = GetMacroSpell(param)
		if not target then
			target = GuessMacroTarget(param) or GuessSpellTarget(spell)
		end
	elseif not target then
		target = GuessSpellTarget(spell)
	end
	
	local auraType
	auraType, target = GetModifiedTarget(spell, target)
	local guid = target and UnitGUID(target)

	if force or auraChanged[guid or state.guid or false] or auraType ~= state.auraType or spell ~= state.spell or guid ~= state.guid then
		--@debug@
		self:Debug(self, "UpdateButtonAura update because of:",
			force and "forced" or "-",
			auraChanged[guid or false] and "aura" or "-",
			auraType ~= state.auraType and "auraType" or "-",
			spell ~= state.spell and "spell" or "-",
			guid ~= state.guid and "guid" or "-"
		)
		--@end-debug@
		state.spell, state.guid, state.auraType = spell, guid, auraType
		
		local name, count, expirationTime, isDebuff, isMine, glowing
		if spell and target and auraType then
			name, count, expirationTime, isDebuff, isMine, glowing = GetAuraToDisplay(spell, target)
			--@debug@
			if name then
				self:Debug("GetAuraToDisplay", spell, target, "=>", "name=", name, "count=", count, "expirationTime=", expirationTime, "isDebuff=", isDebuff, "isMine=", isMine, "glowing=", glowing)
			end
			--@end-debug@
		end

		if state.name ~= name or state.count ~= count or state.expirationTime ~= expirationTime or state.isDebuff ~= isDebuff or state.isMine ~= isMine or state.glowing ~= glowing then 
			state.name, state.count, state.expirationTime, state.isDebuff, state.isMine = name, count, expirationTime, isDebuff, isMine
			if state.glowing ~= glowing then
				state.glowing = glowing
				--@debug@
				self:Debug("GetAuraToDisplay: updating glow")
				--@end-debug@
				ActionButton_UpdateOverlayGlow(self)
			end
			--@debug@
			self:Debug("GetAuraToDisplay: updating state")
			--@end-debug@
			self:__IA_UpdateState()			
		end
	end
end

------------------------------------------------------------------------------
-- Action handling
------------------------------------------------------------------------------

local function ParseAction(self)
	local action, param = self:__IA_GetAction()
	if action == 'action' then
		local _, spellId
		action, param, _, spellId = GetActionInfo(param)
		if action == 'equipmentset' then
			return
		elseif action == 'companion' then
			action, param = 'spell', spellId
		end
	end
	if action == 'item' and param then
		return "spell", GetItemSpell(param)
	elseif action == 'spell' and param then
		return action, (GetSpellInfo(param))
	elseif action == "macro" then
		return action, param
	end
end

local function UpdateAction_Hook(self)
	local state = buttons[self] 
	if not state then return end
	local action, param
	if self:IsVisible() then
		action, param = ParseAction(self)
	end
	if action ~= state.action or param ~= state.param then
		--@debug@
		self:Debug("action changed =>", action, param)
		--@end-debug@
		state.action, state.param = action, param
		activeButtons[self] = (action and param) or nil
		return UpdateButtonAura(self)
	end
end

------------------------------------------------------------------------------
-- Button initializing
------------------------------------------------------------------------------

local function Blizzard_GetAction(self)
	return 'action', self.action
end

local function NOOP() end
local function InitializeButton(self)
	if buttons[self] then return end
	buttons[self] = {}
	self.__IA_SetChecked = self.SetChecked
	--@debug@
	if true or self == BonusActionButton1 then
		self.Debug = dprint
	else
	--@end-debug@
		self.Debug = self.Debug or NOOP
	--@debug@
	end
	--@end-debug@
	if self.__LAB_Version then
		self.__IA_GetAction = self.GetAction
		self.__IA_UpdateState = self.Update
		hooksecurefunc(self, 'SetChecked', UpdateButtonState_Hook)
		hooksecurefunc(self, 'UpdateAction', UpdateAction_Hook)
	else
		self.__IA_GetAction = Blizzard_GetAction
		self.__IA_UpdateState = function(self)
			ActionButton_UpdateState(self)
		end
	end
	UpdateAction_Hook(self)
end

------------------------------------------------------------------------------
-- Blizzard button hooks
------------------------------------------------------------------------------

local function ActionButton_OnLoad_Hook(self)
	if not buttons[self] and not newButtons[self] then
		newButtons[self] = true
		return true
	end
end

local function ActionButton_Update_Hook(self)
	return ActionButton_OnLoad_Hook(self) or UpdateAction_Hook(self)
end

------------------------------------------------------------------------------
-- Event listener stuff
------------------------------------------------------------------------------

local function UpdateUnitListeners()
	for unit, event in pairs(UNIT_EVENTS) do
		if db.profile.enabledUnits[unit] then
			--@debug@
			if not InlineAura:IsEventRegistered(event) then
				dprint("Starting listening for event", event, 'for unit', unit)
			end
			--@end-debug@
			InlineAura:RegisterEvent(event)
		else
			--@debug@
			if InlineAura:IsEventRegistered(event) then
				dprint("Stopping listening for event", event, 'for unit', unit)
			end
			--@end-debug@
			InlineAura:UnregisterEvent(event)
		end
	end
end

------------------------------------------------------------------------------
-- Button updates
------------------------------------------------------------------------------

function InlineAura:OnUpdate(elapsed)
	-- Configuration has been updated
	if configUpdated then

		-- Update event listening based on units
		UpdateUnitListeners()

		-- Update event listening based on SPECIALS
		UpdateSpecialListeners()

		-- Update timer skins
		for button, timerFrame in pairs(timerFrames) do
			TimerFrame_Skin(timerFrame)
		end
	end

	-- Watch for mouseover aura if we can't get UNIT_AURA events
	if unitGUIDs['mouseover'] then
		if unitGUIDs['mouseover'] ~= UnitGUID('mouseover') then
			self:UPDATE_MOUSEOVER_UNIT("OnUpdate")
		elseif self.mouseoverTimer < elapsed then
			self.mouseoverTimer = 1
			if not (UnitInParty('mouseover') or UnitInRaid('mouseover') or UnitIsUnit('mouseover', 'pet') or UnitIsUnit('mouseover', 'target') or UnitIsUnit('mouseover', 'focus')) then
				self:UPDATE_MOUSEOVER_UNIT("OnUpdate")
			end
		else
			self.mouseoverTimer = self.mouseoverTimer - elapsed
		end
	end

	-- Handle new buttons
	if next(newButtons) then
		for button in pairs(newButtons) do
			InitializeButton(button)
		end
		wipe(newButtons)
	end

	-- Update buttons
	if next(auraChanged) or needUpdate or configUpdated then
		for button in pairs(activeButtons) do
			UpdateButtonAura(button, configUpdated)
		end
		needUpdate, configUpdated = false, false
		wipe(auraChanged)
	end

	-- Update timers
	ProcessTimers()
end

function InlineAura:RequireUpdate(config)
	configUpdated = config
	needUpdate = true
end

function InlineAura:RegisterButtons(prefix, count)
	for id = 1, count do
		local button = _G[prefix .. id]
		if button and not buttons[button] and not newButtons[button] then
			newButtons[button] = true
		end
	end
end

------------------------------------------------------------------------------
-- Event handling
------------------------------------------------------------------------------

function InlineAura:AuraChanged(unit)
	local oldGUID = unitGUIDs[unit]
	local guid = db.profile.enabledUnits[unit] and UnitGUID(unit)
	if oldGUID then
		auraChanged[oldGUID] = true
	end
	if guid then
		auraChanged[guid] = true
	end
	unitGUIDs[unit] = guid
	if UnitIsUnit(unit, 'mouseover') then
		self.mouseoverTimer = 1
	end
end

function InlineAura:UNIT_ENTERED_VEHICLE(event, unit)
	if unit == 'player' then
		self:AuraChanged("player")
	end
end

InlineAura.UNIT_EXITED_VEHICLE = InlineAura.UNIT_ENTERED_VEHICLE

function InlineAura:UNIT_AURA(event, unit)
	self:AuraChanged(unit)
end

function InlineAura:UNIT_PET(event, unit)
	if unit == 'player' then
		self:AuraChanged("pet")
	end
end

function InlineAura:PLAYER_ENTERING_WORLD(event)
	for unit, enabled in pairs(db.profile.enabledUnits) do
		if enabled then
			self:AuraChanged(unit)
		end
	end
end

function InlineAura:PLAYER_FOCUS_CHANGED(event)
	self:AuraChanged("focus")
end

function InlineAura:PLAYER_TARGET_CHANGED(event)
	self:AuraChanged("target")
end

function InlineAura:UPDATE_MOUSEOVER_UNIT(event)
	self:AuraChanged("mouseover")
end

function InlineAura:MODIFIER_STATE_CHANGED(event)
	self:RequireUpdate()
end

function InlineAura:CVAR_UPDATE(event, name)
	if name == 'autoSelfCast' then
		self:RequireUpdate(true)
	end
end

function InlineAura:UPDATE_BINDINGS(event, name)
	self:RequireUpdate(true)
end

function InlineAura:VARIABLES_LOADED()
	self.VARIABLES_LOADED = nil
	self:UnregisterEvent('VARIABLES_LOADED')

	-- Retrieve default spell configuration, if loaded
	if InlineAura_LoadDefaults then
		InlineAura_LoadDefaults(self)
		InlineAura_LoadDefaults = nil
	end

	-- Saved variables setup
	db = LibStub('AceDB-3.0'):New("InlineAuraDB", DEFAULT_OPTIONS)
	db.RegisterCallback(self, 'OnProfileChanged', 'RequireUpdate')
	db.RegisterCallback(self, 'OnProfileCopied', 'RequireUpdate')
	db.RegisterCallback(self, 'OnProfileReset', 'RequireUpdate')
	self.db = db

	LibStub('LibDualSpec-1.0'):EnhanceDatabase(db, "Inline Aura")

	-- Update the database from previous versions
	for name, spell in pairs(db.profile.spells) do
		if type(spell) == "table" then
			local units = spell.unitsToScan
			if type(units) ~= "table" then units = nil end
			local auraType = spell.auraType
			if auraType == "buff" then
				if units and units.pet then
					auraType = "pet"
				elseif units and units.player and not units.target and not units.focus then
					auraType = "self"
				else
					auraType = "regular"
				end
			elseif auraType == "debuff" or auraType == "enemy" or auraType == "friend" then
				auraType = "regular"
			end
			if spell.auraType ~= auraType then
				spell.auraType = auraType
				spell.unitsToScan = nil
			end
		end
	end

	-- Setup
	self.bigCountdown = true

	-- Setup basic event listening up
	self:RegisterEvent('UNIT_AURA')
	self:RegisterEvent('UNIT_PET')
	self:RegisterEvent('PLAYER_TARGET_CHANGED')
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:RegisterEvent('UNIT_ENTERED_VEHICLE')
	self:RegisterEvent('UNIT_EXITED_VEHICLE')
	self:RegisterEvent('MODIFIER_STATE_CHANGED')
	self:RegisterEvent('CVAR_UPDATE')
	self:RegisterEvent('UPDATE_BINDINGS')

	-- standard buttons
	self:RegisterButtons("ActionButton", 12)
	self:RegisterButtons("BonusActionButton", 12)
	self:RegisterButtons("MultiBarRightButton", 12)
	self:RegisterButtons("MultiBarLeftButton", 12)
	self:RegisterButtons("MultiBarBottomRightButton", 12)
	self:RegisterButtons("MultiBarBottomLeftButton", 12)

	-- Hooks
	hooksecurefunc('ActionButton_OnLoad', ActionButton_OnLoad_Hook)
	hooksecurefunc('ActionButton_UpdateState', UpdateButtonState_Hook)
	hooksecurefunc('ActionButton_Update', ActionButton_Update_Hook)
	hooksecurefunc('ActionButton_HideOverlayGlow', ActionButton_HideOverlayGlow_Hook)

	-- ButtonFacade support
	local LBF = LibStub('LibButtonFacade', true)
	local LBF_RegisterCallback = function() end
	if LBF then
		SetVertexColor = LBF_SetVertexColor
		LBF:RegisterSkinCallback("Blizzard", LBF_Callback)
	end
	-- Miscellanous addon support
	if Dominos then
		self:RegisterButtons("DominosActionButton", 72)
		hooksecurefunc(Dominos.ActionButton, "Skin", ActionButton_OnLoad_Hook)
		if LBF then
			LBF:RegisterSkinCallback("Dominos", LBF_Callback)
		end
	end
	if Bartender4 then
		self:RegisterButtons("BT4Button", 120)
		if LBF then
			LBF:RegisterSkinCallback("Bartender4", LBF_Callback)
		end
	end
	if OmniCC or CooldownCount then
		InlineAura.bigCountdown = false
	end
	local LAB, LAB_version = LibStub("LibActionButton-1.0", true)
	if LAB then
		--@debug@
		dprint("Found LibActionButton-1.0 version", LAB_version)
		--@end-debug@
		hooksecurefunc(LAB, "CreateButton", function(_, id, name, header, config)
			local button = name and _G[name]
			if button then
				ActionButton_OnLoad_Hook(button)
			end
		end)
	end

	-- Refresh everything
	self:RequireUpdate(true)

	-- Our bucket thingy
	self.mouseoverTimer = 1
	self:SetScript('OnUpdate', self.OnUpdate)

	-- Scan unit in case of delayed loading
	if IsLoggedIn() then
		self:PLAYER_ENTERING_WORLD()
	end
end

function InlineAura:ADDON_LOADED(event, name)
	if name ~= addonName then return end
	self:UnregisterEvent('ADDON_LOADED')
	self.ADDON_LOADED = nil

	if IsLoggedIn() then
		self:VARIABLES_LOADED()
	else
		self:RegisterEvent('VARIABLES_LOADED')
	end
end

-- Event handler
InlineAura:SetScript('OnEvent', function(self, event, ...)
	if type(self[event]) == 'function' then
		local success, msg = pcall(self[event], self, event, ...)
		if not success then
			geterrorhandler()(msg)
		end
	--@debug@
	else
		dprint('InlineAura: registered event has no handler: '..event)
	--@end-debug@
	end
end)

-- Initialize on ADDON_LOADED
InlineAura:RegisterEvent('ADDON_LOADED')

------------------------------------------------------------------------------
-- Configuration GUI loader
------------------------------------------------------------------------------

local function LoadConfigGUI()
	LoadAddOn('InlineAura_Config')
end

-- Chat command line
SLASH_INLINEAURA1 = "/inlineaura"
function SlashCmdList.INLINEAURA()
	LoadConfigGUI()
	InterfaceOptionsFrame_OpenToCategory(L['Inline Aura'])
end

-- InterfaceOptionsFrame spy
CreateFrame("Frame", nil, InterfaceOptionsFrameAddOns):SetScript('OnShow', LoadConfigGUI)
