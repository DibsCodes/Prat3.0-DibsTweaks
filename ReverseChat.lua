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

-- Prat3.0-DibsTweaks, module "Dibs reverse chat": in the chosen chat windows, text hangs
-- from the top of the window. The first message appears on the top line and later ones go
-- under it; when the oldest message has faded out, the others move up. The work is done
-- in Engine.lua.

local _, ns = ...

if not (Prat and Prat.AddModuleToLoad and PRAT_L and ns.Refresh) then
	return
end

-- Also the name shown in Prat's Module Control.
local MODULE = "Dibs reverse chat"

-- Prat reads module text from PRAT_L and raises an error for any missing key.
PRAT_L[MODULE .. "/module_name"] = "Dibs reverse chat"
PRAT_L[MODULE .. "/module_desc"] = "Keeps chat text at the top of the window: messages start on the top line and stack downward, and when the oldest has faded out the others move up."
PRAT_L[MODULE .. "/windows_name"] = "Keep Text At The Top"
PRAT_L[MODULE .. "/windows_desc"] = "Choose which chat windows keep their text at the top."

Prat:AddModuleToLoad(function()
	ns.MoveModuleSettings("ReverseChat", MODULE)
	-- Version 2: this module used to put the newest message on top. Settings saved for that
	-- (including "on") do not apply to keep-at-top, so it starts off again, once.
	ns.ResetModuleSettings(MODULE, 2)
	local module = Prat:NewModule(MODULE)
	ns.top = module
	local PL = module.PL

	-- "windows" is new: the earlier "frames" option chose windows for a different feature
	-- (newest message on top), so those choices are not reused.
	Prat:SetModuleDefaults(module.name, {
		profile = {
			on = false,
			windows = { ["*"] = true },
		}
	})

	Prat:SetModuleOptions(module.name, {
		name = PL.module_name,
		desc = PL.module_desc,
		type = "group",
		args = {
			windows = {
				name = PL.windows_name,
				desc = PL.windows_desc,
				type = "multiselect",
				order = 110,
				values = function()
					local frames = {}
					for name, title in pairs(Prat.HookedFrameList) do
						-- The combat log is never changed.
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

	function module:OnModuleEnable()
		ns.Refresh()
		Prat.RegisterChatEvent(self, Prat.Events.FRAMES_UPDATED)
	end

	function module:OnModuleDisable()
		ns.Refresh()
	end

	function module:OnSubValueChanged()
		ns.Refresh()
	end

	function module:Prat_FramesUpdated()
		ns.Refresh()
	end
end) -- Prat:AddModuleToLoad
