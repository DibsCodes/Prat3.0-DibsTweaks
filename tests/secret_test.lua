-- Offline test of Engine.lua with secret (instance) chat lines, using stand-ins for the
-- client. Usage, from the repo root: lua5.1 tests/secret_test.lua Engine.lua
local enginePath = assert(arg[1], "Engine.lua path")

-- A secret value: any arithmetic or comparison on it raises an error, like the client.
local SECRET = setmetatable({}, {
	__add = function() error("arithmetic on secret", 2) end,
	__sub = function() error("arithmetic on secret", 2) end,
	__lt = function() error("compare on secret", 2) end,
	__le = function() error("compare on secret", 2) end,
	__unm = function() error("arithmetic on secret", 2) end,
})
function issecretvalue(v) return v == SECRET end

local now = 0
function GetTime() return now end
function Clamp(v, lo, hi) return math.min(math.max(v, lo), hi) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc(obj, name, fn)
	local orig = obj[name]
	obj[name] = function(...) local r = orig(...); fn(...); return r end
end
function CreateFrame() return { SetScript = function() end } end
SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP = 1

local LINE_H, FRAME_H, VISIBLE, FADE = 12, 170, 10, 3

-- Lines: index 1 is the newest; line i is anchored to line i-1, so a secret line makes
-- every older line's height secret too.
local function NewLine(frame, index)
	local line = { index = index, alpha = 1 }
	function line:GetStringHeight()
		for j = 1, self.index do
			local info = frame.visibleLines[j].messageInfo
			if info and info.secret then return SECRET end
		end
		return (self.messageInfo and self.messageInfo.lines or 1) * LINE_H
	end
	function line:GetLineHeight() return LINE_H end
	function line:GetSpacing() return 0 end
	function line:SetPoint(_, _, _, _, y) self.y = y end
	function line:SetAlpha(a) self.alpha = a end
	return line
end

local frame = { visibleLines = {}, history = {}, overrideFadeTimestamp = 0, oldestFadingLineTimestamp = math.huge, scroll = 0 }
for i = 1, math.ceil(FRAME_H / LINE_H) + 1 do frame.visibleLines[i] = NewLine(frame, i) end
function frame:GetName() return "ChatFrame1" end
function frame:GetHeight() return FRAME_H end
function frame:GetWidth() return 400 end
function frame:GetInsertMode() return 0 end
function frame:CanEffectivelyFade() return true end
function frame:GetTimeVisible() return VISIBLE end
function frame:CalculateLineAlphaValueFromTimestamp(t, ts)
	local d = t - ts
	if d <= VISIBLE then return 1 end
	d = d - VISIBLE
	if d >= FADE then return 0 end
	return 1 - d / FADE
end
function frame:GetScrollOffset() return self.scroll end
function frame:SetScrollOffset(o) self.scroll = o end
function frame:GetNumMessages() return #self.history end
function frame:MarkDisplayDirty() self.dirty = true end
function frame:AddOnDisplayRefreshedCallback(cb) self.cb = cb end
function frame:OnPostUpdate(elapsed) end
function frame:Refresh()
	local oldest = math.huge
	for i, line in ipairs(self.visibleLines) do
		local info = self.history[i]
		line.messageInfo = info
		if info then
			local a = self:CalculateLineAlphaValueFromTimestamp(now, info.timestamp)
			line.alpha = a
			if a > 0 then oldest = math.min(oldest, info.timestamp) end
		end
	end
	self.oldestFadingLineTimestamp = oldest
	self.dirty = false
	if self.cb then self.cb(self) end
end
function frame:Add(secret, lines)
	table.insert(self.history, 1, { timestamp = now, secret = secret, lines = lines or 1 })
	self:Refresh()
end
local function Run(seconds)
	local steps = math.floor(seconds / 0.01 + 0.5)
	for _ = 1, steps do
		now = now + 0.01
		frame:OnPostUpdate(0.01)
		if frame.dirty then frame:Refresh() end
	end
end

-- Modules
local function Module(profile)
	local m = { db = { profile = profile }, enabled = true }
	function m:IsEnabled() return self.enabled end
	return m
end
local ns = {}
ns.animated = Module({ duration = 0.15, slide = true, fade = true })
ns.top = Module({ windows = { ChatFrame1 = true } })
Prat = { HookedFrames = { ChatFrame1 = frame } }
ChatFrame2 = {}

assert(loadfile(enginePath))("Prat3.0-DibsTweaks", ns)

local failures = 0
local function Check(label, got, want)
	local ok = math.abs(got - want) < 0.01
	print(("%s %-58s got %7.2f want %7.2f"):format(ok and "PASS" or "FAIL", label, got, want))
	if not ok then failures = failures + 1 end
end
local L = frame.visibleLines

ns.Refresh(); frame:Refresh()
-- 1. Outside instances: three messages, text kept at the top.
frame:Add(false); Run(0.5); frame:Add(false); Run(0.5); frame:Add(false); Run(0.5)
Check("normal: 3 lines kept at top (line1 y = 170 - 36)", L[1].y, FRAME_H - 3 * LINE_H)

-- 2. A secret message arrives: fades in, keep-at-top pauses (text glides to the bottom).
frame:Add(true)
Check("secret msg: fade starts at alpha 0", L[1].alpha, 0)
Check("secret msg: older text starts where it was (y = 134 - 12)", L[1].y, (FRAME_H - 3 * LINE_H) - LINE_H)
Run(0.5)
Check("secret msg: fade completes (alpha 1)", L[1].alpha, 1)
Check("secret msg: paused, text at the bottom (y = 0)", L[1].y, 0)

-- 3. Another secret message while paused: slides one line, from 12 below.
frame:Add(true)
Check("2nd secret msg: slides in from one line below (y = -12)", L[1].y, -LINE_H)
Run(0.5)
Check("2nd secret msg: settles at bottom", L[1].y, 0)

-- 4. A wrapped secret message: slides one line height (estimate).
frame:Add(true, 3)
Check("wrapped secret msg: slide uses one line (y = -12)", L[1].y, -LINE_H)
Run(0.5)

-- 5. Leave the instance (3 s later): a normal message, still paused while secret ones show.
Run(3)
frame:Add(false)
Run(0.5)
Check("after leaving: still paused while secret msgs show", L[1].y, 0)

-- 6. Secret messages fade out (last one sent 3.5 s before the normal one; visible 10 s + fade 3 s): text resumes at
-- the top. The normal message (sent 0.5 s ago at most) is still showing.
Run(11.5)
Check("secret msgs faded: resumes keep-at-top (y = 170 - 12)", L[1].y, FRAME_H - LINE_H)

-- 7. Animation only (keep-at-top off), secret message.
ns.top.enabled = false; ns.Refresh(); Run(0.5)
frame:Add(true)
Check("anim only, secret msg: starts one line below", L[1].y, -LINE_H)
Check("anim only, secret msg: alpha 0", L[1].alpha, 0)
Run(0.5)
Check("anim only, secret msg: settles", L[1].y, 0)

print(failures == 0 and "ALL PASSED" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
