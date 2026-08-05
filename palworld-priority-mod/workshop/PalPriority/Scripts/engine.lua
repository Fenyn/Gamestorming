-- ============================================================================
-- PalPriority engine — the AUTHORITY half. Runs wherever the machine owns the
-- base pals (single-player, co-op host, dedicated server). main.lua owns the
-- hooks, the keybinds and the loop; this module is only handlers and logic.
--
-- Each base pal gets a 0-5 priority per work type. The supervisor shapes the
-- pal's vanilla "off list" so it only works the types it was allocated. Pals
-- with no config entry are left completely vanilla.
--
-- MECHANISM (settled by in-game probing — see ../../../docs/callpath-map.md)
--   Hooks into the assignment gate (IsExistAssignableSlot) never fire, so
--   assignments cannot be vetoed inline. Instead we drive each pal's off-list
--   through RequestChangeWorkSuitability_ToServer, the same write path the
--   vanilla toggle UI uses (replicated + persisted).
--
--   Writes route PER-OWNER: each configured pal remembers the player whose
--   attested click manages it, and its writes go through that player's own
--   component. Guild-per-player servers silently reject writes sent through
--   another player's component. Manager offline -> shaping defers quietly.
--
-- STRUCTURE
--   camps      — director registry, learned from the assign hook (which fires
--                constantly and hands us the director), with a slow discovery
--                scan as the safety net for camps that have no unfilled work.
--   demand     — pending unfilled jobs, counted PER CAMP and maintained
--                incrementally by the hooks. A job at another base must not
--                fence pals that cannot reach it.
--   planner.lua— the decision, as a pure function.
--   palState   — planned vs applied masks per pal; a camp whose demand has not
--                changed and whose pals are converged costs zero game calls.
--
-- SAFETY
--   A Lua error thrown from a hook can crash the game. EVERY game-object access
--   is pcall-wrapped, every received object is alive()-gated before any member
--   call, SoftObjectProperties are never read, and GetWorkAssignInfo is never
--   called (see the crash rules in the callpath map). Skip-and-log, never retry.
-- ============================================================================

local S = require("shared")
local R = require("registry")
local Planner = require("planner")

local alive, fstr, arrayForEach, I = S.alive, S.fstr, S.arrayForEach, S.I
local guidStr, palKey, palLabel = S.guidStr, S.palKey, S.palLabel
local log, vlog, logOnce = S.log, S.vlog, S.logOnce

local E = {}

-- ---------------------------------------------------------------------------
-- Knobs (set from main.lua via E.configure)
-- ---------------------------------------------------------------------------
local PROTECT_CURRENT = false -- keep the current work type enabled when preempted
local DEBUG = false           -- tick cost readout

function E.configure(opts)
    opts = opts or {}
    if opts.protectCurrent ~= nil then PROTECT_CURRENT = opts.protectCurrent == true end
    if opts.debug ~= nil then DEBUG = opts.debug == true end
end

-- ---------------------------------------------------------------------------
-- Work types (EPalWorkSuitability, 13 usable values)
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
local WORK_MIN, WORK_MAX = Planner.WORK_MIN, Planner.WORK_MAX

-- Work class-name substring -> work type. Cheapest resolution step; substring
-- match survives the "_C" decoration on blueprint classes.
local CLASS_TYPE_MAP = {
    PalWorkTransportItemInBaseCamp = 12,
    PalWorkDeforestFoliage         = 7,
    PalWorkCollectResource         = 6,
}

-- EPalWorkType (the job's OverrideWorkType enum) -> EPalWorkSuitability.
-- Every name below is from the game's own EPalWorkType enum, read via UEnum
-- reflection (WorkTypeProbe, 2026-07-25) — no longer guesswork.
local WORKTYPE_TO_SUIT = {
    [3]=5,   -- Architecture
    [4]=5,   -- RepairBuildObject
    [5]=6,   -- FarmHarvest
    [6]=6,   -- HarvestLevelObject
    [7]=12,  -- TransportFoodItemInBaseCamp
    [8]=3,   -- Seeding
    [9]=2,   -- Watering
    [10]=1,  -- Cooking
    [11]=12, -- TransportDisposableItemInBaseCamp
    [12]=5,  -- ConvertItem
    [13]=5,  -- ProductItem
    [14]=1,  -- Smelting
    [15]=10, -- ProductMedicine
    [16]=12, -- TransportItemInBaseCamp
    [17]=6,  -- CollectResourcePickable
    [18]=7,  -- ProductResource_Deforest
    [19]=8,  -- ProductResource_Mining
    [20]=7,  -- ProductResource_Deforest_OnFacility
    [21]=8,  -- ProductResource_Mining_OnFacility
    [22]=4,  -- GenerateEnergy
    [23]=1,  -- Ignition
    [26]=13, -- MonsterFarm
    [27]=2,  -- ExtinguishBurn (inferred from the enum name, not yet observed)
    [28]=11, -- Cool
    [29]=2,  -- Watering_Farm
    [40]=5,  -- LabResearch
    [44]=12, -- CollectItemToStorage
    [45]=12, -- TransportItem
    [46]=6,  -- CollectResource
    -- Deliberately unmapped: 1 CommonTemp, 2 ReviveCharacter, 24 Defense,
    -- 25 BreedFarm, 30-39 DedicatedWork01-10, 41 FishPond, 42 AncientBreedFarm,
    -- 43 Attack, 47 GrowupPromotion. Either not work-suitability gated or not
    -- yet observed — a wrong entry fences pals onto work that does not exist.
}

-- Stations whose job reports OverrideWorkType = None/0, so neither map above
-- can see them. AssignDefineDataId is the station identifier.
--   ["<AssignDefineDataId>"] = <EPalWorkSuitability 1-13>
-- Grow this from the "unmapped work class" lines in the log.
-- Keys are the station id with its trailing instance number stripped: the id is
-- per-BUILDING, not per-type (confirmed live — a base with several berry plots
-- reported FarmBlockV2_Berries_2). Keying on the raw id would have matched only
-- a player's FIRST campfire and left every later one invisible.
local STATION_SUIT = {
    ["CampFire"] = 1,    -- Kindling. THIS is why a ranching pal never left for a
                         -- cold campfire: its work was invisible to the tracker.
    ["BuildWork"] = 5,   -- Handcraft (construction sites)
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local config = { pals = {} }
local configDirty, configDirtyAt = false, nil
local SAVE_DEBOUNCE_SECONDS = 3   -- one file write per burst of clicks, not per click

local NO_CAMP = "*"               -- fallback camp id when BaseCampId is unreadable

local camps = {}                  -- campId -> { dir = <director>, at = os.clock() }
local jobs = {}                   -- workKey -> { camp, t (nil = unresolvable), lastSeen, work }
local demand = {}                 -- campId -> { [t] = count }, maintained incrementally
local demandSatAt = {}            -- campId -> { [t] = os.time() of last at-cap pulse }
local unresolved = {}             -- campId -> count of tracked jobs with no work type
local pulseSecond, pulseCount = 0, 0   -- PULSE_BUDGET window
local classMemo = {}              -- class|overrideType -> suitability | false; per BUILD, not per session
local contMemo = {}               -- same key as classMemo -> is this job CONTINUOUS; per BUILD too
local contSeen = {}               -- campId -> { [t] = true } for never-completing work; sticky, no expiry

local palState = {}               -- palKey -> per-pal reconcile record (see reconcileCamp)
local campState = {}              -- campId -> { demandMask, verifiedAt }
local forceAll = false            -- set by a click; next tick visits every camp

local campComp = nil              -- legacy send target for owner-less entries
local internalCall = false        -- reentrancy guard while WE send an RPC
local pendingDirByComp = {}       -- compFullName -> { dir = +1/-1, at }
local moddedComps = {}            -- compFullName -> { comp, at }
local ownerComps = {}             -- ownerHex -> { comp, at }

local liveSeen = {}               -- palKey -> os.clock() of last enumeration
local liveInfo = {}               -- palKey -> { name, anchor, raw }
local idleFencedSince = {}        -- palKey -> os.clock() when it was first allocated work but had none
local lastIdleReportAt = nil      -- module-wide rate limit on the fenced-idle line
local firstTickAt = nil
local lastAdoptAt, lastDiscoverAt = nil, nil
local tickCount, tickWorstMs = 0, 0   -- DEBUG cost readout

-- The "needs worker" event is a PULSE that re-fires every 1-4s per unfilled job,
-- not a level. This window must exceed the worst observed re-fire gap or jobs
-- oscillate in and out of demand and toggles flip at pulse frequency. It is the
-- ONLY smoothing mechanism: a bar hysteresis once stacked on top and the two
-- lags summed to 15-25s of idle pals.
local JOB_FRESH_SECONDS = 6

-- RUNAWAY-QUEUE GUARDS. Once a station produces faster than the base can haul,
-- the unfilled-haul queue grows without bound and every job in it keeps pulsing
-- hook A: measured in simulation at 3 items/s, ~980 tracked jobs after 10
-- minutes and ~2900 after 30, with no steady state. Both costs that scale with
-- that queue land on the GAME THREAD — the per-tick prune sweep and the hook
-- body itself — so the backlog starves the pal AI that was going to clear it,
-- which is the reported "transport pals stop moving and nothing gets hauled".
--
-- DEMAND_CAP bounds the jobs table. The planner can never hand out more claims
-- for one type than there are pals in the camp, so any cap at or above the
-- largest possible roster is INVISIBLE to the plan (verified: demand 16 and
-- demand 999 produce byte-identical allocations for a 12-pal roster).
local DEMAND_CAP = 32
-- PULSE_BUDGET bounds the hook. Every unfilled job re-pulses every 1-4s, so
-- what survives the budget is a sample of the same stream — which is all a
-- presence-plus-capped-count estimate needs. Surplus pulses cost one os.time()
-- and two integer ops, with no game access at all.
local PULSE_BUDGET = 120

local MODDED_TTL_SECONDS = 600
local MANAGED_TTL_SECONDS = 60    -- suitabilities barely change
local VERIFY_SECONDS = 30         -- forced off-list re-read even when converged
local ROSTER_SECONDS = 60         -- full enumeration (liveness + suitability refresh)
-- FindAllOf walks the whole object array and measured ~29ms live — two dropped
-- frames, which is exactly the kind of hitch this mod got uninstalled over. It
-- is now a COLD-START FALLBACK only: camps register themselves from hooks A/A2,
-- and a loaded base with pals emits those constantly (assign pulses every 1-4s,
-- plus every unassign). A base that is unloaded has no director for a scan to
-- find either, so periodic scanning bought nothing it could not get for free.
local DISCOVER_SECONDS = 30       -- retry interval while ZERO camps are known
local ADOPT_INTERVAL_SECONDS = 30
local ADOPT_BOOT_GRACE_SECONDS = 60
local LIVE_STALE_SECONDS = 180    -- must comfortably exceed ROSTER_SECONDS
local LIVE_PRUNE_SECONDS = 900
local CAMP_WARMUP_SECONDS = 15    -- grace before silence counts as "this base is idle"

-- Fenced-but-idle reporting. This is the one diagnostic that ships with DEBUG
-- off, because "my pal just stands there" is unreportable without it. The
-- threshold has to clear a normal walk across a base plus the toggle round trip.
local IDLE_FENCED_SECONDS = 15
local IDLE_REPORT_SECONDS = 60

local SEND_MAX_TRIES = 3
local SEND_BACKOFF_SECONDS = 120

local CONFIG_PATH = "Mods/PalPriority/priorities.lua"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function _palKeyOf(id) return palKey(id.PlayerUId, id.InstanceId) end

-- RAW (unnormalized) ints — what the RPC must receive verbatim.
local function extractRaw(id)
    return {
        PlayerUId  = { A = id.PlayerUId.A,  B = id.PlayerUId.B,  C = id.PlayerUId.C,  D = id.PlayerUId.D },
        InstanceId = { A = id.InstanceId.A, B = id.InstanceId.B, C = id.InstanceId.C, D = id.InstanceId.D },
    }
end

-- Hook A fires every 1-4s PER UNFILLED JOB, so this is the mod's highest-
-- frequency function. Named helper, not a closure: see shared.lua.
--
-- Returns nil when the work id cannot be read. It used to fall back to
-- tostring(w), which looks like a key and is not one: the wrapper's address
-- varies between pulses for the SAME job, so every pulse minted a fresh entry
-- and the job was counted over and over. An uncountable job must be skipped, not
-- guessed at — one missing job understates demand by one, a runaway key
-- overstates it without bound.
local function _workId(w) return guidStr(w:GetWorkId()) end
local function workKey(w)
    local ok, key = pcall(_workId, w)
    if ok and key then return key end
    return nil
end

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
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
--   5 = least important. A pal works the most important type it was allocated;
--   pals compete for the jobs that actually exist at their base.
-- WORK TYPES: 1 EmitFlame(Kindling) 2 Watering 3 Seeding 4 GenerateElectricity
--   5 Handcraft 6 Collection 7 Deforest 8 Mining 9 OilExtraction
--   10 ProductMedicine 11 Cool 12 Transport 13 MonsterFarm
--
-- Press F9 in-game (DEBUG builds) to print every base pal's key.
]==]

