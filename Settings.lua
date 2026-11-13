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

-- Prat3.0-DibsTweaks: shared helpers for the modules in this add-on.

local _, ns = ...

-- These modules used to ship as separate add-ons, under the module names "ReverseChat"
-- and "AnimatedChat". Moves their saved settings (the module's own options, and its
-- on/off state in Prat's Module Control) to the new name, once.
-- Must run before Prat:NewModule, which reads the on/off state, and before the module
-- registers its settings namespace in OnInitialize.
function ns.MoveModuleSettings(oldName, newName)
	local sv = Prat and Prat.db and Prat.db.sv
	if type(sv) ~= "table" then
		return
	end

	local namespaces = sv.namespaces
	if type(namespaces) == "table" then
		local old, new = "Prat_" .. oldName, "Prat_" .. newName
		if namespaces[old] ~= nil and namespaces[new] == nil then
			namespaces[new] = namespaces[old]
			namespaces[old] = nil
		end
	end

	-- rawget: Prat gives every module name a default state, so a plain read is never nil
	-- for the active profile.
	if type(sv.profiles) == "table" then
		for _, profile in pairs(sv.profiles) do
			local modules = type(profile) == "table" and profile.modules
			if type(modules) == "table" and rawget(modules, oldName) ~= nil and rawget(modules, newName) == nil then
				modules[newName] = rawget(modules, oldName)
				modules[oldName] = nil
			end
		end
	end
end

-- Clears a module's saved settings, in every profile, once per "version": for when a
-- module now does something different, so that it starts from its defaults again (on/off
-- included: Prat reads the module's state from these settings). The version is kept in
-- the module's settings namespace, which AceDB saves as long as it is not empty.
-- Must run before the module registers its namespace in OnInitialize.
function ns.ResetModuleSettings(name, version)
	local sv = Prat and Prat.db and Prat.db.sv
	if type(sv) ~= "table" then
		return
	end
	sv.namespaces = sv.namespaces or {}
	local key = "Prat_" .. name
	local namespace = sv.namespaces[key]
	if type(namespace) ~= "table" then
		namespace = {}
		sv.namespaces[key] = namespace
	end
	if (tonumber(namespace.dibsSettingsVersion) or 0) < version then
		namespace.profiles = nil
		namespace.dibsSettingsVersion = version
	end
end
