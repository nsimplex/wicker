--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.hooks
-- Note        : 
-- 
-- Adds postinit-style hooks to user/mod loading itself.
-- 
--------------------------------------------------------------------------------

local user_postinits = {}

function RunUserPostInits()
    if not TheUser then return end

    TheUser:DebugSay("Running mod post inits...")

    for i = 1, #user_postinits do
        local f = user_postinits[i]
        f(TheUser)
    end

    user_postinits = {}
end
local RunUserPostInits = RunUserPostInits
RunModPostInits = RunUserPostInits

-- Runs after TheUser has been instantiated.
function AddUserPostInit(f)
    user_postinits[#user_postinits + 1] = f
    RunUserPostInits()
end
AddModPostInit = AddUserPostInit
