-- Helpers used by both halves of the mod. Previously duplicated across two
-- separate mods on purpose; once they ship as one mod that no longer earns
-- anything.
--
-- CRASH RULES (see ../../../docs/callpath-map.md — these are why the mod does
-- not crash players):
--   * alive() before EVERY member call on EVERY received object. UE4SS returns a
--     wrapper, not nil, for null UObject properties, and pcall cannot catch the
--     native AV from calling a method on one.
--   * Never read a SoftObjectProperty.
--   * Never call GetWorkAssignInfo.

local S = {}

S.DEBUG = false     -- set from main.lua
S.VERBOSE = false

function S.log(msg)
    print(string.format("[PalPriority] %s\n", msg))
end

function S.vlog(msg)
    if S.VERBOSE or S.DEBUG then S.log(msg) end
end

local logged = {}
function S.logOnce(tag, msg)
    if logged[tag] then return end
    logged[tag] = true
    S.log(msg)
end

function S.clearLogOnce()
    logged = {}
end

-- pcall(f, arg) allocates nothing; pcall(function() ... end) allocates a fresh
-- closure on EVERY call. These four run thousands of times per enumeration
-- burst — alive() most of all — so the closure form was this mod's largest
-- source of game-thread GC churn, which is exactly what micro-stutter is made
-- of. Crash semantics are unchanged: the member LOOKUP as well as the call
-- still happens inside the protected call.
local function _isValid(o) return o:IsValid() end
local function _toString(o) return o:ToString() end
local function _fullName(o) return o:GetFullName() end
local function _className(o) return o:GetClass():GetFName():ToString() end

function S.alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(_isValid, obj)
    return ok and v == true
end

function S.fstr(x)
    if x == nil then return nil end
    if type(x) == "string" then return x end
    local ok, s = pcall(_toString, x)
    if ok and type(s) == "string" then return s end
    return nil
end

-- FGuid int32 fields arrive sign-extended; mask to unsigned 32-bit or the same
-- pal produces different keys across sessions. Lua '%' follows the divisor sign.
function S.norm(v)
    return v % 0x100000000
end

function S.I(x)
    if math.type and math.type(x) == "integer" then return x end
    return math.floor(x + 0)
end

function S.guidStr(g)
    return string.format("%08X%08X%08X%08X",
        S.norm(g.A), S.norm(g.B), S.norm(g.C), S.norm(g.D))
end

function S.palKey(playerUId, instanceId)
    return S.guidStr(playerUId) .. "-" .. S.guidStr(instanceId)
end

-- Name + the first 4 hex of the InstanceId half. The PlayerUId half is all
-- zeros for base pals and unnamed pals display their species id, so two
-- same-species pals are otherwise indistinguishable in logs.
function S.palLabel(name, key)
    return string.format("%s/%s", name or "?",
        (key and #key >= 37) and key:sub(34, 37) or "?")
end

function S.classNameOf(obj)
    local ok, name = pcall(_className, obj)
    if ok and type(name) == "string" then return name end
    return nil
end

function S.fullNameOf(obj)
    if not S.alive(obj) then return nil end
    local ok, n = pcall(_fullName, obj)
    if ok and type(n) == "string" then return n end
    return nil
end

function S.isDefaultObject(fullName)
    return type(fullName) == "string" and fullName:find("Default__", 1, true) ~= nil
end

-- UE4SS ForEach hands each element as a RemoteUnrealParam -> :get(). Runtime
-- shape is unverified, so degrade to a numeric loop, then to nothing.
--
-- Only for SMALL, STABLE arrays (the pal SlotArray — months in production).
-- UE4SS source (2026-07-26, docs/callpath-map.md "Director & work internals"):
-- ForEach carries an author-acknowledged unfixed crash on large arrays, so
-- churny game-owned queues must not come through here.
function S.arrayForEach(arr, fn)
    if arr == nil then return false end
    local ok = pcall(function()
        arr:ForEach(function(_, elem)
            local v = elem
            local okg, got = pcall(function() return elem:get() end)
            if okg then v = got end
            fn(v)
        end)
    end)
    if ok then return true end
    local ok2 = pcall(function()
        local n = nil
        pcall(function() n = arr:GetArrayNum() end)
        if n == nil then n = #arr end
        -- 0-based, 0..n-1: UE4SS TArray indexing passes the index straight
        -- through to the C++ side, and an index >= Num() is not a failed read —
        -- it calls AddZeroed on the LIVE game array. The old 1..n walk would
        -- have grown the array by one on its last iteration had this fallback
        -- ever actually run.
        for i = 0, n - 1 do fn(arr[i]) end
    end)
    return ok2
end

-- This mod's own directory, derived from package.path (UE4SS seeds it with each
-- mod's Scripts dir), so file access does not depend on the game's cwd.
function S.modDir()
    local dir = nil
    pcall(function()
        for entry in string.gmatch(package.path or "", "[^;]+") do
            local base = entry:match("^(.*[/\\]Mods[/\\]PalPriority)[/\\]Scripts[/\\]%?%.lua$")
            if base then
                dir = base
                break
            end
        end
    end)
    return dir
end

return S
