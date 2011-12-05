--[[
Inline Aura - displays aura information inside action buttons
Copyright (C) 2009-2011 Adirelle (adirelle@tagada-team.net)

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

local addonName, addon = ...

------------------------------------------------------------------------------
-- Import
------------------------------------------------------------------------------

local L = addon.L
local dprint = addon.dprint
local buttons = addon.buttons
local overlayedSpells = addon.overlayedSpells

------------------------------------------------------------------------------
-- Make often-used globals local
------------------------------------------------------------------------------

--<GLOBALS
local _G = _G
local ActionButton_HideOverlayGlow = _G.ActionButton_HideOverlayGlow
local ActionButton_ShowOverlayGlow = _G.ActionButton_ShowOverlayGlow
local ActionButton_UpdateState = _G.ActionButton_UpdateState
local ActionButton_UpdateUsable = _G.ActionButton_UpdateUsable
local GetActionCooldown = _G.GetActionCooldown
local assert = _G.assert
local ceil = _G.ceil
local CreateFrame = _G.CreateFrame
local floor = _G.floor
local format = _G.format
local GetSpellCooldown = _G.GetSpellCooldown
local GetTime = _G.GetTime
local IsSpellOverlayed = _G.IsSpellOverlayed
local IsUsableAction = _G.IsUsableAction
local IsUsableSpell = _G.IsUsableSpell
local min = _G.min
local next = _G.next
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local strmatch = _G.strmatch
local tostring = _G.tostring
local type = _G.type
local unpack = _G.unpack
--GLOBALS>

------------------------------------------------------------------------------
-- LibSharedMedia
------------------------------------------------------------------------------
local LSM = LibStub('LibSharedMedia-3.0')

------------------------------------------------------------------------------
-- Local reference to addon settings
------------------------------------------------------------------------------
local profile = addon.db and addon.db.profile
LibStub('AceEvent-3.0').RegisterMessage('InlineAura/Display.lua', 'InlineAura_ProfileChanged',function() profile = addon.db.profile end)

------------------------------------------------------------------------------
-- Home-made bucketed timers
------------------------------------------------------------------------------
-- This is mainly a simplified version of AceTimer-3.0, credits goes to Ace3 authors

local ScheduleTimer, CancelTimer
do
	local assert, type, next, floor, GetTime = assert, type, next, floor, GetTime
	local BUCKETS = 131
	local HZ = 20
	local buckets = {}
	local targets = {}
	for i = 1, BUCKETS do buckets[i] = {} end
	local frame = CreateFrame("Frame")
	frame:Hide()

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
		frame:Show()
	end

	function CancelTimer(target)
		assert(target)
		local bucketNum = targets[target]
		if bucketNum then
			buckets[bucketNum][target] = nil
			targets[target] = nil
			if not next(targets) then
				frame:Hide()
			end
		end
	end

	frame:SetScript('OnUpdate', function()
		local now = GetTime()
		local newIndex = floor(now*HZ)
		for index = lastIndex + 1, newIndex do
			local bucketNum = 1 + (index % BUCKETS)
			local bucket = buckets[bucketNum]
			for target, when in next, bucket do
				if when <= now then
					bucket[target] = nil
					targets[target] = nil
					target:OnUpdate(now)
				end
			end
		end
		lastIndex = newIndex
		if not next(targets) then
			frame:Hide()
		end
	end)
end

------------------------------------------------------------------------------
-- Base fontstring widget
------------------------------------------------------------------------------

local baseProto = setmetatable({}, { __index = CreateFrame("Frame"):CreateFontString() })
local baseMeta = { __index = baseProto }

function baseProto:Initialize(button)
	self.button = button
	self:SetAllPoints(button)
	return self:ApplySettings()
end

--@debug@
function baseProto:Debug(...)
	return self.button:Debug(...)
end
--@end-debug@

function baseProto:SetPosition(position)
	if position ~= self.position then
		self.position = position
		self:SetJustifyH(strmatch(position, 'LEFT') or strmatch(position, 'RIGHT') or 'MIDDLE')
		self:SetJustifyV(strmatch(position, 'TOP') or strmatch(position, 'BOTTOM') or 'CENTER')
	end
end

function baseProto:ApplySettings()
	self.font = LSM:Fetch(LSM.MediaType.FONT, profile.fontName)
	self.fontFlag = profile.fontFlag
	self.fontSize = profile[self.sizeKey]
	self.fontColor = profile[self.colorKey]
	return self:UpdateFont()
end

function baseProto:UpdateFont()
	self:SetFont(self.font, self.fontSize, self.fontFlag)
	self:SetTextColor(unpack(self.fontColor))
end

function baseProto:SetValue(value)
	if value ~= self.value then
		self.value = value
		--@debug@
		self:Debug('SetValue', value)
		--@end-debug@
		return self:_SetValue(value)
	end
end

------------------------------------------------------------------------------
-- Countdown text widget
------------------------------------------------------------------------------

local countdownProto = setmetatable({}, baseMeta)
local countdownMeta = { __index = countdownProto }

countdownProto.colorKey = "colorCountdown"
countdownProto.sizeKey = "largeFontSize"

function countdownProto:UpdateFont()
	local fontSize, r, g, b = self:getFontSize()
	self:SetTextColor(r, g, b)
	self:SetFont(self.font, fontSize, self.fontFlag)
	local overflowRatio = self:GetStringWidth() / (self:GetParent():GetWidth()-4)
	if overflowRatio > 1 then
		return self:SetFont(self.font, fontSize / overflowRatio, self.fontFlag)
	end
end

function countdownProto:ApplySettings()
	self.sizeKey = addon.bigCountdown and "largeFontSize" or "smallFontSize"
	self.getCountdownText = profile.preciseCountdown and self.GetPreciseCountdownText or self.GetImpreciseCountdownText
	self.decimalThreshold = profile.decimalCountdownThreshold
	self.getFontSize = profile.dynamicCountdownColor and self.GetDynamicFontSize or self.GetStaticFontSize
	return baseProto.ApplySettings(self)
end

function countdownProto:_SetValue(value)
	if not value then
		self:Hide()
		CancelTimer(self)
		self.timeLeft = nil
	else
		self:Show()
		self:OnUpdate(GetTime())
	end
end

function countdownProto:OnUpdate(now)
	local timeLeft = self.value - now
	if timeLeft <= 0 then
		return self:SetValue(nil)
	end
	self.timeLeft = timeLeft
	local displayTime, delay = self:getCountdownText()
	self:SetText(displayTime)
	self:UpdateFont()
	ScheduleTimer(self, min(delay, timeLeft))
end

-- Countdown formatting

function countdownProto:GetPreciseCountdownText()
	local timeLeft = self.timeLeft
	if timeLeft >= 3600 then
		return format(L["%dh"], floor(timeLeft/3600)), 1 + floor(timeLeft) % 3600
	elseif timeLeft >= 600 then
		return format(L["%dm"], floor(timeLeft/60)), 1 + floor(timeLeft) % 60
	elseif timeLeft >= 60 then
		return format("%d:%02d", floor(timeLeft/60), floor(timeLeft%60)), timeLeft % 1
	elseif timeLeft >= self.decimalThreshold then
		return tostring(floor(timeLeft)), timeLeft % 1
	elseif timeLeft > 0 then
		return format("%.1f", floor(timeLeft*10)/10), 0
	else
		return "0", 0
	end
end

function countdownProto:GetImpreciseCountdownText()
	local timeLeft = self.timeLeft
	if timeLeft >= 3600 then
		return format(L["%dh"], ceil(timeLeft/3600)), ceil(timeLeft) % 3600
	elseif timeLeft >= 60 then
		return format(L["%dm"], ceil(timeLeft/60)), ceil(timeLeft) % 60
	elseif timeLeft > 0 then
		return tostring(floor(timeLeft)), timeLeft % 1
	else
		return "0", 0
	end
end

-- Size and color modifiers

local dynamicModifiers = {
	-- { font scale, r, g, b }
	{ 1.3, 1, 0, 0 }, -- soon
	{ 1.0, 1, 1, 0 }, -- in less than a minute
	{ 0.8, 1, 1, 1 }, -- in more than a minute
}

function countdownProto:GetDynamicFontSize()
	local timeLeft = self.timeLeft
	if timeLeft then
		local phase = (timeLeft <= 5 and 1) or (timeLeft <= 60 and 2) or 3
		local scale, r, g, b = unpack(dynamicModifiers[phase])
		return self.fontSize * scale, r, g, b
	end
	return self:GetStaticFontSize()
end

function countdownProto:GetStaticFontSize()
	return self.fontSize, unpack(self.fontColor)
end

------------------------------------------------------------------------------
-- Stack text widget
------------------------------------------------------------------------------

local stackProto = setmetatable({}, baseMeta)
local stackMeta = { __index = stackProto }

stackProto.colorKey = "colorStack"
stackProto.sizeKey = "smallFontSize"

function stackProto:_SetValue(value)
	if value then
		self:SetFormattedText("%d", value)
		return self:Show()
	else
		return self:Hide()
	end
end

------------------------------------------------------------------------------
-- Widget registries
------------------------------------------------------------------------------

local overlays = setmetatable({}, { __index = function(t, button)
	--@debug@
	button:Debug("Spawning overlay")
	--@end-debug@
	local overlay = CreateFrame("Frame", nil, button)
	local cooldown = _G[button:GetName()..'Cooldown']
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + 5)
	overlay:SetAllPoints(cooldown)
	t[button] = overlay
	return overlay
end})

local countdowns = {}
local stacks = {}

local function GetWidget(button, spawn, registry, key, meta)
	local widget = registry[button]
	if not widget and spawn then
		--@debug@
		button:Debug("Spawning", key)
		--@end-debug@
		local overlay = overlays[button]
		widget = setmetatable(overlay:CreateFontString(nil, "OVERLAY"), meta)
		widget:Initialize(button)
		overlay[key] = widget
		registry[button] = widget
	end
	return widget
end

local function GetCountdown(button, spawn)
	return GetWidget(button, spawn, countdowns, "countdown", countdownMeta)
end

local function GetStack(button, spawn)
	return GetWidget(button, spawn, stacks, "stack", stackMeta)
end

------------------------------------------------------------------------------
-- Text feedback
------------------------------------------------------------------------------

local function UpdateTextLayout(countdown, stack)
	if countdown and not countdown:IsShown() then
		countdown = nil
	end
	if stack and not stack:IsShown() then
		stack = nil
	end
	if countdown and stack then
		countdown:SetPosition(profile.twoTextFirstPosition)
		stack:SetPosition(profile.twoTextSecondPosition)
	elseif countdown or stack then
		(countdown or stack):SetPosition(profile.singleTextPosition)
	end
end

function addon.ShowCountdownAndStack(button, expirationTime, count)
	local countdown = GetCountdown(button, expirationTime)
	if countdown then
		countdown:SetValue(expirationTime)
	end
	local stack = GetStack(button, count)
	if stack then
		stack:SetValue(count)
	end
	button:Debug("ShowCountdownAndStack", expirationTime, count, "=>", countdown, stack)
	if stack or countdown then
		return UpdateTextLayout(countdown, stack)
	end
end

function addon:UpdateWidgets()
	for button, widget in pairs(countdowns) do
		widget:ApplySettings()
	end
	for button, widget in pairs(stacks) do
		widget:ApplySettings()
	end
	for button, overlay in pairs(overlays) do
		UpdateTextLayout(overlay.countdown, overlay.stack)
	end
end

------------------------------------------------------------------------------
-- Vertex color setter
------------------------------------------------------------------------------

local function SetVertexColor(texture, r, g, b, a)
	return texture:SetVertexColor(r, g, b, a)
end

-- LibButtonFacade compatibility
function addon:HasLibButtonFacade()
	SetVertexColor = function(texture, r, g, b, a)
		local R, G, B, A = texture:GetVertexColor()
		return texture:SetVertexColor(r*R, g*G, b*B, a*(A or 1))
	end
end

------------------------------------------------------------------------------
-- Highlight feedback
------------------------------------------------------------------------------

local function IsUsable(state)
	local usable, noPower = state:IsUsablestate()
	return usable or noPower
end

local function IsOnCooldown(state)
	local start, duration, enable = state:GetCooldown()
	return enable ~= 0 and start ~= 0 and duration > 1.5
end

function addon:UpdateButtonHighlight(button, event)
	local state = self.buttons[button]
	local highlight, action, spellId = state.highlight, button.action, state.spellId

	-- Glowing
	if (spellId and IsSpellOverlayed(spellId)) or (
		highlight == "glowing"
		and (profile.glowOutOfCombat or addon.inCombat)
		and (profile.glowUnusable or IsUsable(state))
		and (profile.glowOnCooldown or not IsOnCooldown(state))
	) then
		if button.overlay then
			if button.overlay.animOut:IsPlaying() then
				button.overlay.animOut:Stop()
			end
		else
			ActionButton_ShowOverlayGlow(button)
		end
		-- Small hack to prevent ugly glitches
		local animIn = button.overlay.animIn
		if not animIn:IsPlaying() then
			animIn:GetScript('OnFinished')(animIn)
		end
	elseif button.overlay and not button.overlay.animOut:IsPlaying() then
		ActionButton_HideOverlayGlow(button)
	end

	-- Dim
	if highlight == "dim" then
		local name = button:GetName()
		_G[name.."Icon"]:SetVertexColor(0.4, 0.4, 0.4)
		_G[name.."NormalTexture"]:SetVertexColor(1.0, 1.0, 1.0)
	else
		state:UpdateUsable()
	end

	-- Color border
	if highlight == "border" then
		local color = profile["color"..state.highlightBorder]
		if color then
			button:SetChecked(true)
			return SetVertexColor(button:GetCheckedTexture(), unpack(color))
		end
	end
	button:GetCheckedTexture():SetVertexColor(1, 1, 1)
	state:UpdateState()
end

