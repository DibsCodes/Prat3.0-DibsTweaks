-------------------------------------------------------------------------------
-- Prat3.0-DibsTweaks
-- Copyright (C) 2026 DibsCodes
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

-- Prat3.0-DibsTweaks, module "Dibs animated chat": animates chat windows. It needs no changes
-- to Prat's own files.
--   * When a new message arrives, the older messages slide out of the way and the new one
--     fades in.
--   * Text hangs from the top of the window: the first message appears on the top line and
--     later ones go under it. When the oldest message has faded out on the chat fade timer,
--     the others move up. Once the text fills the window, chat scrolls as usual.
--
-- Target: Forever. Checked against Gethe/wow-ui-source forever branch, commit
-- 9dc84f0d3bbae1768ac3405b3716000bd93eda06 (1.60.1.70862):
--   Blizzard_SharedXML/ScrollingMessageFrame.lua: the frame draws its messages with a
--     chain of FontStrings in frame.visibleLines. Line 1 is the newest message and is
--     anchored to the frame's bottom (or top, in top insert mode); every other line is
--     anchored to the line before it. Offsetting line 1 therefore moves all of them.
--     A line's fade-out alpha depends only on its message's timestamp
--     (CalculateLineAlphaValueFromTimestamp), so it can be worked out for any line.
--   Blizzard_SharedXML/ScrollingMessageFrame.xml: the lines live in a container with
--     clipChildren, so a line pushed past the frame edge is cut off, not drawn outside.
--     The frame's own update (OnPostUpdate) runs after any OnUpdate script.

local _, ns = ...

if not (Prat and Prat.AddModuleToLoad and PRAT_L) then
	return
end

local INSERT_TOP = SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP

-- Also the name shown in Prat's Module Control.
local MODULE = "Dibs animated chat"

-- Prat reads module text from PRAT_L and raises an error for any missing key.
PRAT_L[MODULE .. "/module_name"] = "Dibs animated chat"
PRAT_L[MODULE .. "/module_desc"] = "Slides older chat messages out of the way and fades new ones in."
PRAT_L[MODULE .. "/duration_name"] = "Animation Time"
PRAT_L[MODULE .. "/duration_desc"] = "How long the animation takes, in seconds."
PRAT_L[MODULE .. "/slide_name"] = "Slide Old Messages"
PRAT_L[MODULE .. "/slide_desc"] = "Slide the older messages to make room for a new one."
PRAT_L[MODULE .. "/fade_name"] = "Fade In New Messages"
PRAT_L[MODULE .. "/fade_desc"] = "Fade new messages in."
PRAT_L[MODULE .. "/top_name"] = "Keep Text At The Top"
PRAT_L[MODULE .. "/top_desc"] = "Show messages from the top of the window downwards. When the oldest message fades out, the others move up."

