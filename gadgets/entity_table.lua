--[[
-- Creates tables indexes by entities.
--
-- The entries are automatically cleaned when the entity is removed.
--]]


local Pred = wickerrequire "lib.predicates"


local function new_entity_table(onclear)
    local inner_t = {}

    local ClearEntry
    if onclear then
        ClearEntry = function(inst)
            onclear(inst)
            inner_t[inst] = nil
        end
    else
        ClearEntry = function(inst)
            inner_t[inst] = nil
        end
    end

    local function SetInstEntry(t, inst, v)
        assert( Pred.IsEntityScript(inst), "EntityScript expected as index!" )

        local oldv = inner_t[inst]

        if oldv ~= nil and v == nil then
            inst:RemoveEventCallback("onremove", ClearEntry)
            ClearEntry(inst)
            return
        end

        if oldv == nil and v ~= nil then
            inst:ListenForEvent("onremove", ClearEntry)
        end

        inner_t[inst] = v
    end

    local next = next
    local function proxy_next(t, k)
        return next(inner_t, k)
    end

    local pairs = pairs
    local function proxy_pairs(t)
        return pairs(inner_t)
    end

    return setmetatable({}, {
        __index = inner_t,
        __newindex = SetInstEntry,
        __next = proxy_next,
        __pairs = proxy_pairs,
    })
end


return new_entity_table
