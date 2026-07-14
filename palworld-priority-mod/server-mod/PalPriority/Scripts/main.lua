-- ============================================================================
-- PalPriority — server-side RimWorld-style work priorities for Palworld base pals.
-- UE4SS (Okaetsu fork) Lua mod. Palworld 1.0.
--
-- WHAT IT DOES
--   Give each base pal a 0-5 priority per work type. The supervisor tick shapes
--   each configured pal's vanilla "off list" (disabled work types) so that the
--   pal only works on its highest-priority types *that currently have pending
--   work*. Pals with no config entry are left completely untouched (vanilla).
--
-- HOW IT WORKS (mechanism, settled by in-game probing — see ../docs/callpath-map.md)
--   Direct native hooks into the assignment gate (IsExistAssignableSlot) never
--   fire, so we cannot veto assignments inline. Instead we drive the game's own
--   per-pal "off list" via the RequestChangeWorkSuitability_ToServer RPC, which is
--   the exact write path the vanilla toggle UI uses (replicated + persisted).
--
-- SAFETY
--   This runs inside someone's game. A Lua error thrown from a hook can crash the
--   game, so EVERY game-object access is wrapped in pcall, and repeated failures
--   are logged once (never in a retry loop). Prefer skip-and-log over retry.
-- ============================================================================

local VERSION = "0.6.0"

-- CYCLE_MODE: when true, a genuine user toggle on the vanilla work screen CYCLES
-- that work type's priority 0->1->2->3->4->5->0 (auto-configuring the pal on the
-- first touch). When false, fall back to the original binary semantics
-- (off -> prio 0, on -> prio 3-if-0) which is what an UNMODDED client sees, since
-- an unmodded client can only send true/false and cannot show a cycle number.
local CYCLE_MODE = true

local function log(msg)
    -- Single choke-point so the tag + newline format is consistent everywhere.
    print(string.format("[PalPriority] %s\n", msg))
end

-- Log a given message only once per tag, so degraded paths don't spam the console.
local logged = {}
local function logOnce(tag, msg)
    if logged[tag] then return end
    logged[tag] = true
    log(msg)
end

log(string.format("v%s loading...", VERSION))

-- ---------------------------------------------------------------------------
-- Work-type table (EPalWorkSuitability, 13 usable values). Confirmed in-game.
-- ---------------------------------------------------------------------------
local WORKNAME = {
    [1]  = "EmitFlame",          -- Kindling
    [2]  = "Watering",
    [3]  = "Seeding",
    [4]  = "GenerateElectricity",
    [5]  = "Handcraft",
    [6]  = "Collection",
    [7]  = "Deforest",
    [8]  = "Mining",
    [9]  = "OilExtraction",
    [10] = "ProductMedicine",
    [11] = "Cool",
    [12] = "Transport",
    [13] = "MonsterFarm",
}
local WORK_MIN, WORK_MAX = 1, 13

-- Fallback map: work object class-name substring -> work type. Used only when the
-- (unverified) GetWorkAssignInfo out-param path fails. Substring match is robust to
-- the "_C" / package-path decoration in GetFullName().
local CLASS_TYPE_MAP = {
    PalWorkTransportItemInBaseCamp = 12, -- Transport
    PalWorkDeforestFoliage         = 7,  -- Deforest
    PalWorkCollectResource         = 6,  -- Collection
}

-- ---------------------------------------------------------------------------
-- Mutable state
-- ---------------------------------------------------------------------------
local config = { pals = {} }   -- loaded from priorities.lua (see loadConfig)
local shadows = {}             -- palKey -> { [type]=true }  our belief of the pal's off-list
local pending = {}             -- workKey -> { type=int, lastSeen=os.time() }
local campComp = nil           -- captured PalNetworkBaseCampComponent used to send RPCs
local internalCall = false     -- reentrancy guard: true while WE send an RPC (see hook)
-- Modded-client attestation. The client UI mod sends a PrioMod_Dir marker just
-- before each toggle it originates; both arrive on the sender's own network
-- component, so keying by component full name (a) identifies the sender and
-- (b) prevents one player's marker being consumed by another player's toggle.
-- Components that have EVER spoken our protocol are remembered as modded.
local pendingDirByComp = {}    -- compFullName -> { dir=+1/-1, at=os.clock() } (stale after 1s)
local moddedComps = {}         -- compFullName -> os.clock() of last PrioMod_* message.
-- TTL'd because UE recycles object names: a stale entry must not classify a NEW
-- player's component as modded. Every marker/ping refreshes it, so an active
-- modded client never expires mid-session.
local MODDED_TTL_SECONDS = 600
local barHold = {}             -- palKey -> { bar=int, at=os.clock() } bar hysteresis (anti-wiggle)
local BAR_HOLD_SECONDS = 10    -- how long a higher bar persists after its pending work vanishes
local managedCache = {}        -- palKey -> { set={[t]=true}, at=os.clock() } suitability cache
local MANAGED_TTL_SECONDS = 60 -- suitabilities barely change; skip 13 reflection calls/pal/tick
local CONFIG_PATH = "Mods/PalPriority/priorities.lua" -- resolved for real at startup

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

-- CRITICAL: FGuid int32 fields come back into Lua sign-extended (e.g. -1 for
-- 0xFFFFFFFF). We must mask to unsigned 32-bit before formatting the pal key,
-- otherwise the same pal produces different keys across sessions and configs
-- never match. Lua '%' follows the divisor's sign, so -1 % 2^32 == 0xFFFFFFFF.
local function norm(v)
    return v % 0x100000000
end

-- Coerce to a Lua integer for %d formatting (engine values should already be
-- integers, but be defensive so a stray float can never abort a config save).
local function I(x)
    if math.type and math.type(x) == "integer" then return x end
    return math.floor(x + 0)
end