Prat:AddModuleToLoad(function()
	ns.MoveModuleSettings("AnimatedChat", MODULE)
	local module = Prat:NewModule(MODULE)
	local PL = module.PL

	Prat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			duration = 0.15,
			slide = true,
			fade = true,
			top = true,
		}
	})

	Prat:SetModuleOptions(module.name, {
		name = PL.module_name,
		desc = PL.module_desc,
		type = "group",
		args = {
			duration = {
				name = PL.duration_name,
				desc = PL.duration_desc,
				type = "range",
				order = 110,
				min = 0.05,
				max = 0.5,
				step = 0.01,
			},
			slide = {
				name = PL.slide_name,
				desc = PL.slide_desc,
				type = "toggle",
				order = 120,
			},
			fade = {
				name = PL.fade_name,
				desc = PL.fade_desc,
				type = "toggle",
				order = 130,
			},
			top = {
				name = PL.top_name,
				desc = PL.top_desc,
				type = "toggle",
				order = 140,
			},
		}
	})

	-- A message that sat in a hidden tab is not "new" when the tab is shown again.
	local MAX_MESSAGE_AGE = 0.5
	-- Stands for "the window was empty" as the last seen newest message.
	local EMPTY = {}

	local enabled = false
	-- Per chat frame:
	--   head       newest message last seen while scrolled to the newest
	--   from, t    slide: start distance and elapsed time
	--   fades      message entry -> fade-in start time
	--   lift       how far the text is raised so that it starts at the top of the window
	local states = {}

	-- The room a line takes up in the chain, or nil if the client restricts the value.
	local function GetLineStep(line)
		local height = line:GetStringHeight()
		-- Never do arithmetic on a restricted value.
		if type(height) ~= "number" or (issecretvalue and issecretvalue(height)) then
			return nil
		end
		return height + line:GetSpacing()
	end

	local function SetLineOffset(frame, line, offset)
		if frame:GetInsertMode() == INSERT_TOP then
			line:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, offset)
		else
			line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -offset)
		end
	end

	--[[------------------------------------------------
		Text at the top
	------------------------------------------------]] --

	-- In top insert mode the text already starts at the top.
	local function CanLift(frame)
		return module.db.profile.top
			and frame:GetInsertMode() ~= INSERT_TOP
			and frame.CanEffectivelyFade
			and frame.CalculateLineAlphaValueFromTimestamp
			and frame.overrideFadeTimestamp
	end

	-- The empty room above the messages that are showing (negative if they do not all fit),
	-- and how many are showing. A message counts until the chat frame's fade timer has
	-- faded it out completely; with "ignoreFade" every message counts. Returns nil if the
	-- text is not kept at the top, or if the client restricts the text height.
	local function GetRoom(frame, now, ignoreFade)
		if not CanLift(frame) then
			return nil
		end
		local canFade = not ignoreFade and frame:CanEffectivelyFade()
		local room = frame:GetHeight()
		local shown = 0
		for i, line in ipairs(frame.visibleLines) do
			local info = line.messageInfo
			if not info then
				break
			end
			if canFade and frame:CalculateLineAlphaValueFromTimestamp(now, math.max(info.timestamp, frame.overrideFadeTimestamp)) <= 0 then
				break
			end
			local step = GetLineStep(line)
			if not step then
				return nil
			end
			room = room - step
			shown = i
			if room <= 0 then
				break
			end
		end
		return room, shown
	end

	-- How far to raise the text so that it starts at the top of the window: nothing once
	-- the text fills the window.
	local function GetLift(frame, now)
		local room, shown = GetRoom(frame, now)
		if not room then
			return 0, 0
		end
		return math.max(room, 0), shown
	end

	--[[------------------------------------------------
		Scrolling back
	------------------------------------------------]] --

	-- With the text at the top, scrolling back further than "the oldest message is on the
	-- top line" would only push messages out of the window. state.topOffset is the scroll
	-- position of that point once it is known; it holds while state.topKey is unchanged.

	local function GetLayoutKey(frame)
		return frame:GetNumMessages() .. ":" .. #frame.visibleLines .. ":" .. frame:GetWidth() .. ":" .. frame:GetHeight()
	end

	-- Runs after every change of the scroll position, before the frame is drawn.
	local function OnScrollOffsetSet(frame, state)
		local top = state.topOffset
		if top and frame:GetScrollOffset() > top and state.topKey == GetLayoutKey(frame) and CanLift(frame) then
			frame:SetScrollOffset(top)
		end
	end

	-- Runs when the frame has rewritten its lines. Finds the furthest allowed scroll
	-- position and brings the frame back to it. Message heights are only known for lines
	-- that are on screen, so this can take a few frames the first time. The move itself is
	-- left to Tick (state.pendingOffset): the frame forgets a redraw requested from here.
	local function LimitScroll(frame, state)
		local key = GetLayoutKey(frame)
		if state.topKey ~= key then
			state.topKey, state.topOffset = key, nil
		end

		local offset = frame:GetScrollOffset()
		-- "settling": this position was set from here, while looking for the top.
		local settling = state.settling == offset
		state.settling = nil
		if not settling then
			state.climbing = nil
		end

		local now = GetTime()
		if offset == 0 then
			-- All text fits in the window: there is nothing to scroll back to.
			local room = GetRoom(frame, now, true)
			if room and room >= 0 then
				state.topOffset = 0
			end
			return
		end

		local room = GetRoom(frame, now)
		local line = frame.visibleLines[1]
		local minStep = line and line:GetLineHeight() + line:GetSpacing()
		if not room or not minStep or minStep <= 0 then
			return
		end

		if room < 0 then
			if settling or state.topOffset == offset then
				-- Came down too far: the oldest message is cut off. Go back up one.
				state.topOffset = nil
				state.settling, state.climbing = offset + 1, true
				state.pendingOffset = offset + 1
			end
		elseif room < minStep or (settling and state.climbing) then
			-- No further message fits below: this is the furthest allowed position.
			state.topOffset = offset
		elseif state.topOffset ~= offset then
			-- Empty room below: come down by as many one-line messages as would fit.
			local target = math.max(offset - math.floor(room / minStep), 0)
			state.settling = target
			state.pendingOffset = target
		end
	end

	--[[------------------------------------------------
		Animation
	------------------------------------------------]] --

	-- How far the lines are still away from their final place (ease-out). Positive means
	-- they are coming from the side of the newest message.
	local function GetSlideOffset(state, duration)
		if not state.from or state.t >= duration then
			return 0
		end
		local remaining = 1 - state.t / duration
		return state.from * remaining * remaining * remaining
	end

	-- Starts a slide over "shift", added to a slide that is still running, so that a burst
	-- of messages stays smooth.
	local function StartSlide(frame, state, shift)
		local frameHeight = frame:GetHeight()
		state.from = Clamp(GetSlideOffset(state, module.db.profile.duration) + shift, -frameHeight, frameHeight)
		state.t = 0
		state.justStarted = true
		state.active = true
	end

	local function Apply(frame, state)
		local lines = frame.visibleLines
		local duration = module.db.profile.duration
		local active = false

		if lines[1] then
			local offset = GetSlideOffset(state, duration)
			if offset ~= 0 then
				active = true
			else
				state.from = nil
			end
			SetLineOffset(frame, lines[1], offset - state.lift)
		end

		-- Fading lines are the newest ones, so they are always first in the list.
		local now = GetTime()
		for i = 1, #lines do
			local line = lines[i]
			local start = line.messageInfo and state.fades[line.messageInfo]
			if not start then
				break
			end
			local progress = (now - start) / duration
			if progress < 1 then
				line:SetAlpha(progress)
				active = true
			else
				line:SetAlpha(1)
				state.fades[line.messageInfo] = nil
			end
		end

		state.active = active
	end

	-- While messages are fading out: when one is gone, move the rest up.
	local function UpdateLift(frame, state)
		if not CanLift(frame) then
			return
		end
		local now = GetTime()
		local fading = frame:CanEffectivelyFade() and now >= frame.oldestFadingLineTimestamp + frame:GetTimeVisible()
		-- One extra pass after the last line finished fading.
		local wasFading = state.wasFading
		state.wasFading = fading
		if not (fading or wasFading) then
			return
		end
		local lift = GetLift(frame, now)
		if lift ~= state.lift then
			StartSlide(frame, state, lift - state.lift)
			state.lift = lift
		end
	end

	local function Tick(frame, elapsed)
		local state = states[frame]
		if not enabled then
			return
		end
		if state.pendingOffset then
			local offset = state.pendingOffset
			state.pendingOffset = nil
			frame:SetScrollOffset(offset)
		end
		UpdateLift(frame, state)
		if not state.active then
			return
		end
		-- The frame that starts an animation already showed its first step.
		if state.justStarted then
			state.justStarted = nil
		else
			state.t = state.t + elapsed
		end
		Apply(frame, state)
	end

	local function Reset(frame, state)
		state.head = nil
		state.from = nil
		state.lift = 0
		state.active = false
		state.topOffset = nil
		state.settling = nil
		state.pendingOffset = nil
		wipe(state.fades)
		if frame.visibleLines[1] then
			SetLineOffset(frame, frame.visibleLines[1], 0)
		end
		-- Makes the frame set every line's alpha again.
		frame:MarkDisplayDirty()
	end

	-- How many lines are newer than the last seen newest message (0 if that is unclear).
	local function CountNewLines(lines, previousHead)
		for i = 1, #lines do
			local info = lines[i].messageInfo
			if info == previousHead or (not info and previousHead == EMPTY) then
				return i - 1
			elseif not info then
				break
			end
		end
		return 0
	end

	-- Runs each time the chat frame has rewritten its lines.
	local function OnDisplayRefreshed(frame)
		local state = states[frame]
		if not enabled then
			return
		end
		LimitScroll(frame, state)

		local lines = frame.visibleLines
		local newest = lines[1] and lines[1].messageInfo
		local previousHead = state.head
		-- Scrolled back: the frame keeps the view still, so there is nothing to animate.
		state.head = frame:GetScrollOffset() == 0 and (newest or EMPTY) or nil
		local headChanged = state.head ~= previousHead

		-- New lines, and the room they take up.
		local now = GetTime()
		local count, distance = 0, 0
		if previousHead and newest and state.head and now - newest.timestamp <= MAX_MESSAGE_AGE then
			count = CountNewLines(lines, previousHead)
			for i = 1, count do
				local step = GetLineStep(lines[i])
				if not step then
					-- Show such a message plainly.
					count, distance = 0, 0
					break
				end
				distance = distance + step
			end
		end

		local oldLift = state.lift
		local lift, shown = GetLift(frame, now)
		state.lift = lift

		-- "shift" is how far the lines now sit from where they should end up.
		local profile = module.db.profile
		local shift = 0
		if count > 0 then
			if profile.slide then
				shift = distance
				-- Older text is still showing: it only has to move as far as the new
				-- lines do not fit into the empty room below it.
				if shown > count then
					shift = shift + lift - oldLift
				end
			end
			if profile.fade then
				for i = 1, count do
					state.fades[lines[i].messageInfo] = now
				end
			end
			state.justStarted = true
		elseif not headChanged then
			-- Same text, but its place changed: fade timers restarted (for example by a
			-- click), the window was resized, or an option was switched.
			shift = lift - oldLift
		end

		if shift ~= 0 then
			StartSlide(frame, state, shift)
		end
		Apply(frame, state)
	end

	local function Attach(frame)
		if states[frame] then
			return
		end
		local state = { fades = setmetatable({}, { __mode = "k" }), t = 0, lift = 0 }
		states[frame] = state

		-- None of these can be removed again, so they do nothing while disabled.
		frame:AddOnDisplayRefreshedCallback(OnDisplayRefreshed)

		if type(frame.SetScrollOffset) == "function" then
			hooksecurefunc(frame, "SetScrollOffset", function(self)
				if enabled then
					OnScrollOffsetSet(self, state)
				end
			end)
		end

		-- Preferred: step right after the chat frame's own update, so its fade-out code
		-- cannot overwrite the fade-in alpha in the same frame.
		if type(frame.OnPostUpdate) == "function" then
			hooksecurefunc(frame, "OnPostUpdate", function(self, elapsed)
				state.hooked = true
				Tick(self, elapsed)
			end)
		end
		-- Fallback, in case the client does not call the hooked method.
		local driver = CreateFrame("Frame", nil, frame)
		driver:SetScript("OnUpdate", function(_, elapsed)
			if not state.hooked then
				Tick(frame, elapsed)
			end
		end)
	end

	--[[------------------------------------------------
		Module Event Functions
	------------------------------------------------]] --

	function module:OnModuleEnable()
		enabled = true
		self:AttachAllFrames()
		Prat.RegisterChatEvent(self, Prat.Events.FRAMES_UPDATED)
	end

	function module:OnModuleDisable()
		enabled = false
		for frame, state in pairs(states) do
			Reset(frame, state)
		end
	end

	-- Lets every window take up its new place when an option is switched.
	function module:OnValueChanged()
		for frame in pairs(states) do
			frame:MarkDisplayDirty()
		end
	end

	function module:Prat_FramesUpdated()
		self:AttachAllFrames()
	end

	function module:AttachAllFrames()
		for _, chatFrame in pairs(Prat.HookedFrames) do
			-- The combat log (always ChatFrame2) updates too often to animate.
			if chatFrame ~= ChatFrame2 then
				Attach(chatFrame)
				-- Makes the frame report its current newest message, so that the very
				-- next message already counts as new.
				if not states[chatFrame].head then
					chatFrame:MarkDisplayDirty()
				end
			end
		end
	end
end) -- Prat:AddModuleToLoad
