local assert = assert
local _K = assert( _K )

--- 

local table = assert( table )
local ipairs = assert( ipairs )
local unpack = assert( unpack )

---

local cleanup_fns = {}
local final_cleanup_fns = {}

---

local function AddCleanup(fn)
    table.insert(cleanup_fns, fn)
end

AddFinalCleanup = function(fn)
    table.insert(final_cleanup_fns, 1, fn)
end

local function NewVariableCleanupAdder(basic_adder)
    local function var_adder(...)
        local names = {...}
        basic_adder(function(env)
            for _, name in ipairs(names) do
                env[name] = nil
            end
        end)
        return var_adder
    end
    return var_adder
end

local AddVariableCleanup = NewVariableCleanupAdder(AddCleanup)
local AddFinalVariableCleanup = NewVariableCleanupAdder(AddFinalCleanup)

local function PerformCleanup()
    for _, fn in ipairs(cleanup_fns) do
        fn(_K)
    end
    for _, fn in ipairs(final_cleanup_fns) do
        fn(_K)
    end
    cleanup_fns = nil
    final_cleanup_fns = nil

    PerformCleanup = function() end
end


_K.AddCleanup = AddCleanup
_K.AddFinalCleanup = AddFinalCleanup
_K.AddVariableCleanup = AddVariableCleanup
_K.AddFinalVariableCleanup = AddFinalVariableCleanup
_K.PerformCleanup = PerformCleanup

AddFinalVariableCleanup
    "AddCleanup"
    "AddFinalCleanup"
    "AddVariableCleanup"
    "AddFinalVariableCleanup"
    "PerformCleanup"
