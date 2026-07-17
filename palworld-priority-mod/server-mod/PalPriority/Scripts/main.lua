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
--   Writes route PER-OWNER: each configured pal remembers the player whose
--   attested click manages it (cfg.owner), and its writes go through that
--   player's own network component — the same authority the vanilla UI uses
--   (guild-per-player servers silently reject writes sent through another
--   player's component). Manager offline -> the pal's shaping defers quietly.
--
--   Pending work is tracked from the "needs worker" event, which is a PULSE
--   (re-fires every 1-4s per unfilled job, verified for transport), not a
--   level. Smoothing over pulse gaps happens in exactly ONE place: the pending
--   freshness window (PENDING_FRESH_SECONDS), fast-pathed by a liveness check
--   on the job object so filled/completed jobs drop out within one tick. The
--   active worker needs no hold of its own — its current work counts as
--   pending (see reconcilePal's active-worker lock). A second stacked lag
--   mechanism (bar hysteresis) was removed after a live report of pals idling
--   15-25s before falling back to lower-priority work.
--
--   Server->client priority sync: state is pushed to attested modded clients via
--   Notify_RequestClient_int32 (Client+Reliable, called on that player's own
--   server-side component — NEVER the Multicast variants, so unmodded clients
--   receive nothing). Each unique FName string sent interns permanently in UE's
--   name table; volume is bounded by clicks per session — acceptable, deliberate.
--
-- SAFETY
--   This runs inside someone's game. A Lua error thrown from a hook can crash the
--   game, so EVERY game-object access is wrapped in pcall, and repeated failures
--   are logged once (never in a retry loop). Prefer skip-and-log over retry.
-- ============================================================================

local VERSION = "1.1.0"

-- CYCLE_MODE: when true, a genuine user toggle on the vanilla work screen CYCLES
-- that work type's priority 0->1->2->3->4->5->0 (auto-configuring the pal on the
-- first touch). When false, fall back to the original binary semantics
-- (off -> prio 0, on -> prio 3-if-0) which is what an UNMODDED client sees, since
-- an unmodded client can only send true/false and cannot show a cycle number.
local CYCLE_MODE = true

-- DEBUG: enables the dev diagnostics (F9 roster dump). Ships false in release;
-- flip to true when hunting a bug or re-verifying hooks after a game patch.
local DEBUG = false

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

-- EPalWorkType (the job's OverrideWorkType enum) -> EPalWorkSuitability. Station
-- jobs (PalWorkProgress) don't match CLASS_TYPE_MAP and their assign-info out-param
-- is unreliable, but they DO carry a plain OverrideWorkType enum (VERIFIED: workbench
-- job reported 12 = ConvertItem). Without this map the pending tracker is blind to
-- all station work (crafting, smelting, cooking...), which skews the priority bar.
-- Key = EPalWorkType int; value = EPalWorkSuitability (1-13). Enum indices confirmed
-- against the game's EPalWorkType declaration order.
local WORKTYPE_TO_SUIT = {
    [3]=5,[4]=5,[5]=6,[6]=6,[7]=12,[8]=3,[9]=2,[10]=1,[11]=12,[12]=5,[13]=5,
    [14]=1,[15]=10,[16]=12,[17]=6,[18]=7,[19]=8,[20]=7,[21]=8,[22]=4,[23]=1,
    [26]=13,[28]=11,[29]=2,[40]=5,[44]=12,[45]=12,[46]=6,
}

-- ---------------------------------------------------------------------------
-- Mutable state
-- ---------------------------------------------------------------------------
local config = { pals = {} }   -- loaded from priorities.lua (see loadConfig)
local shadows = {}             -- palKey -> { [type]=true }  our belief of the pal's off-list
local pending = {}             -- workKey -> { type=int, lastSeen=os.time(), work=<obj, alive()-gated ONLY> }
local campComp = nil           -- captured PalNetworkBaseCampComponent used to send RPCs
local internalCall = false     -- reentrancy guard: true while WE send an RPC (see hook)
-- Modded-client attestation. The client UI mod sends a PrioMod_Dir marker just
-- before each toggle it originates; both arrive on the sender's own network
-- component, so keying by component full name (a) identifies the sender and
-- (b) prevents one player's marker being consumed by another player's toggle.
-- Components that have EVER spoken our protocol are remembered as modded.
local pendingDirByComp = {}    -- compFullName -> { dir=+1/-1, at=os.clock() } (stale after 1s)
local moddedComps = {}         -- compFullName -> { comp=<component ref>, at=os.clock() of last PrioMod_* message }
-- TTL'd because UE recycles object names: a stale entry must not classify a NEW
-- player's component as modded. Every marker/ping refreshes it, so an active
-- modded client never expires mid-session. The comp ref is the send target for
-- the server->client sync channel; it MUST be alive()-revalidated before every
-- use (cached UObject refs go stale — see the crash rule on alive()).
local MODDED_TTL_SECONDS = 600
-- PER-OWNER WRITE ROUTING. On servers where every player is in their own
-- guild, an off-list write for pal X sent through another player's component
-- may not be authorized for X's guild and silently no-ops. So each configured
-- pal remembers its managing player (cfg.owner = the attested clicker) and its
-- writes go through THAT player's own component — the same authority the
-- vanilla UI uses. campComp stays as the legacy fallback for entries that
-- predate the owner field. Owner offline -> the pal's shaping defers quietly.
local ownerComps = {}          -- ownerHex (32-hex PlayerUId) -> { comp=<ref>, at=os.clock() }
local compOwnerCache = {}      -- compFullName -> ownerHex; session cache for resolveCompOwner.
                               -- CAVEAT: UE recycles object names, so a hit can in theory go
                               -- stale; capture points always hold a LIVE component when they
                               -- consult it, keeping the window small (same hazard class the
                               -- moddedComps TTL exists for).
-- The ONE pending-smoothing window. The "needs worker" event is a PULSE that
-- re-fires every 1-4s per unfilled job (verified for transport), not a level:
-- this window must exceed the worst observed re-fire gap (~4s) or unfilled
-- jobs oscillate in and out of pending, flip-flopping toggles at pulse
-- frequency (observed live: pals drop carried items when their current type
-- gets fenced mid-task). Raise it if a job type is ever observed pulsing
-- slower. Deliberately the ONLY smoothing mechanism: a bar hysteresis once
-- stacked on top of this, and the two lags summed to 15-25s of idle pals
-- before they fell back to lower-priority work. The active worker needs no
-- hold at all — reconcilePal counts the pal's own current work as pending,
-- which keeps the winner locked on independent of events.
local PENDING_FRESH_SECONDS = 6
-- CONVERGENCE GUARD for off-list writes. The reconciler diffs against the
-- game's ACTUAL stored off-list every tick, so a write that silently no-ops —
-- observed live at boot: RPC sent on a FindFirstOf component with no owning
-- player connection — would otherwise resend identically (RPC + delta log)
-- every 3s forever. After SEND_MAX_TRIES unacknowledged sends per pal+type we
-- back off; any newly captured player component resets the guard
-- (clearSendGuard) for a clean retry, since writes may work fine through it.
local sendGuard = {}           -- "palkey|worktype" -> { tries=n, holdUntil=nil-or-os.clock() }
local SEND_MAX_TRIES = 3
local SEND_BACKOFF_SECONDS = 120
local function clearSendGuard() sendGuard = {} end
local managedCache = {}        -- palKey -> { set={[t]=true}, at=os.clock() } suitability cache
local MANAGED_TTL_SECONDS = 60 -- suitabilities barely change; skip 13 reflection calls/pal/tick
-- Identity migration (pal re-instancing, observed live on a dedicated server):
-- Palworld assigns a NEW InstanceId to a base pal on server restart and on
-- pickup+redeploy, so the palKey the config was written under stops matching
-- and the entry silently orphans (file accumulates dead duplicates). We track
-- every live pal's identity each tick and adopt orphaned entries onto their
-- re-instanced pal by ANCHOR (species + immutable IVs + gender, see anchorOf)
-- when the match is unambiguous.
local liveSeen = {}            -- palKey -> os.clock() of last enumeration (EVERY pal, configured or not)
local liveInfo = {}            -- palKey -> { name, anchor, raw } identity snapshot (stable while live)
local firstTickAt = nil        -- os.clock() of the first supervisor tick (boot-grace anchor)
local lastAdoptAt = nil        -- os.clock() of the last adoption sweep (self-throttle)
local ADOPT_INTERVAL_SECONDS = 10   -- sweep at most this often
local ADOPT_BOOT_GRACE_SECONDS = 60 -- bases stream in slowly after boot; a not-yet-loaded
                                    -- base must not orphan its pals, so judge nothing early
local LIVE_STALE_SECONDS = 30  -- unseen this long => not live (orphan / not a candidate)
local LIVE_PRUNE_SECONDS = 600 -- forget liveSeen/liveInfo entries this stale (churn growth guard)
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
--         anchor = "Species|hp/sh/df/g", -- optional, set by the mod, do not edit:
--                                        --   species + immutable IVs + gender, used
--                                        --   to re-adopt this entry when the game
--                                        --   re-instances the pal (restart/redeploy)
--         owner = "<32-hex PlayerUId>",  -- optional, set by the mod: the managing
--                                        --   player (last attested clicker) whose own
--                                        --   component carries this pal's writes
--         prio = { [8]=5, [12]=1 },      -- [worktype]=priority (0-5); missing => 0
--         raw  = { PlayerUId={A,B,C,D}, InstanceId={A,B,C,D} }, -- identity, do not edit
--       },
--     },
--   }
--
-- PRIORITY (RimWorld scale): 0 = never do this work. 1 = most important,
--   5 = least important. A pal only works its most-important types that
--   currently have pending work.
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
        if e.anchor then
            out[#out + 1] = string.format("      anchor = %q,\n", e.anchor)
        end
        if e.owner then
            out[#out + 1] = string.format("      owner = %q,\n", e.owner)
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
            -- anchor is optional (files predating it lack it entirely); a
            -- malformed value degrades to "absent" = inert for adoption.
            if type(e.anchor) ~= "string" then e.anchor = nil end
            -- owner likewise optional; absent = legacy campComp routing.
            if type(e.owner) ~= "string" then e.owner = nil end
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
        -- Steam-workshop UE4SS layout (tester-verified exact relative path).
        "../../../Mods/NativeMods/UE4SS/Mods/PalPriority/priorities.lua",
    }
    -- Best candidate: derive the mod's ABSOLUTE directory from package.path,
    -- which UE4SS seeds with each mod's Scripts dir — immune to whatever cwd
    -- the game/loader picked. Plain Lua string work only; pcall-guarded anyway
    -- so a weird package.path can never abort startup. The [/\\] right after
    -- "PalPriority" is the segment boundary that keeps us from matching the
    -- companion PalPriorityUI mod's entry.
    pcall(function()
        for entry in string.gmatch(package.path or "", "[^;]+") do
            local base = entry:match("^(.*[/\\]Mods[/\\]PalPriority)[/\\]Scripts[/\\]%?%.lua$")
            if base then
                table.insert(candidates, 1, base .. "/priorities.lua")
                break
            end
        end
    end)
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

-- Drop a pending entry when its pulse stops being fresh (the assign hook
-- stopped re-firing — see PENDING_FRESH_SECONDS) OR when its work object died,
-- the fast path: a completed/destroyed job vanishes within one 3s tick instead
-- of aging out of the window. The stored work ref is consulted through alive()
-- and NOTHING else (crash rule: pcall cannot catch stale-wrapper AVs); entries
-- that somehow lack the ref fall back to pure freshness. os.time() is
-- second-granular — fine at these window sizes, and what the file already uses.
local function prunePending(now)
    for k, e in pairs(pending) do
        if (now - e.lastSeen) > PENDING_FRESH_SECONDS then
            pending[k] = nil
        elseif e.work ~= nil and not alive(e.work) then
            pending[k] = nil
        end
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

    -- Station jobs: resolve via the plain OverrideWorkType enum (safe property
    -- read, VERIFIED populated) mapped through WORKTYPE_TO_SUIT.
    local wt = nil
    pcall(function() wt = w.OverrideWorkType end)
    if type(wt) == "number" then
        local mapped = WORKTYPE_TO_SUIT[wt]
        if mapped then return mapped end
    end

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

-- Identity-migration anchor. The InstanceId does not survive re-instancing
-- (restart / pickup+redeploy) but the SaveParameter blob provably does, so we
-- fingerprint the pal from stable fields inside it: species (CharacterID) +
-- the three SAVED immutable IVs (Talent_HP/Shot/Defense — Talent_Melee is
-- Transient/unsaved, deliberately excluded) + gender. Nicknames turned out to
-- be empty in the wild (the "names" we store are just CharacterIDs), so name
-- matching would be species-only and too weak; the IV spread disambiguates
-- same-species pals except true identical twins. Returns nil unless ALL five
-- reads succeed — a partial anchor could mis-match, absent must stay absent.
local function anchorOf(param)
    local a = nil
    pcall(function()
        if not alive(param) then return end
        local sp = param.SaveParameter
        local species = fstr(sp.CharacterID)
        local hp, shot, def, gender = sp.Talent_HP, sp.Talent_Shot, sp.Talent_Defense, sp.Gender
        if species == nil or #species == 0 then return end
        if type(hp) ~= "number" or type(shot) ~= "number"
            or type(def) ~= "number" or type(gender) ~= "number" then return end
        a = species .. "|" .. hp .. "/" .. shot .. "/" .. def .. "/" .. tostring(gender)
    end)
    return a
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

-- Resolve which player owns a network basecamp component, as the 32-hex
-- PlayerUId string the owner registry is keyed by. Chain (header-verified,
-- the same one the client mod uses): APalPlayerController.Transmitter ->
-- .BaseCamp; the match is by GetFullName() STRING because wrapper equality
-- across separate UE4SS calls is unreliable. Skips Default__ CDOs (crash
-- rule). Result cached per component name for the session; nil = unresolved.
local function resolveCompOwner(compName)
    if type(compName) ~= "string" then return nil end
    local hit = compOwnerCache[compName]
    if hit then return hit end
    local found = nil
    pcall(function()
        local ctrls = FindAllOf("PalPlayerController")
        if not ctrls then return end
        for _, ctrl in ipairs(ctrls) do
            if found then break end
            pcall(function()
                if not alive(ctrl) then return end
                local full = ctrl:GetFullName()
                if type(full) == "string" and full:find("Default__", 1, true) then return end
                local tx = ctrl.Transmitter
                if not alive(tx) then return end
                local bc = tx.BaseCamp
                if not alive(bc) then return end
                if bc:GetFullName() ~= compName then return end
                local uid = ctrl:GetPlayerUId()
                if uid == nil then return end
                found = string.format("%08X%08X%08X%08X",
                    norm(uid.A), norm(uid.B), norm(uid.C), norm(uid.D))
            end)
        end
    end)
    if found then compOwnerCache[compName] = found end
    return found
end

-- Register a live component as its owning player's send target. Returns the
-- ownerHex when resolvable (callers use it to stamp/refresh cfg.owner).
local function registerOwnerComp(compName, compRef)
    local owner = resolveCompOwner(compName)
    if owner and alive(compRef) then
        ownerComps[owner] = { comp = compRef, at = os.clock() }
    end
    return owner
end

-- ---------------------------------------------------------------------------
-- The write lever: send one off-list toggle via the vanilla RPC.
-- bOn == true  -> enable the type (remove from off-list)
-- bOn == false -> disable the type (add to off-list)
-- ownerHex (optional): route through THAT player's component; see below.
-- ---------------------------------------------------------------------------
local function sendToggle(raw, t, bOn, ownerHex)
    local comp = nil
    if ownerHex then
        -- PER-OWNER ROUTING: this pal's writes go through its managing
        -- player's own component. No live component for that player -> DEFER:
        -- return false WITHOUT sending (callers must not advance the
        -- convergence guard for a deferred toggle). NEVER fall back to the
        -- global component for owner-tagged entries — a wrong-guild
        -- component's silently no-op'd write is exactly the bug this fixes.
        local e = ownerComps[ownerHex]
        if not (e and alive(e.comp)) then return false end
        comp = e.comp
    else
        -- LEGACY routing (entries predating the owner field): global cached
        -- component, metered by the convergence guard; the next genuine click
        -- on such a pal stamps an owner and upgrades it.
        -- Revalidate the cached component every send: it can be GC'd/recreated
        -- on level transitions; calling into a stale wrapper is a native crash.
        if campComp and not alive(campComp) then campComp = nil end
        local hadComp = campComp ~= nil
        comp = campComp or FindFirstOf("PalNetworkBaseCampComponent")
        if not alive(comp) then
            logOnce("nocomp", "no PalNetworkBaseCampComponent available yet — cannot send RPC")
            return false
        end
        if not hadComp then
            -- Replacement component (boot, or the cached one went stale): fresh
            -- guard tries everywhere. CAVEAT: this FindFirstOf fallback can hand
            -- back a component with NO owning player connection whose RPCs
            -- silently no-op (observed live at boot) — still better than nothing,
            -- and the convergence guard contains the damage until hooks (B)/(C)
            -- adopt a proven player component.
            clearSendGuard()
        end
        campComp = comp
    end
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

-- ---------------------------------------------------------------------------
-- Server -> client priority sync. On a dedicated server the client mod cannot
-- read priorities.lua, so we push state to it over the wire instead:
-- Notify_RequestClient_int32(FGuid, FName, int32) is a Client+Reliable RPC (the
-- exact mirror of the runtime-proven Request_Server_int32) — calling it on the
-- server-side instance of a SPECIFIC player's component delivers to that player
-- only. On listen-server/single-player it executes locally through ProcessEvent,
-- so the local client hook still fires. NEVER the Multicast variants: unmodded
-- clients must receive nothing.
--
-- Wire protocol (Value is always 1; the payload rides in the FName string):
--   "PrioSync|<palkey>|<13 chars>"  full row: work types 1..13 in order, each
--       char '0'-'5' when cfg.prio[t] is a number, '-' when nil. '-' vs '0'
--       matters to the client: '0' renders "X" (never), '-' renders blank.
--   "PrioDrop|<palkey>"             pal released / no longer configured.
-- <palkey> contains a '-' but no '|', so the client parses by splitting on '|'.
-- ---------------------------------------------------------------------------

-- Build the "PrioSync|..." string for one pal. Plain Lua only, no game objects.
local function packSyncMsg(key, cfg)
    local chars = {}
    for t = WORK_MIN, WORK_MAX do
        local p = cfg.prio[t]
        if type(p) == "number" then
            -- Clamp defensively: a hand-edited config value outside 0-5 must not
            -- desync the fixed-width 13-char field the client parses.
            chars[#chars + 1] = tostring(math.max(0, math.min(5, I(p))))
        else
            chars[#chars + 1] = "-"
        end
    end
    return "PrioSync|" .. key .. "|" .. table.concat(chars)
end

-- Send one sync message to one component. alive() first — the refs in
-- moddedComps are cached across ticks and can go stale.
local function sendSync(comp, msg)
    if not alive(comp) then return false end
    local ok, err = pcall(function()
        comp:Notify_RequestClient_int32({ A = 0, B = 0, C = 0, D = 0 }, FName(msg), 1)
    end)
    if not ok then
        logOnce("syncsend", "Notify_RequestClient_int32 failed: " .. tostring(err))
        return false
    end
    return true
end

-- Push one pal's current state (PrioSync if configured, PrioDrop if not) to
-- every attested modded client. Doubles as the moddedComps janitor: expired or
-- dead entries are dropped here rather than in a dedicated sweep.
local function pushPal(key)
    local cfg = config.pals[key]
    local msg = cfg and packSyncMsg(key, cfg) or ("PrioDrop|" .. key)
    local now = os.clock()
    for name, e in pairs(moddedComps) do
        if (now - e.at) > MODDED_TTL_SECONDS or not alive(e.comp) then
            moddedComps[name] = nil
        else
            sendSync(e.comp, msg)
        end
    end
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

    -- Anchor backfill (identity migration): entries written before the anchor
    -- field existed (or whose reads failed at capture time) get it filled from
    -- the live pal, making them adoptable after the next re-instancing. In
    -- memory only; persisted by whichever saveConfig happens next (not worth a
    -- disk write of its own). Refresh-on-change lives on the managedCache-miss
    -- branch below (60s cadence — no need to re-read five fields every tick).
    if cfg.anchor == nil then
        local a = anchorOf(param)
        if a then cfg.anchor = a end
    end

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

        -- Anchor refresh (piggybacks the same 60s cadence): IVs are immutable
        -- in vanilla, but a future patch/mod could change them — refreshing
        -- while the pal is live keeps the stored anchor accurate at the moment
        -- of orphaning. In-memory; persisted by the next natural save.
        local freshAnchor = anchorOf(param)
        if freshAnchor and freshAnchor ~= cfg.anchor then cfg.anchor = freshAnchor end

        -- PRUNE bogus prio entries (heals configs damaged before the toggle
        -- hook's suitability guard existed): a prio key for a type this pal
        -- cannot do is dead weight that confuses the client display. Only when
        -- the fresh recompute is NON-empty — if all 13 HasWorkSuitability calls
        -- failed, managed is empty and "pruning" would wipe a valid config over
        -- a transient read failure.
        if next(managed) ~= nil then
            local removed = nil
            for t in pairs(cfg.prio) do
                if not managed[t] then
                    removed = removed or {}
                    removed[#removed + 1] = WORKNAME[t] or ("type" .. tostring(t))
                    cfg.prio[t] = nil
                end
            end
            if removed then
                log(string.format("pruned bogus prio entries [%s]: %s",
                    cfg.name or key, table.concat(removed, ", ")))
                saveConfig(config)
                pushPal(key) -- modded clients drop the stale numbers immediately
            end
        end
    end
    local eligible = {}
    for t in pairs(managed) do
        local p = cfg.prio[t] or 0
        if p >= 1 then eligible[t] = p end
    end

    -- RIMWORLD SCALE: 1 is the MOST important, 5 the least. The "bar" is the
    -- numerically LOWEST priority among eligible types with pending work; types
    -- numerically above the bar (less important) get fenced off.
    local bar = nil
    for t, p in pairs(eligible) do
        if (pendingByType[t] or 0) > 0 then
            if not bar or p < bar then bar = p end
        end
    end

    -- ACTIVE-WORKER LOCK: the pal's CURRENT assignment counts as pending for
    -- it. The event-based pending tracker only sees UNFILLED jobs — the moment
    -- this pal takes the last transport job, transport stops "pending", the bar
    -- collapses, and lower-priority types reopen mid-task. Counting the active
    -- job keeps the bar up while the pal is actually doing high-priority work.
    -- This is what keeps the winning worker stable now that the bar hysteresis
    -- is gone: the lock is level-accurate (read from the pal itself, not the
    -- event pulse), so the winner never needs a time-based hold — while idle
    -- pals follow the pending window alone and fall back to lower-priority
    -- work within about one tick of the job being taken by someone else.
    pcall(function()
        local cur = param:GetCurrentWorkSuitability()
        if type(cur) == "number" and eligible[cur] then
            if not bar or eligible[cur] < bar then bar = eligible[cur] end
        end
    end)

    -- desiredEnabled: if nothing pending, allow all eligible; otherwise only the
    -- eligible types at least as important as the bar (numerically <=).
    local desiredEnabled = {}
    if bar == nil then
        for t in pairs(eligible) do desiredEnabled[t] = true end
    else
        for t, p in pairs(eligible) do
            if p <= bar then desiredEnabled[t] = true end
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

    -- PER-OWNER DEFER: an owner-tagged pal whose managing player has no live
    -- component gets NO delta sends this tick — nothing is ever sent blind
    -- through another player's component (guild-per-player servers reject it).
    -- Quiet skip; the convergence guard does not advance because nothing is
    -- sent. Resumes automatically once the owner's component registers (click,
    -- ping, or the connect-time resolver in adoptOrphans).
    if cfg.owner then
        local oc = ownerComps[cfg.owner]
        if not (oc and alive(oc.comp)) then
            logOnce("defer:" .. key, string.format(
                "shaping deferred for [%s] — managing player not connected", cfg.name or key))
            return
        end
    end

    -- Every delta send is metered by the convergence guard (see sendGuard): a
    -- type observed in its desired state clears its guard entry; a type whose
    -- sends never take effect backs off after SEND_MAX_TRIES instead of
    -- resending forever. Shadow semantics deliberately unchanged: a successful
    -- send still sets sh[t] optimistically, and it is precisely the fresh
    -- off-list read CONTRADICTING that optimism next tick that re-raises the
    -- delta and advances the guard's tries counter.
    local nowG = os.clock()
    for t in pairs(managed) do
        local wantOff = not desiredEnabled[t] -- disable everything not desired-enabled
        local isOff = (sh[t] == true)
        local gk = key .. "|" .. t
        if wantOff == isOff then
            sendGuard[gk] = nil -- converged (or never diverged): clean slate
        else
            local g = sendGuard[gk]
            if g and g.holdUntil and nowG < g.holdUntil then
                -- Stuck toggle backing off: skip silently (no log spam).
            else
                local sent = false
                if wantOff then
                    sent = sendToggle(cfg.raw, t, false, cfg.owner)
                    if sent then
                        sh[t] = true
                        log(string.format("delta [%s] %s DISABLE", cfg.name or key, WORKNAME[t] or ("type" .. t)))
                    end
                else
                    sent = sendToggle(cfg.raw, t, true, cfg.owner)
                    if sent then
                        sh[t] = nil
                        log(string.format("delta [%s] %s ENABLE", cfg.name or key, WORKNAME[t] or ("type" .. t)))
                    end
                end
                if sent then
                    -- Re-read the entry: sendToggle can clearSendGuard() when it
                    -- adopts a replacement component mid-call.
                    g = sendGuard[gk] or { tries = 0 }
                    g.tries = g.tries + 1
                    if g.tries >= SEND_MAX_TRIES then
                        g.holdUntil = os.clock() + SEND_BACKOFF_SECONDS
                        g.tries = 0
                        logOnce("stuck:" .. gk, string.format(
                            "toggle for [%s] %s not taking effect after %d attempts — backing off %ds (no connected player component yet?)",
                            cfg.name or key, WORKNAME[t] or ("type" .. t),
                            SEND_MAX_TRIES, SEND_BACKOFF_SECONDS))
                    end
                    sendGuard[gk] = g
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Identity migration: adopt orphaned config entries onto re-instanced pals.
-- An "orphan" is a configured key that no longer enumerates; a "candidate" is a
-- live pal. Matching is by anchor (anchorOf) and acts ONLY when unambiguous —
-- guessing wrong would weld one pal's priorities onto another, so any doubt
-- means do nothing and tell the user once. Matching itself is pure Lua state
-- (identity captured at enumeration time); the owner-registry upkeep hosted
-- here (it already runs on the 10s throttle) does alive()/pcall-guarded
-- controller reads. Still pcall'd at the call site so a bug in this sweep can
-- never kill the tick.
-- ---------------------------------------------------------------------------
local function adoptOrphans()
    local now = os.clock()
    if lastAdoptAt ~= nil and (now - lastAdoptAt) < ADOPT_INTERVAL_SECONDS then return end
    lastAdoptAt = now

    -- Owner-registry upkeep FIRST — deliberately ahead of the boot grace, so
    -- shaping resumes within ~10s of boot for players already connected (the
    -- grace protects orphan judgment, not write routing). Drop dead component
    -- refs, then proactively resolve components for owners that config entries
    -- reference but who have no live registration — shaping thus resumes on
    -- player CONNECT, not only when they click or open the work screen.
    for oh, oe in pairs(ownerComps) do
        if not alive(oe.comp) then ownerComps[oh] = nil end
    end
    local wanted = {}   -- ownerHex -> true: referenced by config, not registered
    for _, ce in pairs(config.pals) do
        if ce.owner and ownerComps[ce.owner] == nil then wanted[ce.owner] = true end
    end
    if next(wanted) ~= nil then
        -- ONE controller pass covers every missing owner.
        pcall(function()
            local ctrls = FindAllOf("PalPlayerController")
            if not ctrls then return end
            for _, ctrl in ipairs(ctrls) do
                if next(wanted) == nil then break end
                pcall(function()
                    if not alive(ctrl) then return end
                    local full = ctrl:GetFullName()
                    if type(full) == "string" and full:find("Default__", 1, true) then return end
                    local uid = ctrl:GetPlayerUId()
                    if uid == nil then return end
                    local hex = string.format("%08X%08X%08X%08X",
                        norm(uid.A), norm(uid.B), norm(uid.C), norm(uid.D))
                    if not wanted[hex] then return end
                    local tx = ctrl.Transmitter
                    if not alive(tx) then return end
                    local bc = tx.BaseCamp
                    if not alive(bc) then return end
                    ownerComps[hex] = { comp = bc, at = os.clock() }
                    wanted[hex] = nil
                end)
            end
        end)
    end

    -- Boot grace: bases stream in over tens of seconds after start; a config
    -- entry whose base has not loaded yet is NOT an orphan. Judge nothing early.
    if firstTickAt == nil or (now - firstTickAt) < ADOPT_BOOT_GRACE_SECONDS then return end

    -- Housekeeping: liveSeen/liveInfo grow as pals churn across a long session;
    -- entries stale beyond matching relevance are dropped here (same loop
    -- family, negligible at this cadence).
    for k, at in pairs(liveSeen) do
        if (now - at) > LIVE_PRUNE_SECONDS then
            liveSeen[k] = nil
            liveInfo[k] = nil
        end
    end

    -- Classify live (fresh) pals by anchor: configured vs unconfigured. Pals
    -- whose anchor never became readable are skipped entirely — they can
    -- neither be adopted onto nor counted as a configured twin.
    local unconfByAnchor = {}     -- anchor -> array of live unconfigured keys
    local confCountByAnchor = {}  -- anchor -> count of live configured keys
    for k, at in pairs(liveSeen) do
        if (now - at) <= LIVE_STALE_SECONDS then
            local info = liveInfo[k]
            local a = info and info.anchor or nil
            if a then
                if config.pals[k] then
                    confCountByAnchor[a] = (confCountByAnchor[a] or 0) + 1
                else
                    unconfByAnchor[a] = unconfByAnchor[a] or {}
                    table.insert(unconfByAnchor[a], k)
                end
            end
        end
    end

    -- Orphans, grouped by stored anchor. Entries WITHOUT an anchor are INERT:
    -- never matched, never dropped (they only leave via the release path) —
    -- anything weaker than the anchor mis-matches (the "names" we store proved
    -- to be bare species CharacterIDs in the wild, not nicknames).
    local orphansByAnchor = {}    -- anchor -> array of orphaned config keys
    for k, e in pairs(config.pals) do
        if e.anchor ~= nil then
            local at = liveSeen[k]
            if at == nil or (now - at) > LIVE_STALE_SECONDS then
                orphansByAnchor[e.anchor] = orphansByAnchor[e.anchor] or {}
                table.insert(orphansByAnchor[e.anchor], k)
            end
        end
    end

    local changed = false
    local touched = {}   -- keys to pushPal after the save (old keys -> PrioDrop, new -> PrioSync)
    for a, orphans in pairs(orphansByAnchor) do
        local cands = unconfByAnchor[a] or {}
        local confCount = confCountByAnchor[a] or 0

        if #orphans == 1 and #cands == 1 and confCount == 0 then
            -- Unambiguous re-instancing: move the entry to the pal's new key.
            -- confCount == 0 matters: with a CONFIGURED twin also live on this
            -- anchor, the orphan could belong to either pal — that's a guess,
            -- and guesses fall through to the ambiguity log below.
            local oldKey, newKey = orphans[1], cands[1]
            local entry = config.pals[oldKey]
            local info = liveInfo[newKey]
            if info and info.raw then entry.raw = info.raw end
            config.pals[newKey] = entry
            config.pals[oldKey] = nil
            shadows[oldKey], managedCache[oldKey] = nil, nil
            shadows[newKey], managedCache[newKey] = nil, nil
            touched[oldKey], touched[newKey] = true, true
            changed = true
            log(string.format("migrated [%s]: %s -> %s (pal was re-instanced)",
                entry.name or "?", oldKey, newKey))
        elseif #cands == 0 and confCount > 0 then
            -- Superseded duplicates: the pal already lives under a NEW configured
            -- key (re-configured before this sweep could migrate — e.g. by a
            -- click that predates this feature). The orphan is dead weight, and
            -- exactly the file bloat this feature exists to stop accumulating.
            for _, oldKey in ipairs(orphans) do
                local entry = config.pals[oldKey]
                config.pals[oldKey] = nil
                shadows[oldKey], managedCache[oldKey] = nil, nil
                touched[oldKey] = true
                changed = true
                log(string.format("dropped superseded config [%s] %s",
                    (entry and entry.name) or "?", oldKey))
            end
        elseif #cands >= 1 then
            -- Ambiguous: multiple orphans or multiple live candidates on one
            -- anchor — identical twins (same species/IVs/gender) cannot be told
            -- apart. Never guess; the user re-clicks those pals by hand.
            logOnce("adopt:" .. a, string.format(
                "cannot migrate config for anchor %s (%d orphan(s), %d live candidate(s)) — identical twins cannot be told apart; re-set priorities by clicking those pals",
                a, #orphans, #cands))
        end
        -- else (#cands == 0 and confCount == 0): the pal's base is likely just
        -- not loaded right now — keep the entry and keep waiting.
    end

    if changed then
        saveConfig(config)
        for k in pairs(touched) do pushPal(k) end
    end
end

-- The tick body. Runs ON the game thread (invoked via ExecuteInGameThread).
local function tickBody()
    -- Heartbeat: proves this mod's async queue survived startup (UE4SS can kill
    -- a mod's engine-tick processing on a "Ref was not function" exception).
    logOnce("alive", "supervisor async loop alive")

    -- Boot-grace anchor for the adoption sweep (see adoptOrphans).
    if firstTickAt == nil then firstTickAt = os.clock() end

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
            -- Identity tracking for the adoption sweep: EVERY enumerated pal,
            -- configured or not — the unconfigured live ones are the adoption
            -- candidates. liveInfo is captured once per key (identity is stable
            -- while the pal stays live; no reason to repeat the reflection
            -- reads every tick). pcall: a bad id must not skip reconcile.
            pcall(function()
                local key = palKey(id.PlayerUId, id.InstanceId)
                liveSeen[key] = os.clock()
                local info = liveInfo[key]
                if info == nil then
                    local okr, raw = pcall(extractRaw, id)
                    liveInfo[key] = {
                        name = displayName(id, param),
                        anchor = anchorOf(param),
                        raw = okr and raw or nil,
                    }
                elseif info.anchor == nil then
                    -- First capture can land on a tick where param wasn't
                    -- readable; heal the anchor once it becomes so — a live pal
                    -- with a nil anchor is invisible to adoption.
                    info.anchor = anchorOf(param)
                end
            end)
            reconcilePal(id, param, pendingByType)
        end)
    end

    -- Adoption sweep (boot grace + 10s throttle live inside it). pcall: total-
    -- failure-safe — a thrown sweep skips the sweep, never the tick.
    local oka, erra = pcall(adoptOrphans)
    if not oka then logOnce("adoptsweep", "adoptOrphans error: " .. tostring(erra)) end
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
                    -- RimWorld scale: 1 = most important; the bar is the LOWEST
                    -- number among pending eligible types.
                    local bar, barsrc = nil, nil
                    for t, p in pairs(eligible) do
                        if (pendingByType[t] or 0) > 0 and (not bar or p < bar) then
                            bar, barsrc = p, t
                        end
                    end
                    local cur = nil
                    if param then
                        pcall(function() cur = param:GetCurrentWorkSuitability() end)
                    end
                    local en, dis = {}, {}
                    for t in pairs(managed) do
                        local p = cfg.prio[t] or 0
                        local want = p >= 1 and (bar == nil or p <= bar)
                        if want then en[#en + 1] = WORKNAME[t] else dis[#dis + 1] = WORKNAME[t] end
                    end
                    table.sort(en); table.sort(dis)
                    log(string.format(
                        "    plan: bar=%s%s cur=%s | want-on {%s} | want-off {%s}",
                        tostring(bar), barsrc and (" via " .. WORKNAME[barsrc]) or "",
                        (type(cur) == "number" and WORKNAME[cur]) or "none",
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
                    -- Entries can predate the work-ref stash; heal it so the
                    -- prunePending death fast-path can see this job too.
                    if e.work == nil then e.work = w end
                    return
                end
                local t = getWorkType(w)
                if not t then return end -- unknown class already logged once
                -- The work ref rides along ONLY for prunePending's liveness
                -- fast-path, gated through alive() — never any other member
                -- call on it (crash rule).
                pending[wk] = { type = t, lastSeen = os.time(), work = w }
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
            -- COMPONENT ADOPTION: a GENUINE toggle only ever arrives on a live
            -- player's component, so it unconditionally replaces the cache —
            -- freshest wins. This evicts the boot-time FindFirstOf dud (a
            -- component with no owning player connection whose RPCs silently
            -- no-op — observed live). Our OWN sends (internalCall) prove
            -- nothing about player ownership and merely fill an empty cache;
            -- if they also triggered adoption, every resend would reset the
            -- convergence guard and defeat it. A replacement component gets
            -- fresh guard tries everywhere (clearSendGuard).
            pcall(function()
                local c = Context:get()
                if not alive(c) then return end
                if campComp == nil then
                    campComp = c
                elseif not internalCall and c ~= campComp then
                    campComp = c
                    clearSendGuard()
                end
                -- Per-owner registry: a genuine toggle proves this component
                -- belongs to a live player — map it to that player's UId so
                -- their owner-tagged pals route writes through it (and any
                -- deferred shaping resumes).
                if not internalCall then
                    registerOwnerComp(c:GetFullName(), c)
                end
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
                local compName = nil -- toggling component's name; also keys the
                                     -- owner (managing player) resolution below
                if CYCLE_MODE then
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
                            if seen and (os.clock() - seen.at) < MODDED_TTL_SECONDS then
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
                                            -- Owner routing like everywhere else; if
                                            -- the manager is offline this restore
                                            -- defers (send skipped) — the release
                                            -- below still proceeds.
                                            sendToggle(raw, t, wantOn, cfg.owner)
                                        end
                                    end
                                end
                            end
                        end
                    end

                    config.pals[key] = nil
                    shadows[key] = nil
                    managedCache[key] = nil
                    saveConfig(config)
                    pushPal(key) -- PrioDrop: modded clients blank the pal's row
                    log(string.format(
                        "released [%s]: unattested toggle — pal returned to vanilla on/off",
                        cfg.name or key))
                    return
                end

                -- MODDED cycle path ---------------------------------------------
                -- The attested clicker is this pal's managing player: its writes
                -- route through their component (see sendToggle). Cache is warm —
                -- the capture block above just registered this same component.
                -- nil when unresolvable: the entry then keeps legacy routing.
                local ownerHex = compName and resolveCompOwner(compName) or nil

                -- Locate the live pal. Needed for auto-config (HasWorkSuitability +
                -- off-list) and for the immediate reconcile below. If we can't find
                -- it, this isn't a base pal we manage -> stay fully vanilla.
                local fid, fparam = findPalByKey(key)

                -- SUITABILITY GUARD (live tester bug): clicking a column the pal
                -- cannot work (e.g. Watering on a non-waterer) must not create or
                -- cycle a bogus prio entry. Verify against the live pal when we
                -- have it; when we don't (pal not enumerable right now), only
                -- allow types the config already manages — never invent an entry
                -- we cannot verify.
                if fparam and alive(fparam) then
                    local okh, has = pcall(function() return fparam:HasWorkSuitability(work) end)
                    if okh and has == false then
                        logOnce("unsuit", "ignored toggle on unsuitable work type")
                        return
                    end
                elseif cfg then
                    if cfg.prio[work] == nil then return end
                end

                if not cfg then
                    if not fparam then return end -- not a base pal -> ignore toggle

                    -- ADOPTION FAST-PATH: before minting a fresh config, check
                    -- whether an ORPHANED entry (its key no longer enumerates —
                    -- the pal was re-instanced on restart/redeploy) carries this
                    -- pal's anchor. Covers the user clicking a re-instanced pal
                    -- before the 10s sweep notices; without this the click
                    -- would mint defaults and strand the old priorities forever.
                    -- Unreadable anchor -> no adoption (anchorless entries are
                    -- inert by design, and nothing weaker is trustworthy).
                    local myAnchor = anchorOf(fparam)
                    local orphanKey, orphanN = nil, 0
                    if myAnchor then
                        local nowA = os.clock()
                        for k2, e2 in pairs(config.pals) do
                            if k2 ~= key and e2.anchor == myAnchor then
                                local at = liveSeen[k2]
                                if at == nil or (nowA - at) > LIVE_STALE_SECONDS then
                                    orphanN = orphanN + 1
                                    orphanKey = k2
                                end
                            end
                        end
                    end
                    if orphanN == 1 then
                        -- Exactly one match: adopt it onto this key. The normal
                        -- cycle+save+push code below then applies this click to
                        -- the adopted priorities, exactly as if the pal had
                        -- always lived under its new key.
                        cfg = config.pals[orphanKey]
                        local okr, raw = pcall(extractRaw, fid or id)
                        if okr then cfg.raw = raw end
                        config.pals[key] = cfg
                        config.pals[orphanKey] = nil
                        shadows[orphanKey], managedCache[orphanKey] = nil, nil
                        shadows[key], managedCache[key] = nil, nil
                        log(string.format("adopted config [%s] on first click", cfg.name or key))
                        pushPal(orphanKey) -- PrioDrop for the dead key (new key syncs below)
                    end
                    -- Zero or ambiguous (twin) matches: fall through to fresh
                    -- auto-config.
                end

                if not cfg then
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
                    -- anchor rides along for identity migration (nil tolerated:
                    -- the entry is then inert for adoption until the reconcile
                    -- backfill manages to read one). name is cosmetic/log only.
                    -- owner = the clicking player; nil keeps legacy routing.
                    cfg = { name = displayName(fid or id, fparam), anchor = anchorOf(fparam),
                            owner = ownerHex, prio = prio }
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

                -- MANAGER REFRESH: the attested clicker becomes (or stays) the
                -- pal's managing player — a different modded player clicking
                -- the pal TAKES OVER its management, because their component is
                -- the freshest proven authority for this pal's guild.
                if ownerHex and cfg.owner ~= ownerHex then cfg.owner = ownerHex end

                cfg.prio[work] = new
                saveConfig(config) -- persist the edit back to priorities.lua
                pushPal(key)       -- sync the row to modded clients (covers auto-config too)
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
                -- The component ref is kept alongside the timestamp: it is the
                -- send target for the server->client sync channel (pushPal /
                -- sendSync alive()-revalidate it before every use).
                local compName, compRef = nil, nil
                pcall(function()
                    local c = Context:get()
                    if alive(c) then
                        compName = c:GetFullName()
                        compRef = c
                    end
                end)
                if compName then moddedComps[compName] = { comp = compRef, at = os.clock() } end

                -- COMPONENT ADOPTION (the dedicated-server fix): ANY PrioMod_*
                -- message proves this component belongs to a real modded
                -- player — clients ping within seconds of opening the work
                -- screen — so promote it to the RPC send target, evicting a
                -- boot-time FindFirstOf dud whose writes silently no-op.
                -- Replacement component => fresh convergence-guard tries.
                if compRef ~= nil and compRef ~= campComp then
                    campComp = compRef
                    clearSendGuard()
                end
                -- Per-owner registry: any PrioMod_* sender is a live modded
                -- player's component — register it so that player's owner-
                -- tagged pals route writes through it (clients ping within
                -- seconds of opening the work screen; deferred shaping
                -- resumes right there on dedicated servers).
                if compName and compRef then
                    registerOwnerComp(compName, compRef)
                end

                if name == "PrioMod_Ping" then
                    log(string.format("PrioMod_Ping received (value=%d) — client mod announced%s",
                        Value:get(), compName and (" on " .. compName) or ""))
                    -- Reply with FULL priority state to just this component, so a
                    -- freshly connected client on a dedicated server catches up.
                    -- Cost profile: ping fires ~once per minute per client while
                    -- the work screen is open, and pal counts are small (tens),
                    -- so the unthrottled full loop is cheap — no batching needed.
                    if compRef and alive(compRef) then
                        for key, cfg in pairs(config.pals) do
                            sendSync(compRef, packSyncMsg(key, cfg))
                        end
                    end
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
-- Dev-only: inert in release builds (see the DEBUG flag at the top); manual
-- config edits are picked up at game start.
pcall(function()
    if not DEBUG then return end
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
-- Dev-only: inert in release builds (see the DEBUG flag at the top).
pcall(function()
    if not DEBUG then return end
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
