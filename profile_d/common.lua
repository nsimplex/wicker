--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.profile_d.common
-- Note        : 
-- 
-- Defines a wrapper function for profile definitions which performs a set of
-- common tasks.
-- 
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Common constants
--------------------------------------------------------------------------------

-- | Kernel modules to be loaded by every profile.
local COMMON_MODULES = {

}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The exported API and its utility functions
--------------------------------------------------------------------------------

-- |
-- attach_postinit :: (b -> IO ()), (a -> b)) -> a -> IO b
--
-- See:
-- https://hackage.haskell.org/package/base-4.8.2.0/docs/Control-Exception-Base.html#v:bracket
local function attach_postinit(ioer, f)
    local function handle_retvals(...)
        ioer(...)
        return ...
    end

    return function(...)
        return handle_retvals(f(...))
    end
end

local RAN = false

local function kernel_postinit()
    if RAN then return end

    for i = 1, #COMMON_MODULES do
        local modulename = COMMON_MODULES[i]
        modprobe(modulename)
    end

    RAN = true
end

local function MakeProfile(profile_body)
    return coroutine.create(function(resume_kernel)
        local do_resume_kernel = attach_postinit(kernel_postinit, resume_kernel)
        return profile_body(do_resume_kernel)
    end)
end

---

return MakeProfile
