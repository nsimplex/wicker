if not IsDST() or IsWorldgen() then return end


--[[
-- This is due to a bug in PlayerController:OnRemoteLeftClick.
--
-- See this:
-- http://forums.kleientertainment.com/topic/47587-general-custom-mod-remote-left-click-action-not-working-due-to-typo/
--]]
local function PatchUnderscoreBug()
	local PlayerActionPicker = require "components/playeractionpicker"

	local function patch_bufaction(bufaction)
		if bufaction.action then
			bufaction.action_mod_name = bufaction.action.mod_name
		end
	end

	PlayerActionPicker.DoGetMouseActions = (function()
		local DoGetMouseActions = PlayerActionPicker.DoGetMouseActions
		return function(self, ...)
			local lmb, rmb = DoGetMouseActions(self, ...)
			if lmb then
				patch_bufaction(lmb)
			end
			if rmb then
				patch_bufaction(rmb)
			end
			return lmb, rmb
		end
	end)()
end

PatchUnderscoreBug()
