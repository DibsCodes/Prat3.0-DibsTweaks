-------------------------------------------------------------------------------
-- Prat3.0-DibsTweaks
-- Copyright (C) 2026 DibsCodes
--
-- The module layout follows the Prat 3.0 module template,
-- Copyright (C) 2006-2018 Prat Development Team, also under the GNU GPL.
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along with this
-- program (see LICENSE). If not, see <https://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------

-- Prat3.0-DibsTweaks, module "Dibs reverse chat": shows the newest chat messages at the top
-- of the window, using the native top insert mode of ScrollingMessageFrame. It needs no
-- changes to Prat's own files.
--
-- Target: Forever. Checked against Gethe/wow-ui-source forever branch, commit
-- 9dc84f0d3bbae1768ac3405b3716000bd93eda06 (1.60.1.70862):
--   Blizzard_SharedXML/ScrollingMessageFrame.lua: top mode draws the newest entry on
--     the top line. Scroll offset 0 is still the newest message, so "AtBottom" and
--     "ScrollToBottom" mean "at the newest message" in this mode.
--   Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua: the scroll bar and Blizzard's
--     mouse wheel handler already account for top mode. Prat's Scroll module replaces
--     that wheel handler, so the extension at the end of this file adds the same check.

local _, ns = ...

if not (Prat and Prat.AddModuleToLoad and Prat.AddModuleExtension and Prat.Addon and PRAT_L) then
	return
end

local INSERT_TOP = SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
local INSERT_BOTTOM = SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM

-- Also the name shown in Prat's Module Control.
local MODULE = "Dibs reverse chat"

-- Prat reads module text from PRAT_L and raises an error for any missing key.
PRAT_L[MODULE .. "/module_name"] = "Dibs reverse chat"
PRAT_L[MODULE .. "/module_desc"] = "Shows the newest chat messages at the top of the chat window."
PRAT_L[MODULE .. "/frames_name"] = "Reverse Windows"
PRAT_L[MODULE .. "/frames_desc"] = "Choose which chat windows show their newest messages at the top."

Prat:AddModuleToLoad(function()
	ns.MoveModuleSettings("ReverseChat", MODULE)
	local module = Prat:NewModule(MODULE)
	local PL = module.PL

	Prat:SetModuleDefaults(module.name, {
		profile = {
			on = false,
			frames = { ["*"] = true },
		}
	})

	Prat:SetModuleOptions(module.name, {
		name = PL.module_name,
		desc = PL.module_desc,
		type = "group",
		args = {
			frames = {
				name = PL.frames_name,
				desc = PL.frames_desc,
				type = "multiselect",
				order = 110,
				values = function()
					local frames = {}
					for name, title in pairs(Prat.HookedFrameList) do
						if name ~= "ChatFrame2" then
							frames[name] = title
						end
					end
					return frames
				end,
				get = "GetSubValue",
				set = "SetSubValue",
			},
		}
	})

	-- The jump button stays in its corner, but the newest message is now up, not down.
	local function SetJumpButtonFlipped(chatFrame, flipped)
		local button = chatFrame.ScrollToBottomButton
		if not button then
			return
		end

		local rotation = flipped and math.pi or 0
		button:GetNormalTexture():SetRotation(rotation)
		button:GetPushedTexture():SetRotation(rotation)
		button:GetHighlightTexture():SetRotation(rotation)
		button:GetDisabledTexture():SetRotation(rotation)
		button.Flash:SetRotation(rotation)
	end

	local function SetReversed(chatFrame, reversed)
		local insertMode = reversed and INSERT_TOP or INSERT_BOTTOM
		if chatFrame:GetInsertMode() ~= insertMode then
			chatFrame:SetInsertMode(insertMode)
			SetJumpButtonFlipped(chatFrame, reversed)
		end
	end

	--[[------------------------------------------------
		Module Event Functions
	------------------------------------------------]] --

	function module:OnModuleEnable()
		self:ConfigureAllFrames()
		Prat.RegisterChatEvent(self, Prat.Events.FRAMES_UPDATED)
		Prat.RegisterChatEvent(self, Prat.Events.FRAMES_REMOVED)
	end

	function module:OnModuleDisable()
		for _, chatFrame in pairs(Prat.HookedFrames) do
			SetReversed(chatFrame, false)
		end
	end

	function module:OnSubValueChanged()
		self:ConfigureAllFrames()
	end

	function module:Prat_FramesUpdated()
		self:ConfigureAllFrames()
	end

	-- Blizzard reuses closed temporary windows, so don't leave one reversed.
	function module:Prat_FramesRemoved(_, _, chatFrame)
		SetReversed(chatFrame, false)
	end

	--[[------------------------------------------------
		Core Functions
	------------------------------------------------]] --

	-- The combat log (always ChatFrame2) keeps its normal order. HookedFrames can include it,
	-- because IsCombatLog() returns false until Blizzard_CombatLog has loaded.
	function module:ConfigureAllFrames()
		for name, chatFrame in pairs(Prat.HookedFrames) do
			SetReversed(chatFrame, chatFrame ~= ChatFrame2 and self.db.profile.frames[name])
		end
	end
end) -- Prat:AddModuleToLoad

-- Prat's Scroll module installs a wheel handler that treats "wheel up" as "older". In top
-- insert mode older messages are below, so flip the wheel as Blizzard's own handler does.
-- This checks the frame's mode on each wheel turn, so it is correct whether or not Reverse
-- Chat is enabled. If a future Prat adds this flip itself, the wheel would be flipped twice.
Prat:AddModuleExtension(function()
	local scroll = Prat.Addon:GetModule("Scroll", true)
	if not (scroll and scroll.MouseWheel) then
		return
	end

	hooksecurefunc(scroll, "MouseWheel", function(_, chatFrame, enabled)
		local handler = enabled and chatFrame:GetScript("OnMouseWheel")
		if not handler then
			return
		end

		chatFrame:SetScript("OnMouseWheel", function(frame, delta, ...)
			if frame:GetInsertMode() == INSERT_TOP then
				delta = -delta
			end
			return handler(frame, delta, ...)
		end)
	end)

	-- Scroll may have set its handlers before this hook existed; set them again.
	if scroll.db and scroll:IsEnabled() then
		for name, chatFrame in pairs(Prat.Frames) do
			if scroll.db.profile.mousewheel[name] then
				scroll:MouseWheel(chatFrame, true)
			end
		end
	end
end) -- Prat:AddModuleExtension
