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

-- Prat3.0-DibsTweaks, module "Dibs animated chat": when a new message arrives, the older
-- messages slide out of the way and the new one fades in. The work is done in Engine.lua.

local _, ns = ...

if not (Prat and Prat.AddModuleToLoad and PRAT_L and ns.Refresh) then
	return
end

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

Prat:AddModuleToLoad(function()
	ns.MoveModuleSettings("AnimatedChat", MODULE)
	local module = Prat:NewModule(MODULE)
	ns.animated = module
	local PL = module.PL

	Prat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			duration = 0.15,
			slide = true,
			fade = true,
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
		}
	})

	function module:OnModuleEnable()
		ns.Refresh()
		Prat.RegisterChatEvent(self, Prat.Events.FRAMES_UPDATED)
	end

	function module:OnModuleDisable()
		ns.Refresh()
	end

	function module:OnValueChanged()
		ns.Refresh()
	end

	function module:Prat_FramesUpdated()
		ns.Refresh()
	end
end) -- Prat:AddModuleToLoad
