--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.auxlib
-- Note        : 
-- 
-- Misc. utilities to be included in the kernel during late bootstrapping.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local _M = _M
assert( _K == _M )

---

modprobe_init "corelib"

---

do
    local next = assert( _G.next )
    local type = assert( _G.type )
    local sbyte = assert( _G.string.byte )
    local sfind = assert( _G.string.find )
    local us = sbyte("_", 1)

    function IsPrivateString(x)
        return type(x) == "string" and sbyte(x, 1) == us
    end
    local IsPrivateString = IsPrivateString

    function IsNotPrivateString(x)
        return type(x) ~= "string" or sbyte(x, 1) ~= us
    end
    local IsNotPrivateString = IsNotPrivateString

    function IsPublicString(x)
        return type(x) == "string" and sbyte(x, 1) ~= us
    end
    local IsPublicString = IsPublicString

    local function new_conditional_iterate(p)
        return function(f, s, var)
            local function g(fs, k)
                local v = nil
                repeat
                    k, v = f(fs, k)
                until k == nil or p(k, v)
                return k, v
            end

            return g, s, var
        end
    end
    NewConditionalIterate = new_conditional_iterate

    public_iterate = new_conditional_iterate(IsPublicString)
    private_iterate = new_conditional_iterate(IsPrivateString)
    nonprivate_iterate = new_conditional_iterate(IsNotPrivateString)

    local function is_string_matching(patt)
        assert(type(patt) == "string")
        return function(k)
            return type(k) == "string" and sfind(k, patt)
        end
    end

    matched_iterate = compose(new_conditional_iterate, is_string_matching)
end

local public_iterate, private_iterate = public_iterate, private_iterate
local nonprivate_iterate = nonprivate_iterate
publicly_iterate = public_iterate
privately_iterate = private_iterate
nonprivately_iterate = nonprivately_iterate

public_pairs = compose(public_iterate, pairs)
publicpairs = public_pairs

private_pairs = compose(private_iterate, pairs)
privatepairs = private_pairs

nonprivate_pairs = compose(nonprivate_iterate, pairs)
nonprivatepairs = nonprivate_pairs

matched_pairs = function(patt)
    local do_iterate = matched_iterate(patt)
    return function(t)
        return do_iterate(pairs(t))
    end
end
matchedpairs = matched_pairs

function InjectNonPrivatesIntoTableIf(p, t, f, s, var)
    for k, v in nonprivate_iterate(f, s, var) do
        if p(k, v) then
            t[k] = v
        end
    end
    return t
end
local InjectNonPrivatesIntoTableIf = InjectNonPrivatesIntoTableIf

function InjectNonPrivatesIntoTable(t, f, s, var)
    t = InjectNonPrivatesIntoTableIf(True, t, f, s, var)
    return t
end