local function serializeConfig(cfg)
    local out = { CONFIG_HEADER, "return {\n  pals = {\n" }

    local keys = {}
    for k in pairs(cfg.pals) do keys[#keys + 1] = k end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local e = cfg.pals[k]
        out[#out + 1] = string.format("    [%q] = {\n", k)
        if e.name then out[#out + 1] = string.format("      name = %q,\n", e.name) end
        if e.anchor then out[#out + 1] = string.format("      anchor = %q,\n", e.anchor) end
        if e.owner then out[#out + 1] = string.format("      owner = %q,\n", e.owner) end

        local pk = {}
        for t in pairs(e.prio or {}) do pk[#pk + 1] = t end
        table.sort(pk)
        local pparts = {}
        for _, t in ipairs(pk) do
            pparts[#pparts + 1] = string.format("[%d]=%d", I(t), I(e.prio[t]))
        end
        out[#out + 1] = "      prio = { " .. table.concat(pparts, ", ") .. " },\n"

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

    for k, e in pairs(result.pals) do
        if type(e) ~= "table" then
            result.pals[k] = nil
        else
            if type(e.prio) ~= "table" then e.prio = {} end
            if type(e.anchor) ~= "string" then e.anchor = nil end
            if type(e.owner) ~= "string" then e.owner = nil end
        end
    end
    return result
end

-- MIRROR. priorities.lua is player data living inside a mod folder, and every
-- distribution channel rewrites mod folders: Vortex restores from its staging
-- copy on each deploy, the Workshop loader reinstalls whenever Version changes,
-- and a manual zip extract overwrites. Any of those silently wipes a player's
-- priorities (observed live 2026-07-25 on a Vortex deploy). So every save also
-- writes outside the mod folder, and startup restores from there if the primary
-- comes back empty. Resolved once, lazily; nil = no writable location, in which
-- case the mod behaves exactly as before.
local MIRROR_PATH, mirrorResolved = nil, false

local function mirrorPath()
    if mirrorResolved then return MIRROR_PATH end
    mirrorResolved = true
    local candidates = {}
    local lad = os.getenv("LOCALAPPDATA")
    if lad and #lad > 0 then
        -- The game's own save folder exists for anyone who has launched it, and
        -- no deployment tool touches it.
        candidates[#candidates + 1] = lad .. "/Pal/Saved/PalPriority-priorities.lua"
        candidates[#candidates + 1] = lad .. "/PalPriority-priorities.lua"
    end
    local up = os.getenv("USERPROFILE")
    if up and #up > 0 then
        candidates[#candidates + 1] = up .. "/PalPriority-priorities.lua"
    end
    for _, p in ipairs(candidates) do
        local f = io.open(p, "a")   -- append: proves writability without truncating
        if f then
            f:close()
            MIRROR_PATH = p
            return MIRROR_PATH
        end
    end
    logOnce("nomirror", "no writable backup location for priorities — config exists only in the mod folder")
    return nil
end

local function writeMirror(text)
    local p = mirrorPath()
    if not p then return end
    pcall(function()
        local f = io.open(p, "w")
        if not f then return end
        f:write(text)
        f:close()
    end)
end

local function writeConfig(cfg)
    local ok, text = pcall(serializeConfig, cfg)
    if not ok then
        log("saveConfig: serialize failed: " .. tostring(text))
        return false
    end

    writeMirror(text)

    local tmp = CONFIG_PATH .. ".tmp"
    local tf = io.open(tmp, "w")
    if tf then
        tf:write(text)
        tf:close()
        pcall(os.remove, CONFIG_PATH)   -- Windows os.rename won't clobber
        if os.rename(tmp, CONFIG_PATH) then
            vlog("config saved -> " .. CONFIG_PATH)
            return true
        end
        pcall(os.remove, tmp)
    end

    local df = io.open(CONFIG_PATH, "w")
    if not df then
        log("saveConfig FAILED: cannot open " .. CONFIG_PATH .. " for writing")
        return false
    end
    df:write(text)
    df:close()
    vlog("config saved (direct rewrite) -> " .. CONFIG_PATH)
    return true
end

-- Debounced: cycling a pal through five values is one write, not five.
local function markConfigDirty()
    configDirty = true
    configDirtyAt = os.clock()
end

local function flushConfig(force)
    if not configDirty then return end
    if not force and configDirtyAt and (os.clock() - configDirtyAt) < SAVE_DEBOUNCE_SECONDS then
        return
    end
    configDirty = false
    configDirtyAt = nil
    writeConfig(config)
end

local function resolveConfigPath()
    local candidates = {
        "Mods/PalPriority/priorities.lua",
        "ue4ss/Mods/PalPriority/priorities.lua",
        "priorities.lua",
        "../../../Mods/NativeMods/UE4SS/Mods/PalPriority/priorities.lua",
    }
    -- Best candidate: this mod's absolute dir, immune to the game's cwd. The
    -- relative fallbacks stay for odd installs where package.path is unusual.
    local dir = S.modDir()
    if dir then table.insert(candidates, 1, dir .. "/priorities.lua") end
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
-- Demand index
-- ---------------------------------------------------------------------------

local function bumpDemand(campId, t, delta)
    if not campId or not t then return end
    local d = demand[campId]
    if not d then
        if delta <= 0 then return end
        d = {}
        demand[campId] = d
    end
    local n = (d[t] or 0) + delta
    d[t] = (n > 0) and n or nil
end

-- Record that this camp/type sat at DEMAND_CAP while its flood was still
-- pulsing. Read back by pruneJobs, which holds the count at the cap rather than
-- draining a queue it deliberately stopped enumerating.
local function stampSaturated(campId, t, now)
    local s = demandSatAt[campId]
    if not s then
        s = {}
        demandSatAt[campId] = s
    end
    s[t] = now
end

local function isSaturated(campId, t, now)
    if not campId or not t then return false end
    local s = demandSatAt[campId]
    local at = s and s[t]
    if not at or (now - at) > JOB_FRESH_SECONDS then return false end
    local d = demand[campId]
    return d ~= nil and (d[t] or 0) >= DEMAND_CAP
end

-- Record that this camp has work of type t that never completes. Sticky for the
-- session: no timestamp, no expiry.
--
-- ASYMMETRIC COSTS, which is the whole argument for having no timer. Remembering
-- too long (the campfire was demolished an hour ago, the stamp is still here)
-- costs nothing but reverting that ONE type in that ONE camp to the old
-- PROTECT_CURRENT = false behaviour — preemptible, which is what shipped for the
-- mod's whole life. Forgetting too early pins a pal on never-completing work
-- indefinitely, which is the exact bug this exists to prevent, and it is the
-- likelier direction: hook A only fires for UNFILLED work, so a station that is
-- being worked announces nothing at all and any TTL would run out underneath the
-- pal standing on it.
local function stampContinuous(campId, t)
    if not campId or not t then return end
    local c = contSeen[campId]
    if not c then
        c = {}
        contSeen[campId] = c
    end
    c[t] = true
end

-- The types this camp has ever announced never-completing work for, handed to
-- the planner so finish-the-job never protects one of them. The stored table IS
-- the set (the planner only reads it), so a reconcile allocates nothing here, and
-- nil simply means this camp has never seen any.
--
-- Granularity is per-TYPE per-camp and cannot be finer: GetCurrentWorkSuitability
-- reports the pal's current TYPE, not the station it is standing at, and a
-- smelter and a campfire are both Kindling. So a single campfire keeps every
-- Kindling pal in that camp preemptible — which is exactly what the old
-- PROTECT_CURRENT = false did for every type in every camp, now narrowed to the
-- types that actually earn it.
local function continuousSetOf(campId)
    return contSeen[campId]
end

-- Resolve a job's required suitability, memoized per class+enum so a class we
-- cannot resolve costs one table lookup on every later job instead of a fresh
-- round of reflection. Deliberately NO deeper fallback: GetWorkAssignInfo
-- marshals object-bearing structs out-param, is the prime suspect in the
-- station-bench crash reports, and never once succeeded.
--
-- Also returns the memo key it settled on, so the caller can file per-signature
-- facts of its own (contMemo) under exactly the same granularity — key1 where
-- the class or the enum decided it, key2 where only the station id could.
local function resolveWorkType(w)
    local name = S.classNameOf(w)
    if not name then return nil end

    local wt = nil
    pcall(function() wt = w.OverrideWorkType end)

    -- Stage 1: class name / OverrideWorkType. Both are per-class facts, so the
    -- memo key is class+enum.
    local key1 = name .. "|" .. tostring(wt)
    local m1 = classMemo[key1]
    if type(m1) == "number" then return m1, key1 end
    if m1 == nil then
        -- OverrideWorkType wins when set. One class carries several: the
        -- transport class was observed with 11/16/17/7, so taking the class name
        -- first labelled every CollectResourcePickable job as Transport and hid
        -- it from pals set to Collection. 0 means no override — use the class.
        local found = nil
        if type(wt) == "number" and wt ~= 0 then found = WORKTYPE_TO_SUIT[wt] end
        if not found then
            for sub, t in pairs(CLASS_TYPE_MAP) do
                if name:find(sub, 1, true) then found = t break end
            end
        end
        if found then
            classMemo[key1] = found
            return found, key1
        end
        classMemo[key1] = "station"
    end

    -- Stage 2: every station shares one class and OverrideWorkType = 0, so
    -- stage 1's key cannot tell a furnace from a bench — the station id must be
    -- part of the key or the first station resolved would answer for all of them.
    local assignId = nil
    pcall(function() assignId = fstr(w.AssignDefineDataId) end)

    -- Strip the trailing instance number so every campfire shares one entry,
    -- not just the first one built. Memoize on the stripped form for the same
    -- reason: otherwise each new building pays a fresh resolution.
    local base = assignId
    if base then base = base:gsub("_%d+$", "") end

    local key2 = key1 .. "|" .. tostring(base)
    local m2 = classMemo[key2]
    if m2 ~= nil then
        if m2 == false then return nil, key2 end
        return m2, key2
    end

    -- Exact id first so a single misbehaving building could be special-cased,
    -- then the stripped form, which is what the table is actually keyed on.
    local found = (assignId and STATION_SUIT[assignId])
        or (base and STATION_SUIT[base]) or nil
    classMemo[key2] = found or false
    if not found then
        logOnce("unkclass:" .. key2, string.format(
            "unmapped work class (its work is invisible to priorities): %s assignId=%s workType=%s",
            name, tostring(assignId), tostring(wt)))
    end
    return found, key2
end

-- Drop jobs whose pulse went stale, or whose work object died (the fast path —
-- a completed job leaves within one tick instead of aging out). The stored ref
-- is consulted through alive() and NOTHING else.
local function pruneJobs(now)
    for k, e in pairs(jobs) do
        local dead = (now - e.lastSeen) > JOB_FRESH_SECONDS
        if not dead and e.work ~= nil and not alive(e.work) then dead = true end
        if dead then
            -- A type at the cap stopped being enumerated on purpose, so the
            -- entries still here stand in for a queue we are no longer counting.
            -- Draining them would walk the count down and then re-admit jobs one
            -- sampled pulse at a time; hold the slot until the flood's own pulses
            -- stop arriving. lastSeen is deliberately NOT refreshed, so the whole
            -- held set drains on the first prune after saturation lifts. The work
            -- ref is dropped so a held entry costs no alive() call.
            if isSaturated(e.camp, e.t, now) then
                e.work = nil
            else
                jobs[k] = nil
                bumpDemand(e.camp, e.t, -1)
                if e.t == nil and e.camp and unresolved[e.camp] then
                    local n = unresolved[e.camp] - 1
                    unresolved[e.camp] = (n > 0) and n or nil
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Camp registry
-- ---------------------------------------------------------------------------

local function campIdOf(dir)
    local id = nil
    pcall(function() id = guidStr(dir.BaseCampId) end)
    if id then return id end
    logOnce("nocampid",
        "director BaseCampId unreadable — pending work falls back to a single global pool")
    return NO_CAMP
end

local function noteCamp(dir)
    if not alive(dir) then return nil end
    local id = campIdOf(dir)
    local e = camps[id]
    if e then
        e.dir = dir
        e.at = os.clock()
    else
        camps[id] = { dir = dir, at = os.clock() }
    end
    return id
end

-- Safety net for camps with no unfilled work to announce through the assign
-- hook. Also how a pal fenced before a restart gets un-fenced when its base has
-- nothing pending. Slow on purpose: FindAllOf walks the whole object array.
--
-- 1.3 made this COLD-START ONLY (`if next(camps) ~= nil then return end`) on the
-- reasoning that hooks A/A2 register every camp for free. They do not: a camp
-- registers only when it has UNFILLED work, because that is the only thing hook
-- A fires for. A fully-staffed base never pulses, is never discovered, and is
-- never reconciled — so a pal fenced there before a restart stays fenced
-- forever, which is precisely the safety net the comment above promises. 1.2
-- rescanned every 60s unconditionally and did not have this hole.
--
-- Restoring the sweep without restoring the cost: scan when the registry is
-- empty (the original cold start), and otherwise only when some CONFIGURED pal
-- has not been seen alive recently — i.e. only when there is actually a pal
-- unaccounted for. A save whose camps are all registered never pays the walk.
local function discoverCamps(now)
    if lastDiscoverAt and (now - lastDiscoverAt) < DISCOVER_SECONDS then return end

    local cold = (next(camps) == nil)
    if not cold then
        local missing = false
        for k in pairs(config.pals) do
            local at = liveSeen[k]
            if at == nil or (now - at) > LIVE_STALE_SECONDS then
                missing = true
                break
            end
        end
        if not missing then return end
    end

    lastDiscoverAt = now
    local dirs = nil
    pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
    if not dirs then return end
    local found, fresh = 0, 0
    for _, dir in ipairs(dirs) do
        pcall(function()
            if not alive(dir) then return end
            if S.isDefaultObject(S.fullNameOf(dir)) then return end
            local id = campIdOf(dir)
            if camps[id] == nil then fresh = fresh + 1 end
            if noteCamp(dir) then found = found + 1 end
        end)
    end
    if cold and found > 0 then
        logOnce("discover", string.format(
            "cold-start scan found %d camp(s) — none had announced itself yet", found))
    elseif fresh > 0 then
        log(string.format(
            "sweep adopted %d camp(s) that never announced themselves "
            .. "(a base with no pending work does not pulse)", fresh))
    end
end

-- ---------------------------------------------------------------------------
-- Enumeration
-- ---------------------------------------------------------------------------

local function displayName(id, param)
    local nm = nil
    pcall(function()
        if param then
            local sp = param.SaveParameter
            nm = fstr(sp.NickName)
            if not nm or #nm == 0 then nm = fstr(sp.CharacterID) end
        end
    end)
    if not nm or #nm == 0 then
        pcall(function() nm = fstr(id.DebugName) end)
    end
    if not nm or #nm == 0 then nm = "?" end
    return nm
end

-- Identity fingerprint for re-instancing (InstanceId does not survive a restart
-- or pickup+redeploy, the SaveParameter blob does): species + the three SAVED
-- immutable IVs + gender. Talent_Melee is Transient/unsaved, deliberately out.
-- Returns nil unless ALL reads succeed — a partial anchor could mis-match.
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

-- SlotArray (plain replicated property) first; GetSlots() by-value return fails
-- to marshal on some UE4SS builds.
local function getSlotsArray(container)
    local arr = nil
    pcall(function() arr = container.SlotArray end)
    if arr ~= nil then return arr, "SlotArray" end
    pcall(function() arr = container:GetSlots() end)
    return arr, "GetSlots()"
end

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
                -- Empty slots hold NULL-WRAPPER handles: non-nil, and any member
                -- call on them is a native crash.
                if not alive(slot) then
                    s.nilSlot = (s.nilSlot or 0) + 1
                    return
                end
                local handle = slot.Handle
                if not alive(handle) then
                    s.invalid = (s.invalid or 0) + 1
                    return
                end
                local id = handle:GetIndividualID()
                if id == nil then
                    s.noId = (s.noId or 0) + 1
                    return
                end
                local param = handle:TryGetIndividualParameter()
                if not alive(param) then param = nil end
                s.ok = (s.ok or 0) + 1
                cb(handle, id, param)
            end)
        end)
    end)
end

local function findPalByKey(key)
    local foundId, foundParam = nil, nil
    local dirs = {}
    for _, e in pairs(camps) do dirs[#dirs + 1] = e.dir end
    if #dirs == 0 then
        -- No camp has announced itself yet (first click after load, before any
        -- job pulse). Scan once rather than refuse the click, and REGISTER what
        -- it finds so the next click is a dictionary read.
        pcall(function()
            local found = FindAllOf("PalBaseCampWorkerDirector")
            if not found then return end
            for _, d in ipairs(found) do
                if alive(d) and not S.isDefaultObject(S.fullNameOf(d)) then
                    dirs[#dirs + 1] = d
                    pcall(noteCamp, d)
                end
            end
        end)
    end
    for _, dir in ipairs(dirs) do
        if foundParam then break end
        enumerateDir(dir, function(_, id, param)
            if foundParam then return end
            local ok, k = pcall(_palKeyOf, id)
            if ok and k == key then foundId, foundParam = id, param end
        end)
    end
    return foundId, foundParam
end

-- ---------------------------------------------------------------------------
-- Component / owner routing
-- ---------------------------------------------------------------------------

-- Owner lookups go through registry.lua: one shared, rate-limited, backed-off
-- controller walk instead of one per question. The old local version cached
-- successes only, so every component it could not resolve re-walked the whole
-- object array on the next call.
local function registerOwnerComp(compName, compRef)
    R.note(compName)
    local owner = R.ownerOf(compName)
    if owner and alive(compRef) then
        ownerComps[owner] = { comp = compRef, at = os.clock() }
    end
    return owner
end

-- Send one off-list toggle. ownerHex routes through THAT player's component;
-- no live component for them -> DEFER (return false without sending, so callers
-- never advance the convergence guard). NEVER fall back to the global component
-- for an owner-tagged entry: a wrong-guild component's write silently no-ops.
-- overrideComp forces a specific component (the release path uses the caller's
-- own, which just proved authority over the pal).
local function sendToggle(raw, t, bOn, ownerHex, overrideComp)
    local comp = nil
    if overrideComp and alive(overrideComp) then
        comp = overrideComp
    elseif ownerHex then
        local e = ownerComps[ownerHex]
        if not (e and alive(e.comp)) then return false end
        comp = e.comp
    else
        if campComp and not alive(campComp) then campComp = nil end
        comp = campComp or FindFirstOf("PalNetworkBaseCampComponent")
        if not alive(comp) then
            logOnce("nocomp", "no PalNetworkBaseCampComponent available yet — cannot send RPC")
            return false
        end
        campComp = comp
    end
    local ok, err = pcall(function()
        -- Our RPC re-enters the toggle hook synchronously on a listen server.
        internalCall = true
        comp:RequestChangeWorkSuitability_ToServer(
            { PlayerUId = raw.PlayerUId, InstanceId = raw.InstanceId, DebugName = "" },
            t, bOn)
        internalCall = false
    end)
    internalCall = false
    if not ok then
        logOnce("rpcfail", "RPC RequestChangeWorkSuitability failed: " .. tostring(err))
        return false
    end
    return true
end

function E.isInternalCall()
    return internalCall
end

-- ---------------------------------------------------------------------------
-- Server -> client sync.  Notify_RequestClient_int32 is Client+Reliable; called
-- on a specific player's server-side component it delivers to that player only,
-- and executes locally on listen-server/single-player. NEVER the Multicast
-- variants — unmodded clients must receive nothing.
--   "PrioSync|<palkey>|<13 chars>"  '0'-'5' priority ('0' renders X), '-' none
--   "PrioDrop|<palkey>"             pal released
--   "PrioReset"                     clear everything, a full batch follows
-- <palkey> contains '-' but no '|', so the client splits on '|'.
-- ---------------------------------------------------------------------------
local function packSyncMsg(key, cfg)
    local chars = {}
    for t = WORK_MIN, WORK_MAX do
        local p = cfg.prio[t]
        if type(p) == "number" then
            chars[#chars + 1] = tostring(math.max(0, math.min(5, I(p))))
        else
            chars[#chars + 1] = "-"
        end
    end
    return "PrioSync|" .. key .. "|" .. table.concat(chars)
end

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

-- Drop the three tables that nothing else expires.
--
-- These used to be cleaned only as a side effect of other work: moddedComps
-- inside pushPal (which runs only when a config changes, so a session with no
-- clicks held UObject refs indefinitely past their TTL), pendingDirByComp not at
-- all (a click marker with no follow-up toggle was ignored via a freshness test
-- but never removed), and the demand tables only by the tick's camps loop —
-- which cannot reach an entry filed under NO_CAMP, because that id is used
-- exactly when noteCamp failed and so never created a camps row to iterate.
local function janitor(now)
    for name, e in pairs(moddedComps) do
        if (now - e.at) > MODDED_TTL_SECONDS or not alive(e.comp) then
            moddedComps[name] = nil
        end
    end
    -- A marker is only honoured for 1.0s (see onToggle); anything older is dead.
    for name, m in pairs(pendingDirByComp) do
        if (now - m.at) > 5.0 then pendingDirByComp[name] = nil end
    end
    for campId in pairs(demand) do
        if camps[campId] == nil then
            demand[campId] = nil
            demandSatAt[campId] = nil
            unresolved[campId] = nil
            contSeen[campId] = nil
        end
    end
end

-- Push one pal's state to every attested modded client.
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

-- Read the game's ACTUAL off-list. Ground truth: the reconciler diffs against
-- this rather than its own write history, so drift self-heals.
local function readOffMask(param)
    local m, ok = 0, nil
    ok = pcall(function()
        local lst = param.SaveParameter.WorkSuitabilityOptionInfo.OffWorkSuitabilityList
        arrayForEach(lst, function(v)
            if type(v) == "number" and v >= WORK_MIN and v <= WORK_MAX then
                m = m | Planner.bit(v)
            end
        end)
    end)
    return m, ok
end

-- ---------------------------------------------------------------------------
-- Per-pal state
-- ---------------------------------------------------------------------------
local function stateOf(key)
    local s = palState[key]
    if not s then
        s = { managed = 0, rank = nil, managedAt = nil,
              planned = nil, applied = nil, verifiedAt = nil, tries = {}, hold = {} }
        palState[key] = s
    end
    return s
end

local function dropState(key)
    palState[key] = nil
    idleFencedSince[key] = nil
end

-- Refresh the pal's suitability set + ranks. 13 reflection calls, so cached;
-- an empty result is NOT cached (a transient read failure would otherwise
-- unmanage the pal for a full TTL).
local function refreshManaged(key, param, cfg, now)
    local s = stateOf(key)
    if s.managedAt and (now - s.managedAt) < MANAGED_TTL_SECONDS and s.managed ~= 0 then
        return s
    end

    local mask, rank, allRead = 0, {}, true
    for t = WORK_MIN, WORK_MAX do
        local okh, has = pcall(function() return param:HasWorkSuitability(t) end)
        if not okh then allRead = false end
        if okh and has then
            mask = mask | Planner.bit(t)
            local r = nil
            pcall(function() r = param:GetWorkSuitabilityRankWithCharacterRank(t) end)
            rank[t] = (type(r) == "number") and r or 0
        end
    end
    if mask == 0 then return s end   -- read failed; keep whatever we had

    s.managed, s.rank, s.managedAt = mask, rank, now

    local fresh = anchorOf(param)
    if fresh and fresh ~= cfg.anchor then
        cfg.anchor = fresh
        markConfigDirty()
    end

    -- Heal configs damaged before the toggle hook's suitability guard existed:
    -- a prio key for a type this pal cannot do confuses the client display.
    --
    -- Requires ALL THIRTEEN reads to have succeeded, not merely a non-zero mask.
    -- A mask of zero was the only guarded case, but a single failed
    -- HasWorkSuitability among twelve successes yields a nonzero-but-incomplete
    -- mask — and this loop then deletes the player's priority for the type that
    -- failed to read, writes it to disk, and never restores it. A pal that
    -- silently stops hauling forever traces back to exactly one unlucky read.
    local removed = nil
    if allRead then
        for t in pairs(cfg.prio) do
            if not Planner.has(mask, t) then
                removed = removed or {}
                removed[#removed + 1] = WORKNAME[t] or ("type" .. t)
                cfg.prio[t] = nil
            end
        end
    end
    if removed then
        log(string.format("pruned bogus prio entries [%s]: %s",
            palLabel(cfg.name, key), table.concat(removed, ", ")))
        markConfigDirty()
        pushPal(key)
    end
    return s
end

-- ---------------------------------------------------------------------------
-- Reconcile one camp
-- ---------------------------------------------------------------------------

-- Drive one pal's off-list toward its planned mask. Returns true when converged.
-- Returns (converged, stalled). stalled = nothing was sent and nothing WILL be
-- until some external condition changes (player reconnects, send backoff ends),
-- so the caller must not keep its camp on the every-tick path over it.
local function applyPlan(key, cfg, s, param, now)
    -- Owner-tagged pal whose manager has no live component: send nothing. The
    -- convergence guard does not advance because nothing is sent.
    if cfg.owner then
        local oc = ownerComps[cfg.owner]
        if not (oc and alive(oc.comp)) then
            logOnce("defer:" .. key, string.format(
                "shaping deferred for [%s] — managing player not connected", palLabel(cfg.name, key)))
            return false, true
        end
    end

    local offMask, okRead = readOffMask(param)
    if not okRead then
        logOnce("offread:" .. key, "could not read off-list for " .. key)
        return false, true
    end
    s.verifiedAt = now

    -- Desired: every managed type not in planned is off.
    local wantOff = s.managed & ~s.planned
    local isOff = offMask & s.managed
    if wantOff == isOff then
        s.applied = s.planned
        s.tries, s.hold = {}, {}
        return true, false
    end

    local sent = 0
    local diff = wantOff ~ isOff
    for t = WORK_MIN, WORK_MAX do
        if Planner.has(diff, t) then
            local turnOff = Planner.has(wantOff, t)
            -- The backoff exists to stop us hammering a write the game keeps
            -- refusing. It must never suppress an ENABLE: the failure mode of a
            -- suppressed DISABLE is a pal doing lower-priority work for two
            -- minutes, but the failure mode of a suppressed ENABLE is a pal
            -- barred from work it is supposed to be doing — the idle bug this
            -- release is about, inflicted by the mod's own retry limiter.
            local hold = turnOff and s.hold[t] or nil
            if not (hold and now < hold) then
                if sendToggle(cfg.raw, t, not turnOff, cfg.owner) then
                    sent = sent + 1
                    vlog(string.format("delta [%s] %s %s", palLabel(cfg.name, key),
                        WORKNAME[t] or ("type" .. t), turnOff and "DISABLE" or "ENABLE"))
                    local n = (s.tries[t] or 0) + 1
                    if n >= SEND_MAX_TRIES then
                        s.hold[t] = now + SEND_BACKOFF_SECONDS
                        s.tries[t] = 0
                        logOnce("stuck:" .. key .. "|" .. t, string.format(
                            "toggle for [%s] %s not taking effect after %d attempts — backing off %ds",
                            palLabel(cfg.name, key), WORKNAME[t] or ("type" .. t),
                            SEND_MAX_TRIES, SEND_BACKOFF_SECONDS))
                    else
                        s.tries[t] = n
                    end
                end
            end
        end
    end
    s.applied = nil   -- not converged; re-check next pass
    return false, (sent == 0)
end

-- Plan and apply one camp. Skips entirely when its demand has not changed and
-- every pal is converged and verified recently — that is the steady state, and
-- it costs no game calls at all.
--
-- ALWAYS returns (worked, nPals). It used to return a bare `false` from its
-- three early exits and two values on success, which the caller papered over
-- with `np or 0` — and the caller ALSO reuses the second return as the error
-- message in the pcall-failure branch, so the two shapes read the same slot.
local function reconcileCamp(campId, entry, now, rosterDue, budget)
    local d = demand[campId]
    local dMask = Planner.demandMask(d)
    local cs = campState[campId]
    if not cs then
        cs = { demandMask = nil, verifiedAt = nil, firstSeenAt = now }
        campState[campId] = cs
    end

    -- WARMUP: silence is not the same as "no work". The assign pulse is 1-4s and
    -- a base streams in over longer than that, so a camp that has not reported
    -- anything yet gets left alone. Otherwise the planner reads the empty demand
    -- table as an idle base, unfences every work type, and vanilla hands the pal
    -- whatever is nearest — which is how a logging-1 pal ends up harvesting for
    -- a few seconds after spawning. Once any demand has been seen, or the camp
    -- has been quiet this long, "idle" is a real conclusion.
    if dMask == 0 and not cs.everHadDemand
        and (now - cs.firstSeenAt) < CAMP_WARMUP_SECONDS then
        return false, 0
    end
    if dMask ~= 0 then cs.everHadDemand = true end

    -- Why this camp might need work, split by whether it can WAIT a tick.
    --   must: something actually changed, or a pal is mid-convergence, or the
    --         user just clicked. Never deferred — that is responsiveness.
    --   may:  the periodic verify and the liveness sweep. Deferrable, and on a
    --         4-base save they otherwise land in the same frame and enumerate
    --         every camp at once, which is the spike shape itself.
    local verifyDue = (cs.verifiedAt == nil) or ((now - cs.verifiedAt) >= VERIFY_SECONDS)
    local must = forceAll or cs.pending or (dMask ~= cs.demandMask)
    local may = rosterDue or verifyDue
    if not must then
        if not may then return false, 0 end   -- steady state: no game calls
        if budget.n <= 0 then return false, 0 end
        budget.n = budget.n - 1            -- one deferrable camp per tick
    end

    local pals, ctx = {}, {}
    entry.enumAt = now   -- the sweep only chases camps nothing else has touched
    enumerateDir(entry.dir, function(_, id, param)
        local okk, key = pcall(_palKeyOf, id)
        if not okk or not key then return end

        -- Liveness rides on EVERY enumeration, not just the periodic sweep: a
        -- camp reconciling because its demand moved keeps its pals fresh for
        -- free, so the sweep is left with almost nothing to do.
        liveSeen[key] = now
        local info = liveInfo[key]
        if info == nil then
            local okr, raw = pcall(extractRaw, id)
            liveInfo[key] = {
                name = displayName(id, param),
                anchor = anchorOf(param),
                raw = okr and raw or nil,
            }
        elseif info.anchor == nil then
            info.anchor = anchorOf(param)
        end

        local cfg = config.pals[key]
        if not cfg or not param or ctx[key] then return end   -- unconfigured stays vanilla

        local okr, raw = pcall(extractRaw, id)
        if not okr then return end
        cfg.raw = raw
        if cfg.anchor == nil then
            local a = anchorOf(param)
            if a then cfg.anchor = a end
        end

        local s = refreshManaged(key, param, cfg, now)
        if s.managed == 0 then return end

        local cur = nil
        pcall(function()
            local c = param:GetCurrentWorkSuitability()
            if type(c) == "number" and c >= WORK_MIN and c <= WORK_MAX then cur = c end
        end)

        ctx[key] = { cfg = cfg, state = s, param = param, cur = cur }
        pals[#pals + 1] = {
            key = key, prio = cfg.prio, managed = s.managed, current = cur, rank = s.rank,
        }
    end)

    cs.demandMask = dMask
    if #pals == 0 then
        cs.verifiedAt = now
        cs.pending = false
        return true, 0
    end

    local plan = Planner.plan(pals, d, {
        protectCurrent = PROTECT_CURRENT,
        continuous = continuousSetOf(campId),
    })

    -- allConverged gates the verify stamp; anyActive gates cs.pending. A pal
    -- that is merely STALLED (managing player offline, every toggle in send
    -- backoff) must not pin its camp to the every-tick path: nothing next tick
    -- can change the outcome, and on a big save that held a full roster
    -- enumeration on every single tick for the length of the backoff.
    local allConverged, anyActive = true, false
    local idleRows = nil
    for key, c in pairs(ctx) do
        local r = plan[key]
        if r then
            -- FENCED BUT IDLE. The plan allocated this pal work and the pal
            -- reports doing none — the failure players describe as "it just
            -- stands there", and until now visible only in a DEBUG build nobody
            -- runs. Both facts were already read above, so this costs no game
            -- call; it only advances on ticks where the camp actually reconciles,
            -- which VERIFY_SECONDS guarantees happens even in steady state.
            if r.claim and c.cur == nil then
                local since = idleFencedSince[key]
                if since == nil then
                    idleFencedSince[key] = now
                elseif (now - since) >= IDLE_FENCED_SECONDS then
                    idleRows = idleRows or {}
                    idleRows[#idleRows + 1] = string.format("%s wants %s, idle %ds (demand %d)",
                        palLabel(c.cfg.name, key), WORKNAME[r.claim] or ("type" .. r.claim),
                        I(now - since), (d and d[r.claim]) or 0)
                end
            else
                idleFencedSince[key] = nil
            end

            -- A NEW plan retires the old plan's failures. s.hold/s.tries were
            -- only ever cleared on full convergence, so a backoff earned trying
            -- to satisfy a plan that no longer exists kept suppressing writes
            -- for the plan that replaced it — for up to SEND_BACKOFF_SECONDS,
            -- against a target that might now succeed on the first try.
            if c.state.planned ~= r.enabled then
                c.state.tries, c.state.hold = {}, {}
            end
            c.state.planned = r.enabled
            local settled = (c.state.applied == r.enabled)
                and c.state.verifiedAt and (now - c.state.verifiedAt) < VERIFY_SECONDS
            if not settled then
                local done, stalled = applyPlan(key, c.cfg, c.state, c.param, now)
                if not done then
                    allConverged = false
                    if not stalled then anyActive = true end
                end
            end
        end
    end
    -- One compact line, at most once a minute across the whole mod: this is the
    -- text a player copies into a bug report, so it is log() and not vlog().
    if idleRows and (lastIdleReportAt == nil
        or (now - lastIdleReportAt) >= IDLE_REPORT_SECONDS) then
        lastIdleReportAt = now
        log(string.format("camp %s: %d pal(s) allocated work but idle — %s",
            campId:sub(1, 8), #idleRows, table.concat(idleRows, "; ")))
    end

    cs.pending = anyActive
    if allConverged then cs.verifiedAt = now end
    return true, #pals
end

-- ---------------------------------------------------------------------------
-- Identity migration: adopt orphaned config entries onto re-instanced pals.
-- Acts ONLY when unambiguous — a wrong guess welds one pal's priorities onto
-- another, so any doubt means do nothing and say so once.
-- ---------------------------------------------------------------------------
local function adoptOrphans(now)
    janitor(now)

    -- Owner registry upkeep, ahead of the boot grace: shaping should resume on
    -- player CONNECT, not only when they click. One controller pass covers
    -- every missing owner, and it only runs when one is actually missing.
    for oh, oe in pairs(ownerComps) do
        if not alive(oe.comp) then ownerComps[oh] = nil end
    end
    -- An owner with no live component is usually just OFFLINE, which used to
    -- mean a full object-array walk every 30s for the rest of the session. The
    -- registry answers from its dictionary, walks at most once however many
    -- owners miss together, and backs each absent owner off to a 30s ceiling.
    for _, ce in pairs(config.pals) do
        if ce.owner and ownerComps[ce.owner] == nil then
            local comp = R.compOf(ce.owner, now)
            if alive(comp) then ownerComps[ce.owner] = { comp = comp, at = os.clock() } end
        end
    end

    -- Bases stream in over tens of seconds after start; an entry whose base has
    -- not loaded yet is not an orphan. Judge nothing early.
    if firstTickAt == nil or (now - firstTickAt) < ADOPT_BOOT_GRACE_SECONDS then return end

    for k, at in pairs(liveSeen) do
        if (now - at) > LIVE_PRUNE_SECONDS then
            liveSeen[k] = nil
            liveInfo[k] = nil
        end
    end

    -- Pals whose anchor never became readable are skipped: they can neither be
    -- adopted onto nor counted as a configured twin.
    local unconfByAnchor, confCountByAnchor = {}, {}
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

    -- Entries without an anchor are INERT: never matched, never dropped.
    local orphansByAnchor = {}
    for k, e in pairs(config.pals) do
        if e.anchor ~= nil then
            local at = liveSeen[k]
            if at == nil or (now - at) > LIVE_STALE_SECONDS then
                orphansByAnchor[e.anchor] = orphansByAnchor[e.anchor] or {}
                table.insert(orphansByAnchor[e.anchor], k)
            end
        end
    end

    local changed, touched = false, {}
    for a, orphans in pairs(orphansByAnchor) do
        local cands = unconfByAnchor[a] or {}
        local confCount = confCountByAnchor[a] or 0

        if #orphans == 1 and #cands == 1 and confCount == 0 then
            local oldKey, newKey = orphans[1], cands[1]
            local entry = config.pals[oldKey]
            local info = liveInfo[newKey]
            if info and info.raw then entry.raw = info.raw end
            config.pals[newKey] = entry
            config.pals[oldKey] = nil
            dropState(oldKey)
            dropState(newKey)
            touched[oldKey], touched[newKey] = true, true
            changed = true
            log(string.format("migrated [%s]: %s -> %s (pal was re-instanced)",
                palLabel(entry.name, newKey), oldKey, newKey))
        elseif #cands == 0 and confCount > 0 then
            -- The pal already lives under a NEW configured key; the orphan is
            -- the file bloat this exists to stop accumulating.
            for _, oldKey in ipairs(orphans) do
                local entry = config.pals[oldKey]
                config.pals[oldKey] = nil
                dropState(oldKey)
                touched[oldKey] = true
                changed = true
                log(string.format("dropped superseded config [%s] %s",
                    palLabel(entry and entry.name, oldKey), oldKey))
            end
        elseif #cands >= 1 then
            logOnce("adopt:" .. a, string.format(
                "cannot migrate config for anchor %s (%d orphan(s), %d live candidate(s)) — identical twins cannot be told apart; re-set priorities by clicking those pals",
                a, #orphans, #cands))
        end
        -- else: the pal's base is probably just not loaded — keep waiting.
    end

    if changed then
        markConfigDirty()
        for k in pairs(touched) do pushPal(k) end
    end
end

-- ---------------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------------
function E.tick()
    logOnce("alive", "supervisor loop alive")
    local now = os.clock()
    if firstTickAt == nil then firstTickAt = now end

    pruneJobs(os.time())
    flushConfig(false)

    if next(config.pals) == nil then
        forceAll = false
        return
    end

    discoverCamps(now)

    -- One deferrable enumeration per tick across ALL camps. A camp with real
    -- work to do (demand moved, a pal unconverged, a click) is never held back;
    -- only the periodic verify and liveness sweep queue up, and at 1s ticks a
    -- four-base save still gives every camp a turn well inside VERIFY_SECONDS.
    local budget = { n = 1 }

    local nCamps, nWorked, nPals = 0, 0, 0
    for campId, entry in pairs(camps) do
        if alive(entry.dir) then
            nCamps = nCamps + 1
            local rosterDue = (entry.enumAt == nil) or ((now - entry.enumAt) >= ROSTER_SECONDS)
            local ok, worked, np = pcall(reconcileCamp, campId, entry, now, rosterDue, budget)
            if not ok then
                -- On failure `worked` carries the error, not a result.
                logOnce("camp:" .. campId, "reconcileCamp error: " .. tostring(worked))
            elseif worked then
                nWorked = nWorked + 1
                nPals = nPals + np
            end
        else
            camps[campId] = nil
            campState[campId] = nil
            demand[campId] = nil
            demandSatAt[campId] = nil
            unresolved[campId] = nil
            contSeen[campId] = nil
        end
    end
    forceAll = false

    -- Cost readout. The whole point of the 1.2 restructure is that a steady
    -- state enumerates nothing, so "worked 0/N" on most ticks is the number
    -- that matters — that is the frame time two users uninstalled over.
    if DEBUG then
        tickCount = tickCount + 1
        local ms = (os.clock() - now) * 1000
        if ms > tickWorstMs then tickWorstMs = ms end
        if (tickCount % 10) == 0 then
            local nJobs = 0
            for _ in pairs(jobs) do nJobs = nJobs + 1 end
            -- "pulses" is this second's count, so > PULSE_BUDGET means the
            -- runaway-queue guard is engaging; "sat" lists the flooded types.
            local sat = {}
            for _, byType in pairs(demandSatAt) do
                for t, at in pairs(byType) do
                    if (os.time() - at) <= JOB_FRESH_SECONDS then
                        sat[#sat + 1] = WORKNAME[t] or ("type" .. t)
                    end
                end
            end
            log(string.format(
                "tick #%d: %.2fms (worst %.2fms) | camps worked %d/%d, pals %d, "
                .. "jobs tracked %d, pulses %d/%d%s",
                tickCount, ms, tickWorstMs, nWorked, nCamps, nPals, nJobs,
                pulseCount, PULSE_BUDGET,
                (#sat > 0) and (", SATURATED: " .. table.concat(sat, ",")) or ""))
            tickWorstMs = 0
        end
    end

    if lastAdoptAt == nil or (now - lastAdoptAt) >= ADOPT_INTERVAL_SECONDS then
        lastAdoptAt = now
        local ok, err = pcall(adoptOrphans, now)
        if not ok then logOnce("adoptsweep", "adoptOrphans error: " .. tostring(err)) end
    end
end

-- ---------------------------------------------------------------------------
-- Hook handlers. main.lua registers the hooks, gates them on authority and
-- pcall-wraps every call into here.
-- ---------------------------------------------------------------------------

-- Pending-work intake, and where camps announce themselves. Fires every few
-- seconds per unfilled job.
function E.onRequiredAssignWork(Context, Work, RequirementParameter)
    -- PULSE BUDGET FIRST, before any game access: plain Lua, no marshalling, no
    -- native call, no allocation. A runaway haul queue drives this handler past a
    -- thousand calls a second and the surplus carries nothing the sampled pulses
    -- do not already carry, so the cheapest possible rejection is the whole trick.
    local nowSec = os.time()
    if nowSec ~= pulseSecond then pulseSecond, pulseCount = nowSec, 0 end
    pulseCount = pulseCount + 1
    if pulseCount > PULSE_BUDGET then return end

    local w = Work:get()
    if not alive(w) then return end

    local wk = workKey(w)
    if not wk then
        logOnce("noworkid", "GetWorkId unreadable on a work object — those jobs "
            .. "are skipped rather than counted under an unstable key")
        return
    end
    local e = jobs[wk]
    if e then
        -- Repeat pulse: refresh only. Unresolvable jobs are stored too (t = nil)
        -- precisely so they take this path instead of re-running reflection
        -- every 1-4 seconds forever.
        e.lastSeen = nowSec
        if e.work == nil then e.work = w end
        return
    end

    local dir = Context:get()
    local campId = noteCamp(dir) or NO_CAMP
    local t, sig = resolveWorkType(w)
    -- At the cap this type stops being enumerated: no entry, no retained ref, no
    -- further growth. The stamp is what holds the count up while the flood lasts.
    if t then
        local d = demand[campId]
        if d and (d[t] or 0) >= DEMAND_CAP then
            stampSaturated(campId, t, nowSec)
            return
        end
    else
        -- UNRESOLVABLE work needs the cap too. It contributes no demand
        -- (bumpDemand no-ops on a nil type), so it was never counted and the
        -- count-based cap above could never fire for it — leaving the one
        -- category with no ceiling at all, each entry holding a UObject wrapper
        -- and costing a native alive() in every prune sweep. That is exactly the
        -- unbounded game-thread cost DEMAND_CAP exists to stop, and unmapped
        -- stations are reachable in ordinary play.
        if unresolved[campId] and unresolved[campId] >= DEMAND_CAP then return end
        unresolved[campId] = (unresolved[campId] or 0) + 1
    end

    -- CONTINUOUS-WORK PROBE, on first sight of a signature and never again. A lit
    -- campfire reports RequiredWorkAmount = 0 and burns AutoWorkSelfAmountBySec
    -- instead (verified live by WorkTypeProbe, 2026-07-25), so it has no
    -- completion for finish-the-job to wait on and its pal must stay preemptible.
    -- Both are plain scalars off the work object — safe to read, unlike the
    -- struct-bearing calls the crash rules forbid. The memo is keyed on the same
    -- signature resolveWorkType settled on, so every later job of that shape
    -- costs one table lookup and no reflection at all.
    --
    -- One sighting is enough: the camp's stamp never expires, so repeat pulses of
    -- the same job have nothing left to tell us and stay on the cheap path.
    local cont = false
    if sig then
        cont = contMemo[sig]
        if cont == nil then
            local req, auto = nil, nil
            pcall(function() req = w.RequiredWorkAmount end)
            pcall(function() auto = w.AutoWorkSelfAmountBySec end)
            cont = (req == 0 and type(auto) == "number" and auto > 0)
            contMemo[sig] = cont
        end
    end

    jobs[wk] = { camp = campId, t = t, lastSeen = nowSec, work = w }
    bumpDemand(campId, t, 1)
    if cont then stampContinuous(campId, t) end
end

-- Unassign: a job just opened up. Camp-discovery source only.
function E.onUnassignWork(Context, Work, IndividualId)
    local w = Work:get()
    if not alive(w) then return end
    -- The job re-announces itself through the assign hook if it still needs a
    -- worker; refreshing its timestamp here would keep a completed job counted
    -- as pending.
    pcall(function() noteCamp(Context:get()) end)
end

-- Vanilla toggle observer + component capture.
function E.onToggle(Context, TargetIndividualId, WorkSuitability, bOn)
    -- A GENUINE toggle only ever arrives on a live player's component, so it
    -- unconditionally replaces the cache — this evicts the boot-time
    -- FindFirstOf dud whose RPCs silently no-op. Our own sends prove nothing
    -- about ownership and merely fill an empty cache.
    local toggleComp = nil
    pcall(function()
        local c = Context:get()
        if not alive(c) then return end
        toggleComp = c
        if campComp == nil then
            campComp = c
        elseif not internalCall and c ~= campComp then
            campComp = c
        end
        if not internalCall then registerOwnerComp(S.fullNameOf(c), c) end
    end)
    if internalCall then return end

    local id = TargetIndividualId:get()
    local work = WorkSuitability:get()
    local on = bOn:get()
    local key = palKey(id.PlayerUId, id.InstanceId)
    local cfg = config.pals[key]

    -- Modded source? A fresh per-component PrioMod_Dir marker (the client
    -- attests every click it originates), or failing that a component that has
    -- spoken our protocol before.
    --
    -- This used to sit behind a CYCLE_MODE flag whose false branch was described
    -- as "binary semantics". It was nothing of the kind: with it off, `step`
    -- could never be assigned, so EVERY toggle — modded or not — fell through to
    -- the release path below and un-configured the pal. The first click of a
    -- session would have started dismantling the player's whole setup. There is
    -- no binary behaviour to preserve, so the flag is gone rather than fixed.
    local step, compName = nil, nil
    pcall(function()
        local c = Context:get()
        if alive(c) then compName = S.fullNameOf(c) end
    end)
    if compName then
        local m = pendingDirByComp[compName]
        if m and (os.clock() - m.at) < 1.0 then
            step = m.dir
            pendingDirByComp[compName] = nil
        else
            local seen = moddedComps[compName]
            if seen and (os.clock() - seen.at) < MODDED_TTL_SECONDS then step = 1 end
        end
    end

    if step == nil then
        -- UNMODDED source: vanilla checkboxes bypass the mod entirely. A
        -- configured pal touched this way is RELEASED — restore its off-list to
        -- the binary reading of its priorities, keep the toggle the user just
        -- made, then forget the pal.
        if not cfg then return end

        -- The restore below is the pal's ONLY way back to a sane off-list, and
        -- the release drops the config that could otherwise heal it later. So a
        -- restore we could not actually perform must abort the release rather
        -- than proceed: better a pal that stays configured (and gets another
        -- chance next click) than one left wearing a fence with nothing left to
        -- remove it.
        local fid, fparam = findPalByKey(key)
        if not fparam then
            logOnce("relnopal:" .. key, string.format(
                "release deferred for [%s] — pal not enumerable right now, "
                .. "keeping its config so its off-list can still be restored",
                palLabel(cfg.name, key)))
            return
        end
        -- A failed read yields mask 0, which reads as "nothing is off" — so every
        -- restore comparison below would conclude there is nothing to re-enable
        -- and send nothing, leaving the pal wearing its fence with its config
        -- deleted underneath it.
        local offMask, okRead = readOffMask(fparam)
        if not okRead then
            logOnce("relnooff:" .. key, string.format(
                "release deferred for [%s] — off-list unreadable, "
                .. "restoring blind would strand the pal", palLabel(cfg.name, key)))
            return
        end

        local raw = cfg.raw
        if not raw then
            local okr, r = pcall(extractRaw, fid)
            if okr then raw = r end
        end
        if not raw then
            logOnce("relnoraw:" .. key, string.format(
                "release deferred for [%s] — no raw instance id, cannot restore",
                palLabel(cfg.name, key)))
            return
        end

        for t = WORK_MIN, WORK_MAX do
            if t ~= work then
                local has = false
                pcall(function() has = fparam:HasWorkSuitability(t) end)
                if has then
                    local wantOn = (cfg.prio[t] or 0) >= 1
                    local isOn = not Planner.has(offMask, t)
                    if wantOn ~= isOn then
                        -- Route through the component that just proved authority
                        -- over this pal, not cfg.owner: if the manager is offline
                        -- the restore would silently not happen and the pal would
                        -- keep its fenced off-list with no config left to fix it.
                        sendToggle(raw, t, wantOn, nil, toggleComp)
                    end
                end
            end
        end

        config.pals[key] = nil
        dropState(key)
        markConfigDirty()
        flushConfig(true)
        pushPal(key)
        log(string.format(
            "released [%s]: unattested toggle — pal returned to vanilla on/off",
            palLabel(cfg.name, key)))
        return
    end

    -- MODDED cycle path.
    local ownerHex = compName and R.ownerOf(compName) or nil
    local fid, fparam = findPalByKey(key)

    -- Clicking a column the pal cannot work must not create or cycle a bogus
    -- entry. Verify against the live pal; without one, only allow types the
    -- config already manages.
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
        if not fparam then return end   -- not a base pal

        -- Before minting defaults, check whether an ORPHANED entry (pal
        -- re-instanced on restart/redeploy) carries this pal's anchor — the user
        -- clicking it before the sweep notices.
        local myAnchor = anchorOf(fparam)
        local orphanKey, orphanN = nil, 0
        if myAnchor then
            for k2, e2 in pairs(config.pals) do
                if k2 ~= key and e2.anchor == myAnchor then
                    local at = liveSeen[k2]
                    if at == nil or (os.clock() - at) > LIVE_STALE_SECONDS then
                        orphanN = orphanN + 1
                        orphanKey = k2
                    end
                end
            end
        end
        if orphanN == 1 then
            cfg = config.pals[orphanKey]
            local okr, raw = pcall(extractRaw, fid or id)
            if okr then cfg.raw = raw end
            config.pals[key] = cfg
            config.pals[orphanKey] = nil
            dropState(orphanKey)
            dropState(key)
            log(string.format("adopted config [%s] on first click", palLabel(cfg.name, key)))
            pushPal(orphanKey)
        end
    end

    if not cfg then
        -- Auto-configure on first touch: enabled -> 3, disabled -> 0. The
        -- clicked type is seeded from bOn (the NEW state the click is
        -- requesting), so its PRE-click value is used regardless of whether the
        -- game has applied the write yet. Seeding it from the off-list instead
        -- made the first click on an enabled cell land on 1 and on an X cell
        -- land on 4, contradicting both the docs and the dim preview the client
        -- shows.
        local offMask = readOffMask(fparam)
        local prio, nInit = {}, 0
        for t = WORK_MIN, WORK_MAX do
            local okh, has = pcall(function() return fparam:HasWorkSuitability(t) end)
            if okh and has then
                if t == work then
                    prio[t] = on and 0 or 3
                else
                    prio[t] = Planner.has(offMask, t) and 0 or 3
                end
                nInit = nInit + 1
            end
        end
        cfg = { name = displayName(fid or id, fparam), anchor = anchorOf(fparam),
                owner = ownerHex, prio = prio }
        local okr, raw = pcall(extractRaw, fid or id)
        if okr then cfg.raw = raw end
        config.pals[key] = cfg
        log(string.format("auto-config [%s]: %d work type(s) initialized",
            palLabel(cfg.name, key), nInit))
    end

    -- 0->1->2->3->4->5->0, or the reverse for a -1 marker. Lua's % handles the
    -- negative wrap.
    local new = ((cfg.prio[work] or 0) + step) % 6

    -- A different modded player clicking this pal TAKES OVER its management:
    -- their component is the freshest proven authority.
    if ownerHex and cfg.owner ~= ownerHex then cfg.owner = ownerHex end

    cfg.prio[work] = new
    markConfigDirty()
    pushPal(key)
    vlog(string.format("cycle [%s] %s -> %d",
        palLabel(cfg.name, key), WORKNAME[work] or ("type" .. work), new))

    -- Force the next tick to revisit every camp so the checkbox visual snaps
    -- without waiting for a demand change.
    dropState(key)
    forceAll = true
end

-- Client -> server transport.
function E.onServerInt32(Context, BaseCampId, FunctionName, Value)
    local name = FunctionName:get():ToString()
    if type(name) ~= "string" then return end
    if name:sub(1, 8) ~= "PrioMod_" then return end

    local compName, compRef = nil, nil
    pcall(function()
        local c = Context:get()
        if alive(c) then
            compName = S.fullNameOf(c)
            compRef = c
        end
    end)
    -- ANY PrioMod_* message proves this component belongs to a real modded
    -- player, so it becomes the send target — evicting a boot-time FindFirstOf
    -- dud whose writes silently no-op.
    if compName then moddedComps[compName] = { comp = compRef, at = os.clock() } end
    if compRef ~= nil then campComp = compRef end
    if compName and compRef then registerOwnerComp(compName, compRef) end

    if name == "PrioMod_Ping" then
        log(string.format("PrioMod_Ping received (value=%d) — client mod announced%s",
            Value:get(), compName and (" on " .. compName) or ""))
        -- Full state to this client. PrioReset first, so a pal released while it
        -- was disconnected stops showing numbers.
        if compRef and alive(compRef) then
            sendSync(compRef, "PrioReset")
            for key, cfg in pairs(config.pals) do
                sendSync(compRef, packSyncMsg(key, cfg))
            end
        end
        return
    end

    if name == "PrioMod_Dir" then
        -- Direction for the toggle that immediately follows (+1 left-click,
        -- -1 right-click). Stale after 1s.
        if compName then
            local v = Value:get()
            pendingDirByComp[compName] = {
                dir = (v and v < 0) and -1 or 1,
                at = os.clock(),
            }
        end
        return
    end

    logOnce("prio:" .. name, "unknown PrioMod command: " .. name)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function E.activate()
    local resolved, found = resolveConfigPath()
    CONFIG_PATH = resolved
    log(string.format("config path: %s (%s)", CONFIG_PATH, found and "found" or "NOT found on disk"))

    local cfg, lerr = loadConfig(CONFIG_PATH)
    local n = 0
    if cfg then
        config = cfg
        for _ in pairs(config.pals) do n = n + 1 end
        log(string.format("config loaded: %d pal(s) configured", n))
    else
        config = { pals = {} }
        log("config load failed (" .. tostring(lerr) .. ") — starting with empty config")
    end

    -- The primary came back empty. If the out-of-folder mirror still has pals,
    -- a deployment restored a stock priorities.lua over the player's — restore
    -- rather than let them find out by watching their pals go vanilla.
    if n == 0 then
        local mp = mirrorPath()
        local mcfg = mp and loadConfig(mp) or nil
        local mn = 0
        if mcfg then for _ in pairs(mcfg.pals) do mn = mn + 1 end end
        if mn > 0 then
            config = mcfg
            log(string.format(
                "RESTORED %d pal(s) from %s — the config in the mod folder was empty, "
                .. "which usually means a mod manager or Workshop update overwrote it. "
                .. "Delete that file if you meant to clear your priorities.", mn, mp))
            writeConfig(config)
        end
    end
    configDirty, configDirtyAt = false, nil
end

-- Session teardown. Every UObject ref held here belongs to the world that is
-- going away, so all of it goes; classMemo and contMemo are per-build facts about
-- the game's own work classes and stay — contSeen, which is about a particular
-- camp in a particular save, does not.
-- Pending clicks are written out first — the config file outlives the session.
function E.reset()
    pcall(flushConfig, true)

    config = { pals = {} }
    configDirty, configDirtyAt = false, nil

    camps, campState, jobs, demand = {}, {}, {}, {}
    demandSatAt, unresolved, contSeen = {}, {}, {}
    pulseSecond, pulseCount = 0, 0
    palState = {}
    liveSeen, liveInfo = {}, {}
    idleFencedSince, lastIdleReportAt = {}, nil

    campComp, internalCall = nil, false
    ownerComps, moddedComps, pendingDirByComp = {}, {}, {}

    firstTickAt = nil
    lastAdoptAt, lastDiscoverAt = nil, nil
    forceAll = false
    tickCount, tickWorstMs = 0, 0
end

-- F8: reload priorities.lua from disk, drop the reconcile state so every camp
-- is re-planned against it.
function E.reload()
    local ok, err = pcall(function()
        local cfg, lerr = loadConfig(CONFIG_PATH)
        if not cfg then
            log("F8 reload FAILED: " .. tostring(lerr))
            return
        end
        config = cfg
        palState, campState = {}, {}
        local n = 0
        for _ in pairs(config.pals) do n = n + 1 end
        log(string.format("F8 reloaded: %d pal(s) configured; state reset", n))
    end)
    if not ok then log("F8 error: " .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- F9 roster dump
-- ---------------------------------------------------------------------------
function E.dumpRoster()
    local ok, err = pcall(function()
        log("=== ROSTER DUMP ===")
        local now = os.clock()
        pruneJobs(os.time())

        for campId, entry in pairs(camps) do
            local d = demand[campId] or {}
            local psum = {}
            for t = WORK_MIN, WORK_MAX do
                if (d[t] or 0) > 0 then
                    psum[#psum + 1] = (WORKNAME[t] or ("type" .. t)) .. "=" .. d[t]
                end
            end
            log(string.format("-- camp %s -- pending: %s", campId:sub(1, 8),
                #psum > 0 and table.concat(psum, ", ") or "(none)"))

            local pals, ctx = {}, {}
            local stats = {}
            enumerateDir(entry.dir, function(_, id, param)
                local key = palKey(id.PlayerUId, id.InstanceId)
                local name = displayName(id, param)
                local cfg = config.pals[key]
                if not cfg then
                    log(string.format("  %s  %s  (unconfigured)", key, name))
                    return
                end
                if not param then return end
                local s = refreshManaged(key, param, cfg, now)
                local cur = nil
                pcall(function()
                    local c = param:GetCurrentWorkSuitability()
                    if type(c) == "number" then cur = c end
                end)
                ctx[key] = { cfg = cfg, name = name, state = s, param = param, cur = cur }
                pals[#pals + 1] = {
                    key = key, prio = cfg.prio, managed = s.managed, current = cur, rank = s.rank,
                }
            end, stats)

            local plan = Planner.plan(pals, d, {
                protectCurrent = PROTECT_CURRENT,
                continuous = continuousSetOf(campId),
            })
            for key, c in pairs(ctx) do
                local r = plan[key] or {}
                log(string.format("  %s  %s", key, c.name))

                local prioParts = {}
                for _, t in ipairs(Planner.listFromMask(c.state.managed)) do
                    prioParts[#prioParts + 1] =
                        string.format("%s=%d", WORKNAME[t] or ("type" .. t), c.cfg.prio[t] or 0)
                end
                log("    prio: " .. (#prioParts > 0 and table.concat(prioParts, " ")
                    or "(no suitabilities readable)"))

                local en = {}
                for _, t in ipairs(Planner.listFromMask(r.enabled or 0)) do
                    en[#en + 1] = WORKNAME[t]
                end
                log(string.format("    plan: bar=%s claim=%s cur=%s | want-on {%s}",
                    tostring(r.bar), r.claim and (WORKNAME[r.claim] or r.claim) or "none",
                    (type(c.cur) == "number" and WORKNAME[c.cur]) or "none",
                    table.concat(en, ",")))

                local offMask = readOffMask(c.param)
                local offParts = {}
                for _, t in ipairs(Planner.listFromMask(offMask)) do
                    offParts[#offParts + 1] = WORKNAME[t]
                end
                log(string.format("    off-list game {%s}  applied=%s",
                    table.concat(offParts, ","), tostring(c.state.applied)))
            end
            log(string.format(
                "  [diag] src=%s slots=%d noContainer=%d noSlots=%d nilSlot=%d invalid=%d noId=%d ok=%d",
                tostring(stats.slotSource), stats.slots or 0, stats.noContainer or 0,
                stats.noSlots or 0, stats.nilSlot or 0, stats.invalid or 0,
                stats.noId or 0, stats.ok or 0))
        end
        log("=== END DUMP ===")
    end)
    if not ok then log("F9 dump error: " .. tostring(err)) end
end

return E