-- CRASH-CRITICAL: UE4SS returns a WRAPPER object (not nil) for null UObject
-- properties, and pcall CANNOT catch the native access violation caused by
-- calling a method on a null/stale wrapper (learned from a live crash). Require
-- IsValid() to affirmatively return true before ANY member call on ANY received
-- object. IsValid() itself is safe on null/stale wrappers.
local function alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

-- FString/FName property values arrive either as a plain Lua string or as a
-- userdata with :ToString(). Normalize both, return nil on failure.
local function fstr(x)
    if x == nil then return nil end
    if type(x) == "string" then return x end
    local ok, s = pcall(function() return x:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

-- Iterate a UE4SS TArray (or a plain Lua array as a degenerate fallback).
-- UE4SS ForEach hands each element as a RemoteUnrealParam -> :get(); we unwrap
-- it so callers always receive the underlying value/struct. Everything is
-- pcall-guarded; runtime shape of these arrays is UNVERIFIED, so we degrade to
-- a numeric loop, then to nothing, rather than throw.
local function arrayForEach(arr, fn)
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
    -- Fallback: numeric indexing. Try TArray:GetArrayNum() first (the '#'
    -- operator is not implemented for TArray userdata in all UE4SS builds),
    -- then plain '#' for Lua tables (the GetWorkAssignInfo out-param case).
    local ok2 = pcall(function()
        local n = nil
        pcall(function() n = arr:GetArrayNum() end)
        if n == nil then n = #arr end
        for i = 1, n do fn(arr[i]) end
    end)
    return ok2
end

-- Build the canonical, session-stable pal key from the two FGuids.
-- Two 32-hex-char halves (PlayerUId, InstanceId) joined by '-'. Normalized.
local function palKey(playerUId, instanceId)
    return string.format("%08X%08X%08X%08X-%08X%08X%08X%08X",
        norm(playerUId.A), norm(playerUId.B), norm(playerUId.C), norm(playerUId.D),
        norm(instanceId.A), norm(instanceId.B), norm(instanceId.C), norm(instanceId.D))
end

-- Pull the RAW (unnormalized, possibly negative) A/B/C/D ints from a live
-- FPalInstanceID. These are what we must pass back into the RPC verbatim — the
-- normalized values are ONLY for building table keys.
local function extractRaw(id)
    return {
        PlayerUId  = { A = id.PlayerUId.A,  B = id.PlayerUId.B,  C = id.PlayerUId.C,  D = id.PlayerUId.D },
        InstanceId = { A = id.InstanceId.A, B = id.InstanceId.B, C = id.InstanceId.C, D = id.InstanceId.D },
    }
end

-- Stable key for a pending work object: prefer its FGuid WorkId, fall back to
-- Lua object identity so we never fail to record a job.
local function workKey(w)
    local ok, key = pcall(function()
        local g = w:GetWorkId()
        return string.format("%08X%08X%08X%08X", norm(g.A), norm(g.B), norm(g.C), norm(g.D))
    end)
    if ok and key then return key end
    return tostring(w)
end

-- ---------------------------------------------------------------------------
-- Config load / save
-- ---------------------------------------------------------------------------

-- Header re-emitted on every save so the format doc survives rewrites (a save
-- regenerates the file and cannot preserve hand-written comments in the body).
local CONFIG_HEADER = [==[
-- PalPriority config. Auto-managed: the mod REWRITES this file when you toggle a
-- work type in-game on a configured pal, so hand-written comments inside the
-- pals table will not survive. Edit priorities freely; keep the structure below.
--
-- FORMAT
--   return {
--     pals = {
--       ["<palkey>"] = {
--         name = "display name",         -- optional, cosmetic only
--         prio = { [8]=5, [12]=1 },      -- [worktype]=priority (0-5); missing => 0
--         raw  = { PlayerUId={A,B,C,D}, InstanceId={A,B,C,D} }, -- identity, do not edit
--       },
--     },
--   }
--
-- PRIORITY: 0 = never do this work. 1-5 = higher wins. A pal only works its
--   highest-priority types that currently have pending work.
-- WORK TYPES: 1 EmitFlame(Kindling) 2 Watering 3 Seeding 4 GenerateElectricity
--   5 Handcraft 6 Collection 7 Deforest 8 Mining 9 OilExtraction
--   10 ProductMedicine 11 Cool 12 Transport 13 MonsterFarm
--
-- Press F9 in-game to print every base pal's key + a ready-to-paste skeleton entry.
]==]

-- Serialize the config table back to Lua source (deterministic key order).
local function serializeConfig(cfg)
    local out = {}
    out[#out + 1] = CONFIG_HEADER
    out[#out + 1] = "return {\n  pals = {\n"

    local keys = {}
    for k in pairs(cfg.pals) do keys[#keys + 1] = k end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local e = cfg.pals[k]
        out[#out + 1] = string.format("    [%q] = {\n", k)
        if e.name then
            out[#out + 1] = string.format("      name = %q,\n", e.name)
        end

        -- prio, sorted by work type
        local pk = {}
        for t in pairs(e.prio or {}) do pk[#pk + 1] = t end
        table.sort(pk)
        local pparts = {}
        for _, t in ipairs(pk) do
            pparts[#pparts + 1] = string.format("[%d]=%d", I(t), I(e.prio[t]))
        end
        out[#out + 1] = "      prio = { " .. table.concat(pparts, ", ") .. " },\n"

        -- raw identity (only if present)
        local r = e.raw
        if r and r.PlayerUId and r.InstanceId then
            out[#out + 1] = string.format(
                "      raw = { PlayerUId = { A=%d, B=%d, C=%d, D=%d }, InstanceId = { A=%d, B=%d, C=%d, D=%d } },\n",
                I(r.PlayerUId.A), I(r.PlayerUId.B), I(r.PlayerUId.C), I(r.PlayerUId.D),
                I(r.InstanceId.A), I(r.InstanceId.B), I(r.InstanceId.C), I(r.InstanceId.D))
        end
        out[#out + 1] = "    },\n"
    end

    out[#out + 1] = "  },\n}\n"
    return table.concat(out)
end

-- Parse + validate a config file. Returns (table) or (nil, errmsg).
local function loadConfig(path)
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    local text = f:read("*a")
    f:close()

    local chunk, perr = load(text, "@" .. path)
    if not chunk then return nil, "parse error: " .. tostring(perr) end
    local ok, result = pcall(chunk)
    if not ok then return nil, "exec error: " .. tostring(result) end
    if type(result) ~= "table" then return nil, "config did not return a table" end
    if type(result.pals) ~= "table" then result.pals = {} end

    -- Sanitize: drop malformed entries, ensure prio table exists.
    for k, e in pairs(result.pals) do
        if type(e) ~= "table" then
            result.pals[k] = nil
        else
            if type(e.prio) ~= "table" then e.prio = {} end
        end
    end
    return result
end

-- Write config to disk. Atomic-ish: temp file then rename; fall back to a direct
-- rewrite if the temp/rename path fails (Windows rename needs the target gone).
local function saveConfig(cfg)
    local ok, text = pcall(serializeConfig, cfg)
    if not ok then
        log("saveConfig: serialize failed: " .. tostring(text))
        return false
    end

    local tmp = CONFIG_PATH .. ".tmp"
    local tf = io.open(tmp, "w")
    if tf then
        tf:write(text)
        tf:close()
        pcall(os.remove, CONFIG_PATH)        -- Windows os.rename won't clobber
        local renamed = os.rename(tmp, CONFIG_PATH)
        if renamed then
            log("config saved -> " .. CONFIG_PATH)
            return true
        end
        pcall(os.remove, tmp)                -- rename failed; clean up and fall through
    end

    -- Fallback: direct rewrite.
    local df = io.open(CONFIG_PATH, "w")
    if not df then
        log("saveConfig FAILED: cannot open " .. CONFIG_PATH .. " for writing")
        return false
    end
    df:write(text)
    df:close()
    log("config saved (direct rewrite) -> " .. CONFIG_PATH)
    return true
end

-- Try a few likely relative locations so the mod works regardless of exactly
-- where UE4SS sets the cwd. Returns the first path that opens for read, else the
-- primary path (used for writing; startup logs the resolved outcome).
local function resolveConfigPath()
    local candidates = {
        "Mods/PalPriority/priorities.lua",
        "ue4ss/Mods/PalPriority/priorities.lua",
        "priorities.lua",
    }
    for _, p in ipairs(candidates) do
        local f = io.open(p, "r")
        if f then
            f:close()
            return p, true
        end
    end
    return candidates[1], false
end

-- ---------------------------------------------------------------------------
-- Pending-work tracking
-- ---------------------------------------------------------------------------

-- Drop pending entries not refreshed within 15s. The assign hook re-fires for a
-- job every few seconds while it stays unfilled; once filled/gone it stops, so
-- a stale entry means the work no longer needs a worker.
local function prunePending(now)
    for k, e in pairs(pending) do
        if now - e.lastSeen > 15 then pending[k] = nil end
    end
end

local function countPendingByType()
    local c = {}
    for _, e in pairs(pending) do
        if e.type then c[e.type] = (c[e.type] or 0) + 1 end
    end
    return c
end

local function classNameOf(w)
    local ok, name = pcall(function() return w:GetClass():GetFullName() end)
    if ok then return name end
    return nil
end

local function typeFromClassName(name)
    if not name then return nil end
    for sub, t in pairs(CLASS_TYPE_MAP) do
        if name:find(sub, 1, true) then return t end
    end
    return nil
end

-- Determine the work type of a pending work object.
-- Cheap class-name map FIRST (covers the high-frequency classes with one string
-- scan); only unknown classes pay for the GetWorkAssignInfo attempt, which is
-- UNVERIFIED at runtime and observed to fail (a thrown pcall per call) — no
-- reason to eat that cost on every transport-spam event.
local function getWorkType(w)
    local name = classNameOf(w)
    local ct = typeFromClassName(name)
    if ct then return ct end

    local found = nil
    pcall(function()
        local outArr = {}
        -- Some UE4SS builds populate the passed table; others return the array.
        -- Accept whichever gives us usable data.
        local ret = w:GetWorkAssignInfo(outArr)
        local arr = ret
        if arr == nil then arr = outArr end
        arrayForEach(arr, function(entry)
            if found then return end
            local ok, suit = pcall(function()
                local wa = entry.WorkAssign
                return wa:GetWorkSuitability()
            end)
            if ok and type(suit) == "number" and suit >= WORK_MIN and suit <= WORK_MAX then
                found = suit
            end
        end)
    end)
    if found then return found end

    -- Unknown class: record it once WITH its identifying plain-value properties
    -- (FName/enum — safe reads, no object refs), so real observed values can be
    -- added to the map. PalWorkProgress (generic station work) lands here today,
    -- which blinds pendingByType to station jobs — the map grows from these logs.
    if name then
        local extra = ""
        pcall(function()
            local aid = fstr(w.AssignDefineDataId)
            if aid then extra = extra .. " assignId=" .. aid end
        end)
        pcall(function()
            extra = extra .. " workType=" .. tostring(w.OverrideWorkType)
        end)
        logOnce("unkclass:" .. name .. extra,
            "unmapped work class (skipping): " .. name .. extra)
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Enumeration of directors / pals
-- ---------------------------------------------------------------------------

-- Read a pal's display name for logging. NickName > CharacterID > DebugName > "?".
local function displayName(id, param)
    local nm = nil
    pcall(function()
        if param then
            local sp = param.SaveParameter
            nm = fstr(sp.NickName)
            if not nm or #nm == 0 then
                nm = fstr(sp.CharacterID)
            end
        end
    end)
    if not nm or #nm == 0 then
        pcall(function() nm = fstr(id.DebugName) end)
    end
    if not nm or #nm == 0 then nm = "?" end
    return nm
end

-- Fetch the slot array from a character container. Prefer the SlotArray
-- property (plain replicated property — most reliable access path in UE4SS);
-- fall back to the GetSlots() by-value function return, which some UE4SS
-- builds cannot marshal.
local function getSlotsArray(container)
    local arr = nil
    pcall(function() arr = container.SlotArray end)
    if arr ~= nil then return arr, "SlotArray" end
    pcall(function() arr = container:GetSlots() end)
    return arr, "GetSlots()"
end

-- Walk one director's character container, invoking cb(handle, id, param) for
-- each occupied slot. param may be nil. Everything pcall-guarded — a bad slot
-- skips rather than throws. `stats` (optional table) collects per-step counts
-- so the F9 dump can pinpoint where the chain breaks instead of failing silent.
local function enumerateDir(dir, cb, stats)
    local s = stats or {}
    pcall(function()
        if not alive(dir) then
            s.noContainer = (s.noContainer or 0) + 1
            return
        end
        local container = dir.CharacterContainer
        if not alive(container) then
            s.noContainer = (s.noContainer or 0) + 1
            return
        end
        local slots, src = getSlotsArray(container)
        s.slotSource = src
        if not slots then
            s.noSlots = (s.noSlots or 0) + 1
            return
        end
        arrayForEach(slots, function(slot)
            s.slots = (s.slots or 0) + 1
            pcall(function()
                -- alive() (strict IsValid) everywhere: empty slots hold NULL-WRAPPER
                -- handles that are ~= nil but crash natively on any member call.
                if not alive(slot) then
                    s.nilSlot = (s.nilSlot or 0) + 1
                    return
                end
                local handle = slot.Handle
                if handle == nil then
                    s.noHandle = (s.noHandle or 0) + 1
                    return
                end
                if not alive(handle) then
                    s.invalid = (s.invalid or 0) + 1
                    return
                end
                local id = handle:GetIndividualID()
                if id == nil then
                    s.noId = (s.noId or 0) + 1
                    return
                end
                local param = handle:TryGetIndividualParameter() -- may be nil
                if not alive(param) then param = nil end
                s.ok = (s.ok or 0) + 1
                cb(handle, id, param)
            end)
        end)
    end)
end

-- Find a live base pal by its canonical key, by scanning every worker director.
-- Returns (id, param) or (nil, nil). The cycle-mode toggle handler uses this to
-- (a) auto-configure a freshly touched pal (needs param for HasWorkSuitability +
-- off-list read) and (b) reconcile that pal immediately (reconcilePal needs param).
-- The hook hands us an FPalInstanceID, but not the UPalIndividualCharacterParameter
-- behind it, so we must go find the param via the director walk we already have.
local function findPalByKey(key)
    local foundId, foundParam = nil, nil
    local dirs = nil
    pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
    if not dirs then return nil, nil end
    for _, dir in ipairs(dirs) do
        if foundParam then break end
        enumerateDir(dir, function(_, id, param)
            if foundParam then return end
            local ok, k = pcall(function() return palKey(id.PlayerUId, id.InstanceId) end)
            if ok and k == key then
                foundId, foundParam = id, param
            end
        end)
    end
    return foundId, foundParam
end

-- ---------------------------------------------------------------------------
-- The write lever: send one off-list toggle via the vanilla RPC.
-- bOn == true  -> enable the type (remove from off-list)
-- bOn == false -> disable the type (add to off-list)
-- ---------------------------------------------------------------------------
local function sendToggle(raw, t, bOn)
    -- Revalidate the cached component every send: it can be GC'd/recreated on
    -- level transitions, and calling into a stale wrapper is a native crash.
    if campComp and not alive(campComp) then campComp = nil end
    local comp = campComp or FindFirstOf("PalNetworkBaseCampComponent")
    if not alive(comp) then
        logOnce("nocomp", "no PalNetworkBaseCampComponent available yet — cannot send RPC")
        return false
    end
    campComp = comp
    local ok, err = pcall(function()
        -- Reentrancy: our own RPC re-enters the RequestChangeWorkSuitability hook
        -- synchronously (listen-server ProcessEvent), so flag it to be ignored.
        internalCall = true
        comp:RequestChangeWorkSuitability_ToServer(
            { PlayerUId = raw.PlayerUId, InstanceId = raw.InstanceId, DebugName = "" },
            t, bOn)
        internalCall = false
    end)
    internalCall = false -- ensure cleared even if the call threw
    if not ok then
        logOnce("rpcfail", "RPC RequestChangeWorkSuitability failed: " .. tostring(err))
        return false
    end
    return true
end

-- Read the game's ACTUAL stored off-list for a pal. Returns (set, okFlag).
-- This is ground truth — the reconciler re-reads it every tick rather than
-- trusting our own write history, so any drift (a write the game rejected, a
-- change we never saw) self-heals within one tick instead of persisting.
local function readOffList(param)
    local sh = {}
    local ok = pcall(function()
        local lst = param.SaveParameter.WorkSuitabilityOptionInfo.OffWorkSuitabilityList
        arrayForEach(lst, function(v)
            if type(v) == "number" then sh[v] = true end
        end)
    end)
    return sh, ok
end

-- Legacy wrapper (auto-config + dump callers): read, warn once on failure.
local function initShadow(key, param)
    local sh, ok = readOffList(param)
    if not ok then
        logOnce("shadow:" .. key, "could not read off-list for " .. key .. " (assuming empty)")
    end
    return sh
end

-- ---------------------------------------------------------------------------
-- Supervisor: reconcile one configured pal toward its desired enabled set.
-- ---------------------------------------------------------------------------
local function reconcilePal(id, param, pendingByType)
    if not param then return end
    local key = palKey(id.PlayerUId, id.InstanceId)
    local cfg = config.pals[key]
    if not cfg then return end -- unconfigured pals stay fully vanilla

    -- Keep raw identity fresh from the live pal (authoritative over the file).
    local okr, raw = pcall(extractRaw, id)
    if not okr then return end
    cfg.raw = raw

    -- managed = types this pal can actually do (cached: suitabilities barely
    -- change, and this is 13 reflection calls per pal otherwise — F8 clears it);
    -- eligible = managed AND prio>=1 (recomputed each tick from plain Lua state).
    local nowC = os.clock()
    local mc = managedCache[key]
    local managed
    if mc and (nowC - mc.at) < MANAGED_TTL_SECONDS then
        managed = mc.set
    else
        managed = {}
        for t = WORK_MIN, WORK_MAX do
            local okh, has = pcall(function() return param:HasWorkSuitability(t) end)
            if okh and has then managed[t] = true end
        end
        managedCache[key] = { set = managed, at = nowC }
    end
    local eligible = {}
    for t in pairs(managed) do
        local p = cfg.prio[t] or 0
        if p >= 1 then eligible[t] = p end
    end

    -- Among eligible types that have pending work, find the max priority (the bar).
    local maxp = nil
    for t, p in pairs(eligible) do
        if (pendingByType[t] or 0) > 0 then
            if not maxp or p > maxp then maxp = p end
        end
    end

    -- ANTI-WIGGLE 1: the pal's CURRENT assignment counts as pending for it. The
    -- event-based pending tracker only sees UNFILLED jobs — the moment this pal
    -- takes the last transport job, transport stops "pending", the bar collapses,
    -- and lower-priority types reopen mid-task. Counting the active job keeps the
    -- bar up while the pal is actually doing high-priority work.
    pcall(function()
        local cur = param:GetCurrentWorkSuitability()
        if type(cur) == "number" and eligible[cur] then
            if not maxp or eligible[cur] > maxp then maxp = eligible[cur] end
        end
    end)

    -- ANTI-WIGGLE 2: hysteresis. A bar only drops after BAR_HOLD_SECONDS of
    -- genuinely nothing at that level — bridging the seconds between finishing
    -- one job and the next "need a worker" event, which otherwise flip-flops
    -- lower-priority types every tick.
    local now = os.clock()
    local hold = barHold[key]
    if maxp ~= nil then
        if hold == nil or maxp >= hold.bar or (now - hold.at) >= BAR_HOLD_SECONDS then
            barHold[key] = { bar = maxp, at = now }
        else
            maxp = hold.bar -- recent higher bar still holds
        end
    else
        if hold and (now - hold.at) < BAR_HOLD_SECONDS then
            maxp = hold.bar
        else
            barHold[key] = nil
        end
    end

    -- desiredEnabled: if nothing pending, allow all eligible; otherwise only the
    -- eligible types at/above the bar.
    local desiredEnabled = {}
    if maxp == nil then
        for t in pairs(eligible) do desiredEnabled[t] = true end
    else
        for t, p in pairs(eligible) do
            if p >= maxp then desiredEnabled[t] = true end
        end
    end

    -- Reconcile the pal's off-list against desiredEnabled, but only for types the
    -- pal can do (never touch irrelevant types). Diff against the game's ACTUAL
    -- off-list (fresh read — see readOffList) so drift cannot persist; fall back
    -- to the cached shadow only if the read fails.
    local sh, okRead = readOffList(param)
    if okRead then
        shadows[key] = sh
    else
        sh = shadows[key]
        if not sh then
            sh = initShadow(key, param)
            shadows[key] = sh
        end
    end

    for t in pairs(managed) do
        local wantOff = not desiredEnabled[t] -- disable everything not desired-enabled
        local isOff = (sh[t] == true)
        if wantOff and not isOff then
            if sendToggle(cfg.raw, t, false) then
                sh[t] = true
                log(string.format("delta [%s] %s DISABLE", cfg.name or key, WORKNAME[t] or ("type" .. t)))
            end
        elseif (not wantOff) and isOff then
            if sendToggle(cfg.raw, t, true) then
                sh[t] = nil
                log(string.format("delta [%s] %s ENABLE", cfg.name or key, WORKNAME[t] or ("type" .. t)))
            end
        end
    end
end

-- The tick body. Runs ON the game thread (invoked via ExecuteInGameThread).
local function tickBody()
    -- Nothing configured -> the supervisor has nothing to manage. Skip the
    -- director enumeration (a global object scan) entirely.
    if next(config.pals) == nil then return end

    local now = os.time()
    prunePending(now)
    local pendingByType = countPendingByType()

    local dirs = nil
    local okd = pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
    if not okd or not dirs then return end
    for _, dir in ipairs(dirs) do
        enumerateDir(dir, function(_, id, param)
            reconcilePal(id, param, pendingByType)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- F9 roster dump
-- ---------------------------------------------------------------------------
local function skeletonEntry(key, name, id)
    local okr, raw = pcall(extractRaw, id)
    if not okr then
        return string.format('-- ["%s"] = { name = "%s", prio = {}, raw = {} },', key, name)
    end
    return string.format(
        '-- ["%s"] = { name = "%s", prio = {}, raw = { PlayerUId = { A=%d, B=%d, C=%d, D=%d }, InstanceId = { A=%d, B=%d, C=%d, D=%d } } },',
        key, name,
        I(raw.PlayerUId.A), I(raw.PlayerUId.B), I(raw.PlayerUId.C), I(raw.PlayerUId.D),
        I(raw.InstanceId.A), I(raw.InstanceId.B), I(raw.InstanceId.C), I(raw.InstanceId.D))
end

local function dumpRoster()
    local ok, err = pcall(function()
        log("=== ROSTER DUMP ===")
        local now = os.time()
        prunePending(now)
        local pendingByType = countPendingByType()

        local psum = {}
        for t = WORK_MIN, WORK_MAX do
            local c = pendingByType[t] or 0
            if c > 0 then psum[#psum + 1] = (WORKNAME[t] or ("type" .. t)) .. "=" .. c end
        end
        log("pending work: " .. (#psum > 0 and table.concat(psum, ", ") or "(none)"))

        local dirs = nil
        pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
        if not dirs then
            log("no directors found (are you in a base?)")
            log("=== END DUMP ===")
            return
        end

        local skeletons = {} -- key -> commented entry, de-duplicated
        local di = 0
        for _, dir in ipairs(dirs) do
            di = di + 1
            log(string.format("-- director #%d --", di))
            local stats = {}
            enumerateDir(dir, function(_, id, param)
                local key = palKey(id.PlayerUId, id.InstanceId)
                local name = displayName(id, param)
                local cfg = config.pals[key]
                if cfg then
                    log(string.format("  %s  %s", key, name))

                    -- Full priority row over every type the pal can actually do
                    -- (including explicit 0s — those are the disables).
                    local managed, eligible, prioParts = {}, {}, {}
                    for t = WORK_MIN, WORK_MAX do
                        local has = false
                        if param then
                            pcall(function() has = param:HasWorkSuitability(t) end)
                        end
                        if has then
                            managed[t] = true
                            local p = cfg.prio[t] or 0
                            prioParts[#prioParts + 1] =
                                string.format("%s=%d", WORKNAME[t] or ("type" .. t), p)
                            if p >= 1 then eligible[t] = p end
                        end
                    end
                    log("    prio: " .. (#prioParts > 0
                        and table.concat(prioParts, " ") or "(no suitabilities readable)"))

                    -- The supervisor's CURRENT decision, computed exactly like
                    -- reconcilePal: which pending type sets the bar, and what
                    -- the desired enable/disable split is right now.
                    local maxp, maxsrc = nil, nil
                    for t, p in pairs(eligible) do
                        if (pendingByType[t] or 0) > 0 and (not maxp or p > maxp) then
                            maxp, maxsrc = p, t
                        end
                    end
                    local cur = nil
                    if param then
                        pcall(function() cur = param:GetCurrentWorkSuitability() end)
                    end
                    local hold = barHold[key]
                    local en, dis = {}, {}
                    for t in pairs(managed) do
                        local p = cfg.prio[t] or 0
                        local want = p >= 1 and (maxp == nil or p >= maxp)
                        if want then en[#en + 1] = WORKNAME[t] else dis[#dis + 1] = WORKNAME[t] end
                    end
                    table.sort(en); table.sort(dis)
                    log(string.format(
                        "    plan: bar=%s%s cur=%s hold=%s | want-on {%s} | want-off {%s}",
                        tostring(maxp), maxsrc and (" via " .. WORKNAME[maxsrc]) or "",
                        (type(cur) == "number" and WORKNAME[cur]) or "none",
                        hold and string.format("%d(%.0fs)", hold.bar, os.clock() - hold.at) or "none",
                        table.concat(en, ","), table.concat(dis, ",")))

                    -- Ground truth vs our belief: the game's actual stored off-list
                    -- (fresh read) against the shadow the reconciler diffs with.
                    -- A MISMATCH here means deltas are being computed off bad state.
                    local gameOff = param and initShadow(key, param) or {}
                    local sh = shadows[key] or {}
                    local offParts, shParts, mismatch = {}, {}, false
                    for t = WORK_MIN, WORK_MAX do
                        if gameOff[t] then offParts[#offParts + 1] = WORKNAME[t] end
                        if sh[t] then shParts[#shParts + 1] = WORKNAME[t] end
                        if (gameOff[t] == true) ~= (sh[t] == true) then mismatch = true end
                    end
                    log(string.format("    off-list game {%s} | shadow {%s}%s",
                        table.concat(offParts, ","), table.concat(shParts, ","),
                        mismatch and "  << MISMATCH (shadow drift)" or ""))
                else
                    log(string.format("  %s  %s  (unconfigured)", key, name))
                    skeletons[key] = skeletonEntry(key, name, id)
                end
            end, stats)
            -- Diagnostic line: shows how far the enumeration chain got, so an
            -- empty roster tells us WHICH link failed instead of failing silent.
            log(string.format(
                "  [diag] src=%s slots=%d noContainer=%d noSlots=%d nilSlot=%d noHandle=%d invalid=%d noId=%d ok=%d",
                tostring(stats.slotSource), stats.slots or 0, stats.noContainer or 0,
                stats.noSlots or 0, stats.nilSlot or 0, stats.noHandle or 0,
                stats.invalid or 0, stats.noId or 0, stats.ok or 0))
        end

        if next(skeletons) ~= nil then
            log("-- unconfigured pals: paste into priorities.lua under pals = { ... } and uncomment --")
            for _, s in pairs(skeletons) do
                log("  " .. s)
            end
        end
        log("=== END DUMP ===")
    end)
    if not ok then log("F9 dump error: " .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

-- (A) Pending-work intake. Fires every few seconds per unfilled job.
local okA, errA = pcall(function()
    RegisterHook("/Script/Pal.PalBaseCampWorkerDirector:OnRequiredAssignWork_ServerInternal",
        function(Context, Work, RequirementParameter)
            local ok, err = pcall(function()
                local w = Work:get()
                if not w then return end
                -- The same unfilled job re-fires every few seconds. If we already
                -- know it, just refresh its timestamp — skip type resolution
                -- (the expensive part) entirely for repeat events.
                local wk = workKey(w)
                local e = pending[wk]
                if e then
                    e.lastSeen = os.time()
                    return
                end
                local t = getWorkType(w)
                if not t then return end -- unknown class already logged once
                pending[wk] = { type = t, lastSeen = os.time() }
            end)
            if not ok then logOnce("assignhook", "OnRequiredAssignWork handler error: " .. tostring(err)) end
        end)
end)
log(okA and "HOOK OK OnRequiredAssignWork_ServerInternal"
    or ("HOOK FAILED OnRequiredAssignWork_ServerInternal: " .. tostring(errA)))

-- (B) Vanilla toggle observer + comp capture. Fires on user UI toggles AND our
-- own RPC calls (the latter are filtered by internalCall).
local okB, errB = pcall(function()
    RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:RequestChangeWorkSuitability_ToServer",
        function(Context, TargetIndividualId, WorkSuitability, bOn)
            -- Always try to capture the component — it is our RPC caller.
            pcall(function()
                if not campComp then campComp = Context:get() end
            end)
            if internalCall then return end -- ignore our own writes

            local ok, err = pcall(function()
                local id = TargetIndividualId:get()
                local work = WorkSuitability:get()
                local on = bOn:get()
                local key = palKey(id.PlayerUId, id.InstanceId)
                local cfg = config.pals[key]

                -- Determine whether this toggle came from a MODDED client: a fresh
                -- per-component PrioMod_Dir marker (the client mod attests every
                -- click it originates), or failing that a component that has spoken
                -- our protocol before (covers a marker lost to hook-order races —
                -- assume the default increment).
                local step = nil
                if CYCLE_MODE then
                    local compName = nil
                    pcall(function()
                        local c = Context:get()
                        if alive(c) then compName = c:GetFullName() end
                    end)
                    if compName then
                        local m = pendingDirByComp[compName]
                        if m and (os.clock() - m.at) < 1.0 then
                            step = m.dir
                            pendingDirByComp[compName] = nil
                        else
                            local seen = moddedComps[compName]
                            if seen and (os.clock() - seen) < MODDED_TTL_SECONDS then
                                step = 1
                            end
                        end
                    end
                end

                if step == nil then
                    -- UNMODDED source (vanilla checkboxes, or CYCLE_MODE off):
                    -- bypass mod cycling entirely. Unconfigured pals stay pure
                    -- vanilla. A configured pal touched by a vanilla client (e.g.
                    -- the player uninstalled the client mod) is RELEASED: restore
                    -- its off-list to the binary reading of its priorities (0 ->
                    -- off, 1-5 -> on) so lingering supervisor shaping is undone,
                    -- keep the toggle the user just made as-is, then forget the
                    -- pal — its checkboxes are plain vanilla from here on.
                    if not cfg then return end

                    local fid, fparam = findPalByKey(key)
                    if fparam then
                        local offNow = readOffList(fparam)
                        local raw = cfg.raw
                        if not raw then
                            local okr, r = pcall(extractRaw, fid)
                            if okr then raw = r end
                        end
                        if raw then
                            for t = WORK_MIN, WORK_MAX do
                                if t ~= work then -- the user's own toggle stands
                                    local has = false
                                    pcall(function() has = fparam:HasWorkSuitability(t) end)
                                    if has then
                                        local wantOn = (cfg.prio[t] or 0) >= 1
                                        local isOn = not offNow[t]
                                        if wantOn ~= isOn then
                                            sendToggle(raw, t, wantOn)
                                        end
                                    end
                                end
                            end
                        end
                    end

                    config.pals[key] = nil
                    shadows[key] = nil
                    barHold[key] = nil
                    managedCache[key] = nil
                    saveConfig(config)
                    log(string.format(
                        "released [%s]: unattested toggle — pal returned to vanilla on/off",
                        cfg.name or key))
                    return
                end

                -- MODDED cycle path ---------------------------------------------
                -- Locate the live pal. Needed for auto-config (HasWorkSuitability +
                -- off-list) and for the immediate reconcile below. If we can't find
                -- it, this isn't a base pal we manage -> stay fully vanilla.
                local fid, fparam = findPalByKey(key)

                if not cfg then
                    if not fparam then return end -- not a base pal -> ignore toggle
                    -- Auto-configure on first touch. Read the pal's current off-list
                    -- (same logic as initShadow) and seed every work type it can do:
                    -- enabled -> 3, disabled -> 0. NOTE: the vanilla click already
                    -- flipped `work`'s off-list state before this hook ran, so `work`
                    -- is seeded from its post-click state; the cycle below then
                    -- advances it and the reconcile re-asserts the visual.
                    local offList = initShadow(key, fparam)
                    local prio = {}
                    local nInit = 0
                    for t = WORK_MIN, WORK_MAX do
                        local okh, has = pcall(function() return fparam:HasWorkSuitability(t) end)
                        if okh and has then
                            prio[t] = offList[t] and 0 or 3
                            nInit = nInit + 1
                        end
                    end
                    cfg = { name = displayName(fid or id, fparam), prio = prio }
                    local okr, raw = pcall(extractRaw, fid or id)
                    if okr then cfg.raw = raw end
                    config.pals[key] = cfg
                    shadows[key] = offList -- seed shadow from what we just read
                    log(string.format("auto-config [%s]: %d work type(s) initialized",
                        cfg.name or key, nInit))
                end

                -- Advance the priority one step: 0->1->2->3->4->5->0, or the
                -- reverse for a -1 marker (right-click). Lua's % handles the
                -- negative wrap (0-1 -> 5).
                local new = ((cfg.prio[work] or 0) + step) % 6

                -- Mirror the toggle the game just applied into our shadow, so the
                -- reconcile only sends the delta needed to reach the cycled state.
                -- (We do NOT trust `on` for the priority itself — only for logging.)
                local sh = shadows[key]
                if sh then
                    if on == false then sh[work] = true else sh[work] = nil end
                end

                cfg.prio[work] = new
                saveConfig(config) -- persist the edit back to priorities.lua
                log(string.format("cycle [%s] %s -> %d",
                    cfg.name or key, WORKNAME[work] or ("type" .. work), new))

                -- Immediate reconcile of just this pal so the checkbox visual snaps
                -- to the new state without waiting for the 3s supervisor tick. We are
                -- already on the game thread inside this hook. reconcilePal -> sendToggle
                -- sets internalCall while it re-enters this very hook (listen-server
                -- synchronous ProcessEvent); that nested call is filtered above.
                if fparam then
                    pcall(function()
                        reconcilePal(fid or id, fparam, countPendingByType())
                    end)
                end
            end)
            if not ok then logOnce("togglehook", "toggle handler error: " .. tostring(err)) end
        end)
end)
log(okB and "HOOK OK RequestChangeWorkSuitability_ToServer"
    or ("HOOK FAILED RequestChangeWorkSuitability_ToServer: " .. tostring(errB)))

-- (C) Reserved custom transport for the future UI mod (client -> server).
local okC, errC = pcall(function()
    RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:Request_Server_int32",
        function(Context, BaseCampId, FunctionName, Value)
            local ok, err = pcall(function()
                local name = FunctionName:get():ToString()
                if type(name) ~= "string" then return end
                if name:sub(1, 8) ~= "PrioMod_" then return end -- ignore everything else silently

                -- ANY PrioMod_* message marks the sending component as a modded
                -- client — its toggles are then eligible for cycle semantics.
                local compName = nil
                pcall(function()
                    local c = Context:get()
                    if alive(c) then compName = c:GetFullName() end
                end)
                if compName then moddedComps[compName] = os.clock() end

                if name == "PrioMod_Ping" then
                    log(string.format("PrioMod_Ping received (value=%d) — client mod announced%s",
                        Value:get(), compName and (" on " .. compName) or ""))
                    return
                end

                if name == "PrioMod_Dir" then
                    -- Direction marker for the toggle that immediately follows
                    -- (+1 left-click, -1 right-click). Clamp to ±1; stale after 1s.
                    if compName then
                        local v = Value:get()
                        pendingDirByComp[compName] = {
                            dir = (v and v < 0) and -1 or 1,
                            at = os.clock(),
                        }
                    end
                    return
                end

                -- TODO: set-priority protocol. Planned encoding (client -> server):
                --   FunctionName = "PrioMod_SetPrio", Value packs work-type + priority,
                --   with the target pal identified via a preceding Request_Server_* call
                --   or an FGuid transport. Decode here, update config.pals[key].prio,
                --   reset that pal's shadow, then saveConfig(config). Left as a stub so
                --   the wire format is decided together with the client mod.
                logOnce("prio:" .. name, "unimplemented PrioMod command: " .. name .. " (TODO)")
            end)
            if not ok then logOnce("transporthook", "Request_Server_int32 handler error: " .. tostring(err)) end
        end)
end)
log(okC and "HOOK OK Request_Server_int32"
    or ("HOOK FAILED Request_Server_int32: " .. tostring(errC)))

-- ---------------------------------------------------------------------------
-- Keybinds
-- ---------------------------------------------------------------------------

-- F8: reload priorities.lua, reset shadows so the next tick reshapes from scratch.
pcall(function()
    RegisterKeyBind(Key.F8, function()
        local ok, err = pcall(function()
            local cfg, lerr = loadConfig(CONFIG_PATH)
            if not cfg then
                log("F8 reload FAILED: " .. tostring(lerr))
                return
            end
            config = cfg
            shadows = {} -- forget beliefs; next tick re-reads off-lists and reshapes
            managedCache = {} -- re-read suitabilities too (rank-ups, new pals)
            local n = 0
            for _ in pairs(config.pals) do n = n + 1 end
            log(string.format("F8 reloaded: %d pal(s) configured; shadows reset", n))
        end)
        if not ok then log("F8 error: " .. tostring(err)) end
    end)
end)

-- F9: dump the roster (keys, names, priorities, pending) + paste-ready skeletons.
pcall(function()
    RegisterKeyBind(Key.F9, function()
        dumpRoster()
    end)
end)

-- ---------------------------------------------------------------------------
-- Supervisor loop
-- ---------------------------------------------------------------------------
-- LoopAsync runs its callback OFF the game thread, so all game-object access is
-- hopped onto the game thread via ExecuteInGameThread. In UE4SS, LoopAsync keeps
-- looping while the callback returns false — so we return false here.
pcall(function()
    LoopAsync(3000, function()
        local ok, err = pcall(function()
            ExecuteInGameThread(function()
                local okt, errt = pcall(tickBody)
                if not okt then logOnce("tick", "tick error: " .. tostring(errt)) end
            end)
        end)
        if not ok then logOnce("loop", "LoopAsync error: " .. tostring(err)) end
        return false -- keep looping
    end)
end)

-- ---------------------------------------------------------------------------
-- Startup: resolve + load config, report state.
-- ---------------------------------------------------------------------------
do
    local resolved, found = resolveConfigPath()
    CONFIG_PATH = resolved
    log(string.format("config path: %s (%s)", CONFIG_PATH, found and "found" or "NOT found on disk"))

    local cfg, lerr = loadConfig(CONFIG_PATH)
    if cfg then
        config = cfg
        local n = 0
        for _ in pairs(config.pals) do n = n + 1 end
        log(string.format("config loaded: %d pal(s) configured", n))
    else
        config = { pals = {} }
        log("config load failed (" .. tostring(lerr) .. ") — starting with empty config")
    end
end

log(string.format("v%s ready. Supervisor tick 3s. Keys: F8 reload, F9 dump roster.", VERSION))
