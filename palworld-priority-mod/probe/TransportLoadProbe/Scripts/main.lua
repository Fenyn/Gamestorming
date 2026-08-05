-- ============================================================================
-- TransportLoadProbe — read-only measurement mod for PalPriority.
-- UE4SS (Okaetsu fork) Lua mod. Palworld 1.0. DEV ONLY — never shipped.
--
-- WHY
--   PalPriority 1.3 adds two runaway-queue guards to the engine (DEMAND_CAP and
--   PULSE_BUDGET) on the strength of a SIMULATED model of what a high-output
--   station does to the pending-work tracker. The model says:
--
--     * the trigger is production rate crossing HAULING CAPACITY, not items/sec
--       on its own — below that line the queue is ~0, above it the queue grows
--       linearly and never settles;
--     * OnRequiredAssignWork re-pulses every 1-4s per UNFILLED job, so the hook
--       rate is roughly (queue depth / 2.5) calls per second — hundreds to
--       thousands on a lategame base;
--     * both of the costs that scale with that queue land on the GAME THREAD,
--       which is where pal AI runs, so the backlog starves the very pals that
--       would have cleared it.
--
--   None of that has been measured in a real base. This probe measures it. If
--   the numbers come back small, the guards are harmless but the diagnosis was
--   wrong and the real cause is still open.
--
--   The 1.3 redesign goes further than guarding the estimator: it wants to DELETE
--   it and read the game's own state instead. Header/source verification on
--   2026-07-26 (three agreeing sources: PalworldModdingKit @62fad41, a Dumper-7
--   SDK dump, and the game's own .usmap) settled WHICH state — see
--   `docs/callpath-map.md`, "Director & work internals". Short version:
--   `FPalBaseCampWorkAssignRequest` has ZERO reflected members, so
--   `RequiredAssignWorks` is a LENGTH and nothing else; the readable demand and
--   occupancy data lives on `UPalWorkBase` (`AssignLocations`,
--   `AssignRepInfoArray.Items` -> `UPalWorkAssign`) and on
--   `UPalWorkProgressManager` (`WorkAssignDefineMap`, `WorkMap_InServer`).
--   None of that has ever been read from Lua on this build. Section 4 is what
--   verifies it at runtime.
--
-- WHAT IT CAPTURES
--   1. LOAD (continuous, every REPORT_SECONDS): exact hook A calls/sec with a
--      running peak, plus the distinct unfilled jobs seen per window broken down
--      by camp and work type. Distinct-job count is the queue depth the engine
--      would be tracking; pulses/sec is what it would be paying for it.
--   2. CAPACITY (F6): every base pal's work-suitability RANK for all 13 types.
--      Rank is the only capacity signal the engine already reads
--      (GetWorkSuitabilityRankWithCharacterRank, engine.lua) and it is what the
--      allocator's candidate sort is keyed on. This dump says what the scale
--      actually is, and a guarded scalar sweep of the pal's parameter object
--      looks for anything that reads like an items-per-trip number. It also
--      records the three candidate IDLE signals per pal side by side, which is
--      what the idle-pal/overseer model needs to pick one.
--   3. UNHOOK (F7): detaches hook A via UnregisterHook, waits, re-attaches.
--      main.lua used to claim UE4SS has no reliable unhook; UnregisterHook is in
--      fact documented in ue4ss/Mods/shared/Types.lua and used by
--      ConsoleEnablerMod. The probe's own pulse counter is the evidence — it
--      should fall to zero while detached and recover after. If it does, the
--      engine can detach this hook under load instead of merely rejecting fast.
--   4. STEP-3 ARCHITECTURE (F5) — THE ONE THAT GATES THE REDESIGN. Dumps every
--      property on PalBaseCampWorkerDirector by name and type, then answers the
--      four questions the redesign is built on, each with its own verdict line:
--        a. INDEX BASE — are Lua array reads 0- or 1-based on this build? Not
--           documented anywhere upstream, and an out-of-range `arr[i]` READ
--           MUTATES the game's array (UE4SS's shared read/write path calls
--           AddZeroed), so nothing may index-walk until this is measured.
--        b. WaitingWorkerIndividualIds — length, and whether its FPalInstanceID
--           entries yield the engine's palKey. That is the idle trigger.
--        c. OCCUPANCY CHAIN — `work.AssignLocations` +
--           `work.AssignRepInfoArray.Items` -> `UPalWorkAssign { State,
--           WorkingState, AssignedIndividualId, bFixed }`. Fully reflected, and
--           the replacement for the banned GetWorkAssignInfo. This is the real
--           per-slot demand source: which slots exist and who is in them.
--        d. UPalWorkProgressManager — `WorkAssignDefineMap` (the game's own
--           station -> suitability/WorkerMaxNum table, which would fix the
--           OilExtraction hole generically) and `WorkMap_InServer`. Both TMaps,
--           and the Lua-side TMap API is the single biggest unknown on this
--           build, so F5 tries key lookup AND iteration and reports which works.
--      RequiredAssignWorks is now LENGTH ONLY, permanently: its elements carry
--      no reflected members, so a walk buys nothing and costs real risk. The
--      length still prints next to the pulse-derived count every window, which
--      is the accuracy evidence.
--   5. WORK ANATOMY (F8): one record per distinct job SIGNATURE
--      (class | AssignDefineDataId | OverrideWorkType) with RequiredWorkAmount
--      and AutoWorkSelfAmountBySec. Three answers at once: which stations are
--      still invisible to the work-type map, which work is CONTINUOUS
--      (RequiredWorkAmount = 0 never completes, so it must stay preemptible),
--      and what EPalWorkType 17 really is.
--
-- SAFETY (why this does not crash — see ../../../docs/callpath-map.md)
--   - alive() (strict IsValid) before EVERY member call on EVERY received object.
--   - Property VALUES read only for the types in SCALAR_PROP_TYPES. Object /
--     Struct / Array / SoftObject values are named but never read: reading a
--     SoftObjectProperty is a native AV that pcall CANNOT catch. The director
--     sweep in F5 obeys this too — it NAMES the array properties and only then
--     tries the specifically wanted ones, each in its own pcall.
--   - No ForEach on any director- or work-owned array. UE4SS's TArray:ForEach
--     carries an author TODO at the element-push site, open since 2023 and
--     present in this build ("Fix crash that occurs here... It seems to only
--     affect large arrays"), and it snapshots the data pointer and count once
--     while running Lua between elements, so a churning game array dangles it.
--     Bounded index loops against a GetArrayNum() re-read taken IMMEDIATELY
--     before the loop instead — never past the end (see the index-base block).
--   - No FString reads off game structs. FPalInstanceID.DebugName is skipped
--     deliberately: FString marshalling is the documented weak point on an
--     engine whose offsets are patched by MemberVariableLayout.ini, and the two
--     GUIDs are all the palKey needs.
--   - GetWorkAssignInfo is never called (removed crash suspect). F5's occupancy
--     chain is the reflected replacement for it.
--   - The probe never writes game state at all. No RPCs, no toggles, no
--     assignment — F9 checks whether an RPC exists and stops there.
--   - The probe's own per-pulse work is budgeted, so measuring a flood cannot
--     itself become the flood. The director sample is budgeted the same way.
--
-- HOW TO RUN
--   1. This hook is SERVER-INTERNAL. Run it where the base pals live: single
--      player, a co-op HOST, or a dedicated server. On a remote client it will
--      correctly report zero — that is not a failure, it is the wrong machine.
--   2. Copy this TransportLoadProbe folder into ...\Win64\ue4ss\Mods\
--      (alongside PalPriority). It ships an enabled.txt, so no mods.txt edit.
--   3. Load the save with the base that misbehaves. Stand in it and let it run.
--      Reports print every 15s on their own — no keys needed for the main
--      measurement.
--   4. Press F5 once, early — then press it AGAIN a minute later, and once more
--      while a pal is visibly working a station. Half of F5 needs things that
--      only exist after hook A has pulsed (a live work object, a real
--      AssignDefineDataId) or while a slot is actually occupied. Everything
--      else is optional; this one is not.
--   5. Do the thing that triggers the bug: turn on the high-output station(s)
--      and let the item pile grow for 5-10 minutes. Watch "queue" climb.
--   6. Press F8 once. Then walk past an OIL RIG, mill, cooler, medicine bench,
--      lab, farm plot, ranch and furnace, and press F8 again — it only sees
--      stations whose work has pulsed since the probe loaded, so the second
--      press is what catches the ones the map is missing.
--   7. Press F6 once while in the base (capacity + idle-signal dump). Best done
--      while at least one pal is visibly standing around doing nothing.
--   8. Press F7 once (unhook test), and let the next two reports print.
--   9. Send me  ue4ss\Mods\TransportLoadProbe\transport-load-dump.txt
--
--   The single most important line is the peak pulses/sec next to the queue
--   depth. If queue climbs without bound and pulses/sec follows it, the
--   diagnosis holds. The second most important is F5's verdict block.
-- ============================================================================

local VERSION = "1.2"
local REPORT_SECONDS = 15

-- The probe's own per-second budget for WorkId extraction. Pulses are ALWAYS
-- counted (that is free); only the distinct-job bookkeeping is capped, so a
-- genuine flood cannot make the measurement the problem it is measuring.
local SAMPLE_BUDGET = 400

local function log(msg)
    print(string.format("[TransportLoadProbe] %s\n", msg))
end

log(string.format("v%s loading...", VERSION))

-- ---------------------------------------------------------------------------
-- Safety helpers (same contracts as the engine — see the header).
-- ---------------------------------------------------------------------------
local function alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

local function fstr(x)
    if x == nil then return nil end
    if type(x) == "string" then return x end
    local ok, s = pcall(function() return x:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

local function norm(v) return v % 0x100000000 end

local function guidStr(g)
    local s = nil
    pcall(function()
        s = string.format("%08X%08X%08X%08X", norm(g.A), norm(g.B), norm(g.C), norm(g.D))
    end)
    return s
end

local SCALAR_PROP_TYPES = {
    ByteProperty = true, EnumProperty = true, IntProperty = true,
    Int64Property = true, BoolProperty = true, FloatProperty = true,
    DoubleProperty = true, NameProperty = true, StrProperty = true,
}

local WORKNAME = {
    [1] = "Kindling", [2] = "Watering", [3] = "Seeding", [4] = "Power",
    [5] = "Handcraft", [6] = "Collection", [7] = "Deforest", [8] = "Mining",
    [9] = "Oil", [10] = "Medicine", [11] = "Cool", [12] = "TRANSPORT",
    [13] = "Ranch",
}

-- Same map the engine uses, so the probe's type attribution matches the
-- engine's. Deliberately a copy: the probe must not depend on the mod.
local WORKTYPE_TO_SUIT = {
    [3]=5, [4]=5, [5]=6, [6]=6, [7]=12, [8]=3, [9]=2, [10]=1, [11]=12, [12]=5,
    [13]=5, [14]=1, [15]=10, [16]=12, [17]=6, [18]=7, [19]=8, [20]=7, [21]=8,
    [22]=4, [23]=1, [26]=13, [27]=2, [28]=11, [29]=2, [40]=5, [44]=12, [45]=12,
    [46]=6,
}
local CLASS_TYPE_MAP = {
    PalWorkTransportItemInBaseCamp = 12,
    PalWorkDeforestFoliage         = 7,
    PalWorkCollectResource         = 6,
}

-- ---------------------------------------------------------------------------
-- Output: console + append-only file, closed after every write so a crash
-- never loses what was already measured.
-- ---------------------------------------------------------------------------
local OUT_PATH = "Mods/TransportLoadProbe/transport-load-dump.txt"

pcall(function()
    for entry in string.gmatch(package.path or "", "[^;]+") do
        local base = entry:match("^(.*[/\\]Mods[/\\]TransportLoadProbe)[/\\]Scripts[/\\]%?%.lua$")
        if base then
            OUT_PATH = base .. "/transport-load-dump.txt"
            break
        end
    end
end)

local outFailed = false
local function out(line)
    log(line)
    if outFailed then return end
    local ok = pcall(function()
        local f = io.open(OUT_PATH, "a")
        if not f then outFailed = true return end
        f:write(line, "\n")
        f:close()
    end)
    if not ok then outFailed = true end
end

-- ---------------------------------------------------------------------------
-- Measurement 1: load. Counters only — no game access beyond what the hook
-- already handed us, and the expensive part is budgeted.
-- ---------------------------------------------------------------------------
local pulsesThisSecond, pulseSecond = 0, 0
local peakPulsesPerSecond = 0
local pulsesThisWindow = 0
local sampleBudgetLeft = SAMPLE_BUDGET
local windowJobs = {}        -- workId -> "camp|type", reset every window
local windowStart = os.time()
local reportN = 0
local sampleCapped = false
local classMemo = {}         -- class|override -> suitability | false

-- Measurement 5 state: one entry per distinct job signature, accumulated for the
-- whole session (NOT reset per window) so F8 can be pressed late and still see
-- every station that pulsed since load.
local workSigs = {}          -- "class|assignId|overrideType" -> record
local workSigCount = 0

-- Two things F5 cannot conjure for itself, both harvested for free from hook A:
--   lastWork      — a real UPalWorkBase to walk the occupancy chain on. Retained
--                   deliberately across ticks (it is replaced constantly) and
--                   alive()-gated at every use, per the wrapper crash rule.
--   lastAssignId  — a station id the game itself produced, so the
--                   WorkAssignDefineMap key-lookup experiment uses a key that
--                   definitely exists rather than a guess. Captured only when a
--                   NEW signature appears, so it adds no per-pulse read.
local lastWork = nil
local lastAssignId = nil

local function resolveType(w)
    local name = nil
    pcall(function() name = w:GetClass():GetFName():ToString() end)
    if not name then return nil end
    local wt = nil
    pcall(function() wt = w.OverrideWorkType end)
    local key = name .. "|" .. tostring(wt)
    local memo = classMemo[key]
    if memo ~= nil then
        if memo == false then return nil end
        return memo
    end
    local found = nil
    if type(wt) == "number" and wt ~= 0 then found = WORKTYPE_TO_SUIT[wt] end
    if not found then
        for sub, t in pairs(CLASS_TYPE_MAP) do
            if name:find(sub, 1, true) then found = t break end
        end
    end
    classMemo[key] = found or false
    return found
end

-- ---------------------------------------------------------------------------
-- Measurement 4: the director's own state.
--
-- This is the measurement the redesign depends on. Header verification
-- (2026-07-26, three agreeing sources) fixed what is worth reading here:
--
--   * RequiredAssignWorks : TArray<FPalBaseCampWorkAssignRequest> — the element
--     struct has ZERO reflected members (0x30 of padding in the SDK dump,
--     propCount=0 in the game's .usmap). GetArrayNum() therefore extracts 100%
--     of the information the array carries. LENGTH ONLY, permanently.
--   * WaitingWorkerIndividualIds : TArray<FPalInstanceID> — FPalInstanceID IS
--     fully reflected, so entries can yield the engine's palKey and "this pal
--     is idle" stops being an inference. Worth walking, carefully.
--   * WorkerTasks — scheduled base CHORES (its task enum is
--     {Undefined, IgnitionTorchAtNight}), not per-worker work state. Length
--     only, reported so nobody mistakes it for a work queue again.
--
-- All three are Transient and NOT replicated: they read as empty on a client.
-- That is the wrong machine, not a failure.
-- ---------------------------------------------------------------------------
local dirSnapshot = nil        -- plain Lua, refreshed on the game thread per window
local dirSampleErr = nil

-- Bound every walk: reading the director must NOT cost something proportional to
-- a runaway queue. The idle list is a roster subset, so 16 is already generous;
-- occupancy is per-slot, and no station has four-plus slots worth sampling.
local WAIT_WALK_CAP = 16
local OCC_WALK_CAP = 4
local PAL_WALK_CAP = 64

local function arrayLen(arr)
    -- Both forms compile to a bare FScriptArray::Num() read — the cheapest and
    -- safest operation UE4SS exposes on a TArray, and the offsets it depends on
    -- are among those explicitly corrected by the shipped Palworld
    -- MemberVariableLayout.ini.
    local n = nil
    pcall(function() n = arr:GetArrayNum() end)
    if type(n) ~= "number" then
        pcall(function() n = #arr end)
    end
    return (type(n) == "number") and n or nil
end

-- ---------------------------------------------------------------------------
-- TArray ELEMENT access on this build — two source-verified hazards (UE4SS
-- @c838a8a, the exact commit the Okaetsu Palworld release builds; the fork
-- carries zero source changes, only a MemberVariableLayout.ini):
--
--   * TArray:ForEach has an author TODO at the element-push site, open since
--     v2.5.2 (2023) and present here: "Fix crash that occurs here. It appears
--     that the Lua stack is getting corrupted somehow, or lua_object is getting
--     GC'd by Lua. It seems to only affect large arrays". It also snapshots the
--     data pointer and element count ONCE and runs Lua between elements, so an
--     array the game reallocates mid-iteration leaves it walking freed memory.
--     The director's queue is precisely that kind of array.
--   * arr[i] past the end MUTATES the game's array. Read and write share one
--     implementation that calls AddZeroed for any out-of-range index, so an
--     out-of-bounds READ appends zeroed elements to the live array.
--
-- And the Lua-side index base is undocumented upstream. So: measure the base
-- once, on a NON-EMPTY array (where index 0 is in range under a 0-based build
-- and below the range — never past the end — under a 1-based one), and let no
-- index loop run until it is known.
-- ---------------------------------------------------------------------------
local indexBase = nil          -- 0, 1, or nil = undetermined (walks stay off)
local indexBaseVerdict = "UNDETERMINED (F5 has not run, or found no non-empty array)"
local indexBaseTried = false
local indexBaseAnnounced = false

-- FPalInstanceID -> the engine's palKey (shared.lua:78). DebugName is an FString
-- and is NEVER read: FString marshalling is the documented weak point on an
-- offset-patched engine, and the two GUIDs are the whole key.
local function palKeyOf(v)
    if v == nil then return nil end
    local p, i = nil, nil
    pcall(function() p = guidStr(v.PlayerUId) end)
    pcall(function() i = guidStr(v.InstanceId) end)
    if p and i then return p .. "-" .. i end
    if i then return "?-" .. i end
    return nil
end

-- sigFn(elem) must return a short string for a REAL element and nil for anything
-- unreadable — that is what separates "index 0 exists" from "index 0 is not how
-- this build counts". Prints its own working; sets indexBase/indexBaseVerdict.
local function detectIndexBase(arr, sigFn, label)
    if indexBase ~= nil or arr == nil then return indexBase end
    if indexBaseTried then return nil end

    local nBefore = arrayLen(arr)
    if type(nBefore) ~= "number" or nBefore < 1 then
        -- Not a failure, just nothing to measure on. Stay retryable.
        return nil
    end
    indexBaseTried = true

    out(string.format("      index-base detection on %s (%d element(s))", label, nBefore))

    -- (1) arr[0] — in range if 0-based, below the range if 1-based. Either way
    --     not PAST the end, so the AddZeroed growth path cannot fire.
    local sig0 = nil
    pcall(function() sig0 = sigFn(arr[0]) end)

    -- (2) cross-check with the FIRST element via ForEach, aborted immediately by
    --     returning true (early termination is supported on this build). One
    --     element is the smallest possible exposure to the ForEach TODO crash,
    --     which is reported to bite on large arrays.
    local sigF = nil
    pcall(function()
        arr:ForEach(function(_, elem)
            local v = elem
            local okg, got = pcall(function() return elem:get() end)
            if okg then v = got end
            pcall(function() sigF = sigFn(v) end)
            return true
        end)
    end)

    -- (3) arr[1], and ONLY with two or more elements — on a single-element
    --     0-based array index 1 is past the end, and the read itself would grow
    --     the game's array.
    local sig1 = nil
    if nBefore >= 2 then
        pcall(function() sig1 = sigFn(arr[1]) end)
    end

    local nAfter = arrayLen(arr)
    out(string.format("        arr[0]=%s  ForEach[first]=%s  arr[1]=%s",
        tostring(sig0), tostring(sigF), tostring(sig1)))

    if type(nAfter) == "number" and nAfter ~= nBefore then
        out("        *** LENGTH CHANGED DURING DETECTION: " .. nBefore .. " -> " .. nAfter)
        out("        *** A READ MUTATED THE GAME'S ARRAY (or the game did, mid-probe).")
        out("        *** Index walks stay DISABLED. Press F5 again: if this repeats,")
        out("        *** it is the read, and it is the single most important line in")
        out("        *** the dump. If it never repeats, the game just moved under us.")
        indexBaseVerdict = string.format(
            "UNDETERMINED — length moved %d -> %d during detection; walks disabled",
            nBefore, nAfter)
        indexBaseTried = false     -- one retry per F5 press, user-driven only
        return nil
    end

    if sigF ~= nil and sig0 == sigF then
        indexBase = 0
        indexBaseVerdict = "0-based (arr[0] matches ForEach's first element)"
    elseif sigF ~= nil and sig1 ~= nil and sig1 == sigF then
        indexBase = 1
        indexBaseVerdict = "1-based (arr[1] matches ForEach's first element)"
    elseif sigF == nil and sig0 ~= nil then
        indexBase = 0
        indexBaseVerdict = "0-based, UNCONFIRMED (arr[0] read; ForEach yielded nothing to check it against)"
    elseif sigF == nil and sig0 == nil and sig1 ~= nil then
        indexBase = 1
        indexBaseVerdict = "1-based, UNCONFIRMED (arr[0] empty, arr[1] read, no ForEach cross-check)"
    else
        indexBaseVerdict = "UNDETERMINED (no index and no ForEach produced a readable element)"
    end
    out("        verdict: " .. indexBaseVerdict)
    return indexBase
end

-- ForEach wrapper, kept ONLY for the small stable arrays it was already used on
-- (the pal container's SlotArray — months of production use in the shipped mod).
-- Do NOT point it at a director- or work-owned array: those are the churny ones
-- the ForEach TODO crash and the snapshot-pointer problem apply to. Bounded
-- index loops for those.
local function forEachArray(arr, cap, fn)
    if arr == nil then return 0 end
    local seen = 0
    local ok = pcall(function()
        arr:ForEach(function(_, elem)
            if seen >= cap then return true end
            seen = seen + 1
            local v = elem
            local okg, got = pcall(function() return elem:get() end)
            if okg then v = got end
            fn(v)
        end)
    end)
    -- Fall back ONLY if the ForEach path processed nothing. If it threw partway
    -- through, re-walking numerically would hand the caller the same elements
    -- twice, and the caller is accumulating counts.
    if ok or seen > 0 then return seen end
    seen = 0
    pcall(function()
        local n = arrayLen(arr) or 0
        if n > cap then n = cap end
        -- Use the detected base when there is one. Without it, walk 0..n-1:
        -- those indices are exact under a 0-based build and below the end under
        -- a 1-based one, so neither can reach the AddZeroed growth path. (1..n
        -- would append a zeroed element to a 0-based array — an out-of-bounds
        -- READ that edits the game's state.)
        local base = indexBase or 0
        for i = base, base + n - 1 do
            seen = seen + 1
            fn(arr[i])
        end
    end)
    return seen
end

-- Read one director's queue length + idle list into plain Lua. Game thread only.
local function sampleDirector(dir, into)
    if not alive(dir) then return end
    local full = nil
    pcall(function() full = dir:GetFullName() end)
    if type(full) == "string" and full:find("Default__", 1, true) then return end

    local camp = "?"
    pcall(function() camp = guidStr(dir.BaseCampId) or "?" end)
    local e = { total = false, waiting = false, readMs = 0, waitKeys = {}, waitNote = nil }

    -- The pulse-derived-vs-direct comparison number. Length only — there is
    -- nothing readable inside an element, so this IS the whole measurement, and
    -- it costs one FScriptArray::Num() read however deep the queue is.
    local t0 = os.clock()
    local arr = nil
    if pcall(function() arr = dir.RequiredAssignWorks end) and arr ~= nil then
        local n = arrayLen(arr)
        e.total = (n == nil) and false or n
    end
    e.readMs = (os.clock() - t0) * 1000

    local warr = nil
    if pcall(function() warr = dir.WaitingWorkerIndividualIds end) and warr ~= nil then
        local n = arrayLen(warr)
        e.waiting = (n == nil) and false or n
        -- A COUNT is not enough. The overseer has to answer "WHICH pal is idle",
        -- so the entries must yield the same palKey the engine keys everything on
        -- (guidStr(PlayerUId) .. "-" .. guidStr(InstanceId), shared.lua:78).
        if type(n) == "number" and n > 0 then
            if indexBase == nil then
                e.waitNote = "(elements not walked: index base undetermined — press F5)"
            else
                -- Re-read the length IMMEDIATELY before the loop: the bound has
                -- to come from the same instant as the reads, or an index can
                -- land past the end and grow the array.
                local n2 = arrayLen(warr) or 0
                local lim = (n2 < WAIT_WALK_CAP) and n2 or WAIT_WALK_CAP
                for i = 0, lim - 1 do
                    local idx = i + indexBase
                    local k = nil
                    pcall(function() k = palKeyOf(warr[idx]) end)
                    e.waitKeys[#e.waitKeys + 1] = k or ("UNREADABLE@" .. idx)
                end
                if n2 > lim then
                    e.waitNote = string.format("(showing %d of %d)", lim, n2)
                end
                e.waiting = n2
            end
        end
    end

    into[camp] = e
end

-- Directors are learned from hook A's Context, exactly as the engine does, so
-- the steady state costs no object-array walk. FindAllOf is ~29ms — running it
-- on a timer inside a probe built to measure game-thread starvation would be
-- measuring its own footprint.
local knownDirs = {}           -- campId -> director

local function sampleDirectors()
    local snap = {}
    local any = false
    for camp, dir in pairs(knownDirs) do
        if alive(dir) then
            any = true
            pcall(sampleDirector, dir, snap)
        else
            knownDirs[camp] = nil
        end
    end
    if not any then
        -- Cold start only: nothing has pulsed yet.
        local dirs = nil
        local ok, err = pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
        if not ok then
            dirSampleErr = tostring(err)
            return
        end
        if not dirs then return end
        for _, dir in ipairs(dirs) do
            pcall(sampleDirector, dir, snap)
        end
    end
    dirSnapshot = snap
end

local function onPulse(Context, Work)
    -- Counting is unconditional and costs nothing but integer ops.
    local nowSec = os.time()
    if nowSec ~= pulseSecond then
        if pulsesThisSecond > peakPulsesPerSecond then
            peakPulsesPerSecond = pulsesThisSecond
        end
        pulseSecond, pulsesThisSecond = nowSec, 0
        sampleBudgetLeft = SAMPLE_BUDGET
    end
    pulsesThisSecond = pulsesThisSecond + 1
    pulsesThisWindow = pulsesThisWindow + 1

    -- Distinct-job bookkeeping is the expensive half, so it is budgeted.
    if sampleBudgetLeft <= 0 then
        sampleCapped = true
        return
    end
    sampleBudgetLeft = sampleBudgetLeft - 1

    local w = nil
    pcall(function() w = Work:get() end)
    if not alive(w) then return end
    lastWork = w

    local id = nil
    pcall(function() id = guidStr(w:GetWorkId()) end)
    if not id then
        -- Worth knowing: the engine keys its whole demand index on this, and
        -- falls back to tostring(w) when it fails.
        id = "NOWORKID:" .. tostring(w)
    end
    if windowJobs[id] then return end

    local camp = "?"
    pcall(function()
        local dir = Context:get()
        if alive(dir) then
            camp = guidStr(dir.BaseCampId) or "?"
            -- Register the director so the direct-read sample never needs
            -- FindAllOf. Same trick the engine uses; free, we already have it.
            knownDirs[camp] = dir
        end
    end)
    local t = resolveType(w)
    windowJobs[id] = camp .. "|" .. tostring(t)

    -- One record per distinct job SIGNATURE for the F8 anatomy dump. Keyed on
    -- class+station+override rather than class alone because PalWorkProgress
    -- covers every station, so class alone would collapse them all into one.
    pcall(function()
        local cls = w:GetClass():GetFName():ToString()
        local assignId = fstr(w.AssignDefineDataId)
        local wt = w.OverrideWorkType
        local sig = tostring(cls) .. "|" .. tostring(assignId) .. "|" .. tostring(wt)
        if workSigs[sig] == nil then
            local req, auto = nil, nil
            pcall(function() req = w.RequiredWorkAmount end)
            pcall(function() auto = w.AutoWorkSelfAmountBySec end)
            workSigs[sig] = {
                cls = cls, assignId = assignId, wt = wt,
                req = req, auto = auto, t = t, n = 0,
            }
            workSigCount = workSigCount + 1
            if type(assignId) == "string" and #assignId > 0 then
                lastAssignId = assignId
            end
        end
        workSigs[sig].n = workSigs[sig].n + 1
    end)
end

-- ---------------------------------------------------------------------------
-- Periodic report. Pure Lua, no game objects, so it is safe off the game thread.
-- ---------------------------------------------------------------------------
local function report()
    reportN = reportN + 1
    local elapsed = os.time() - windowStart
    if elapsed < 1 then elapsed = 1 end

    -- Regroup the window's distinct jobs by camp and by type.
    local byCamp, total = {}, 0
    for _, ct in pairs(windowJobs) do
        local camp, t = ct:match("^(.-)|(.*)$")
        local c = byCamp[camp]
        if not c then c = {} byCamp[camp] = c end
        c[t] = (c[t] or 0) + 1
        total = total + 1
    end

    out("")
    out(string.format("--- report #%d  (%ds window) ---", reportN, elapsed))
    out(string.format("  hook A pulses      : %d in window  (%.1f/sec, PEAK %d/sec)",
        pulsesThisWindow, pulsesThisWindow / elapsed, peakPulsesPerSecond))
    out(string.format("  distinct jobs seen : %d%s", total,
        sampleCapped and "   <<< SAMPLE CAPPED, true queue is larger" or ""))
    if total == 0 then
        out("  (no pending work seen — if this is a client, that is expected:")
        out("   OnRequiredAssignWork is server-internal. Run on host/server.)")
    end
    for camp, types in pairs(byCamp) do
        local parts = {}
        for t, n in pairs(types) do
            local label = (t == "nil") and "UNRESOLVED" or
                (WORKNAME[tonumber(t) or -1] or ("type" .. t))
            parts[#parts + 1] = string.format("%s=%d", label, n)
        end
        table.sort(parts)
        out(string.format("  camp %s : %s", camp:sub(1, 8), table.concat(parts, "  ")))
    end
    -- What the engine would be paying at this queue depth, unguarded.
    out(string.format("  engine cost if unguarded: %d prune IsValid calls/tick "
        .. "+ %.0f hook bodies/sec", total, pulsesThisWindow / elapsed))

    -- THE COMPARISON. Left column is what the engine believes today (sampled
    -- pulses, decayed over 6s, capped at 32). Right column is what the director
    -- actually holds. If they diverge, the divergence IS the bug. There is no
    -- per-type breakdown on the right: the queue's element struct carries no
    -- reflected members, so a length is all it can ever say.
    if dirSnapshot ~= nil then
        if indexBase ~= nil and not indexBaseAnnounced then
            indexBaseAnnounced = true
            out("  TArray index base : " .. indexBaseVerdict)
        end
        out("  --- direct read from the director (redesign source) ---")
        if next(dirSnapshot) == nil then
            out("    (no director sampled yet)")
        end
        for camp, e in pairs(dirSnapshot) do
            out(string.format("    camp %s : RequiredAssignWorks = %s  (length only, %.3fms)",
                camp:sub(1, 8),
                (e.total == false) and "UNREADABLE" or tostring(e.total),
                e.readMs))
            out(string.format("    camp %s : WaitingWorkerIndividualIds = %s%s%s",
                camp:sub(1, 8),
                (e.waiting == false) and "UNREADABLE" or tostring(e.waiting),
                e.waitNote and ("  " .. e.waitNote) or "",
                (e.waitKeys and #e.waitKeys > 0)
                    and ("  idle: " .. table.concat(e.waitKeys, ", ")) or ""))
        end
    elseif dirSampleErr then
        out("  direct read: sampling errored — " .. dirSampleErr)
    else
        out("  direct read: not sampled yet (press F5 to probe the director)")
    end

    windowJobs = {}
    pulsesThisWindow = 0
    sampleCapped = false
    windowStart = os.time()
end

-- ---------------------------------------------------------------------------
-- Hook A. Registered through a named function so F7 can re-attach the SAME
-- behaviour, and both ids are kept because UnregisterHook needs them.
-- ---------------------------------------------------------------------------
local HOOK_A = "/Script/Pal.PalBaseCampWorkerDirector:OnRequiredAssignWork_ServerInternal"
local hookPre, hookPost = nil, nil
local hookAttached = false

local function hookBody(Context, Work, RequirementParameter)
    pcall(onPulse, Context, Work)
end

local function attachHookA()
    local ok, err = pcall(function()
        hookPre, hookPost = RegisterHook(HOOK_A, hookBody)
    end)
    hookAttached = ok
    if ok then
        out(string.format("HOOK OK OnRequiredAssignWork_ServerInternal (pre=%s post=%s)",
            tostring(hookPre), tostring(hookPost)))
    else
        out("HOOK FAILED OnRequiredAssignWork_ServerInternal: " .. tostring(err))
    end
    return ok
end

attachHookA()

-- ---------------------------------------------------------------------------
-- F6: capacity dump. Rank per type for every base pal, plus a guarded scalar
-- sweep for anything resembling an items-per-trip number.
-- ---------------------------------------------------------------------------
local CAPACITY_FIELD_GUESSES = {
    "TransportItemNum", "TransportNum", "CarryItemNum", "CarryNum",
    "MaxCarryNum", "MaxTransportNum", "TransportCapacity", "CarryCapacity",
    "MaxInventoryNum", "InventoryNum", "TransportItemSlotNum", "CapacityNum",
    "WorkSpeed", "CraftSpeed", "Rank", "Level",
}

local function dumpPal(id, param, n)
    local name = "?"
    pcall(function()
        local sp = param.SaveParameter
        name = fstr(sp.NickName)
        if not name or #name == 0 then name = fstr(sp.CharacterID) or "?" end
    end)

    local ranks = {}
    for t = 1, 13 do
        local has, r = nil, nil
        pcall(function() has = param:HasWorkSuitability(t) end)
        if has then
            pcall(function() r = param:GetWorkSuitabilityRankWithCharacterRank(t) end)
            ranks[#ranks + 1] = string.format("%s=%s",
                WORKNAME[t] or ("type" .. t), tostring(r))
        end
    end

    out("")
    out(string.format("  PAL #%d  %s", n, name))
    out("    ranks: " .. (#ranks > 0 and table.concat(ranks, "  ") or "(none readable)"))

    -- IDLE SIGNAL CALIBRATION. The idle-pal/overseer model needs to know, once
    -- per second, whether a pal has work. Candidates printed side by side so a
    -- pal that is VISIBLY standing still can be matched against what each one
    -- says. GetCurrentWorkSuitability is on UPalIndividualCharacterParameter —
    -- this object — and is what the engine already reads.
    --
    -- The other three are BlueprintCallable+BlueprintPure on
    -- UPalCharacterParameterComponent, an ActorComponent, NOT on the individual
    -- parameter this dump holds (header-verified 2026-07-26). If they come back
    -- "not callable here", that is the EXPECTED result and not a dead end — it
    -- means the real target is the character's parameter component, reached from
    -- the spawned character rather than from the container slot.
    out("    -- idle signals (compare against what the pal is VISIBLY doing) --")
    local cur = nil
    pcall(function() cur = param:GetCurrentWorkSuitability() end)
    out(string.format("      GetCurrentWorkSuitability = %s%s", tostring(cur),
        (type(cur) == "number" and WORKNAME[cur])
            and (" (" .. WORKNAME[cur] .. ")") or ""))
    for _, m in ipairs({ "IsAssignedToAnyWork", "GetWorkAssign", "GetWork" }) do
        local okc, v = pcall(function() return param[m](param) end)
        if okc then
            out(string.format("      %s() = %s", m, tostring(v)))
        else
            out(string.format("      %s() -> not callable here "
                .. "(EXPECTED: lives on UPalCharacterParameterComponent)", m))
        end
    end

    out("    -- named capacity guesses on the parameter --")
    local hits = 0
    for _, f in ipairs(CAPACITY_FIELD_GUESSES) do
        pcall(function()
            local v = param[f]
            if type(v) == "number" or type(v) == "boolean" then
                out(string.format("      %s = %s", f, tostring(v)))
                hits = hits + 1
            end
        end)
    end
    if hits == 0 then out("      (none readable on the parameter object)") end

    -- Only for the first pal: a full scalar sweep is long, and one is enough to
    -- learn the field set.
    if n == 1 then
        out("    -- full scalar property sweep (first pal only) --")
        pcall(function()
            local cls = param:GetClass()
            cls:ForEachProperty(function(prop)
                pcall(function()
                    local pname = prop:GetFName():ToString()
                    local ptype = prop:GetClass():GetFName():ToString()
                    if SCALAR_PROP_TYPES[ptype] then
                        out(string.format("      %s : %s = %s",
                            pname, ptype, tostring(param[pname])))
                    end
                end)
            end)
        end)
    end
end

local function capacityDump()
    out("")
    out("############################################################")
    out("# F6 CAPACITY DUMP")
    out("# Looking for: what makes one hauler worth more than another.")
    out("# Rank is what the engine already sorts candidates by; if items per")
    out("# trip is not derivable here it likely lives in a DataTable, which")
    out("# needs a follow-up probe (row iteration is unverified on this build).")
    out("############################################################")

    local dirs = nil
    pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
    if not dirs then
        out("  FindAllOf returned nothing — are you in a loaded base?")
        return
    end

    local n = 0
    for _, dir in ipairs(dirs) do
        pcall(function()
            if not alive(dir) then return end
            local full = nil
            pcall(function() full = dir:GetFullName() end)
            if type(full) == "string" and full:find("Default__", 1, true) then return end

            local camp = guidStr(dir.BaseCampId)
            out("")
            out("  CAMP " .. tostring(camp))

            local container = dir.CharacterContainer
            if not alive(container) then
                out("    (no CharacterContainer)")
                return
            end
            local slots = nil
            pcall(function() slots = container.SlotArray end)
            if slots == nil then
                out("    (no SlotArray)")
                return
            end
            -- SlotArray is the one array here that has earned ForEach: fixed
            -- size, owned by a container that is not churning under us, and the
            -- shipped mod has walked it this way for months.
            forEachArray(slots, PAL_WALK_CAP, function(slot)
                pcall(function()
                    if not alive(slot) then return end
                    local handle = slot.Handle
                    if not alive(handle) then return end
                    local pid = handle:GetIndividualID()
                    if pid == nil then return end
                    local param = handle:TryGetIndividualParameter()
                    if not alive(param) then return end
                    n = n + 1
                    dumpPal(pid, param, n)
                end)
            end)
        end)
    end
    out("")
    out(string.format("  %d pal(s) dumped", n))
end

pcall(function()
    RegisterKeyBind(Key.F6, function() pcall(capacityDump) end)
end)

-- ---------------------------------------------------------------------------
-- F5: STEP-3 ARCHITECTURE PROBE. THE GATING MEASUREMENT.
--
-- Four questions, in dependency order, because each gates the next:
--   1. INDEX BASE — nothing may index-walk until this is measured, because an
--      out-of-range read appends zeroed elements to the game's own array.
--   2. WaitingWorkerIndividualIds — does it yield palKeys? (the idle trigger)
--   3. OCCUPANCY CHAIN — work.AssignLocations + work.AssignRepInfoArray.Items ->
--      UPalWorkAssign. Fully reflected per headers, and the replacement for the
--      banned GetWorkAssignInfo. This is where real per-slot demand comes from.
--   4. TMap ACCESS — can Lua key or iterate WorkAssignDefineMap (the game's own
--      station -> suitability / WorkerMaxNum table) and WorkMap_InServer (every
--      live work)? UE4SS's map pusher exists and is defensive, but the Lua-side
--      TMap API surface is undocumented, so this is the biggest open unknown.
--
-- The director property sweep stays as the backstop: if a header name is wrong
-- for this build, the sweep prints the real one and the redesign retargets
-- instead of dying. Array VALUES stay unread during the sweep — names and types
-- only — and every targeted read is individually pcall'd, so if one of them is
-- the landmine we learn which. Type-support failures inside a pcall are
-- catchable Lua errors on this build; only genuine memory faults are not.
-- ---------------------------------------------------------------------------
local WORKER_STATE  = { [0] = "None", [1] = "Reserve", [2] = "Working", [3] = "Leave" }
local WORKING_STATE = { [0] = "Wait", [1] = "ApproachTo", [2] = "Working",
                        [3] = "WaitForWorkable" }

local function enumName(tbl, v)
    if type(v) == "number" and tbl[v] then return tbl[v] end
    return "?"
end

local function describeElement(v)
    if v == nil then return "nil" end
    if type(v) ~= "userdata" and type(v) ~= "table" then
        return type(v) .. " " .. tostring(v)
    end
    if not alive(v) then return "non-alive wrapper (empty slot or struct)" end
    local cls = nil
    pcall(function() cls = v:GetClass():GetFName():ToString() end)
    return "object of class " .. tostring(cls)
end

-- Index-base signature for FPalWorkAssignRepInfo: LocationIndex is an int32 that
-- differs per slot, which is exactly what the arr[0]/ForEach cross-check needs.
local function repItemSig(v)
    if v == nil then return nil end
    local li = nil
    pcall(function() li = v.LocationIndex end)
    if type(li) == "number" then return "loc" .. tostring(li) end
    return nil
end

-- TMap length by whatever the wrapper supports — all guesses, all pcall'd.
local function mapLength(map)
    local n = nil
    pcall(function() n = #map end)
    if type(n) == "number" then return n, "#map" end
    for _, m in ipairs({ "GetNumElements", "Num", "GetArrayNum", "Length", "Count" }) do
        local v = nil
        local ok = pcall(function() v = map[m](map) end)
        if ok and type(v) == "number" then return v, m .. "()" end
    end
    return nil, nil
end

-- TMap iteration, capped, with early termination (a callback returning true
-- breaks the loop — merged upstream Oct 2025 and present in this build).
local function mapIterate(map, cap, fn)
    local seen = 0
    local ok, err = pcall(function()
        map:ForEach(function(k, v)
            if seen >= cap then return true end
            seen = seen + 1
            local kk, vv = k, v
            local okk, gk = pcall(function() return k:get() end)
            if okk then kk = gk end
            local okv, gv = pcall(function() return v:get() end)
            if okv then vv = gv end
            pcall(fn, kk, vv)
            if seen >= cap then return true end
        end)
    end)
    return seen, (not ok) and tostring(err) or nil
end

-- FPalWorkAssignDefineData row — the game's own answer to "what suitability does
-- this station want, and how many workers fit".
local function describeDefineRow(v)
    if v == nil then return "nil" end
    local parts = {}
    for _, f in ipairs({ "WorkSuitability", "WorkType", "WorkerMaxNum",
                         "WorkSuitabilityRank" }) do
        local val = nil
        pcall(function() val = v[f] end)
        parts[#parts + 1] = string.format("%s=%s", f, tostring(val))
    end
    return table.concat(parts, " ")
end

-- The director's three arrays. Length for all of them; elements only for the
-- one array that HAS readable elements.
local function probeDirectorArrays(dir, caps)
    out("    -- targeted reads --")

    -- (1) RequiredAssignWorks — LENGTH ONLY, permanently.
    -- FPalBaseCampWorkAssignRequest has zero reflected members (SDK: 0x30 of
    -- padding; usmap: propCount=0), so GetArrayNum() already extracts 100% of
    -- what the array can tell anyone. Walking it would buy nothing and would
    -- spend the ForEach TODO crash on the one array in the game that is
    -- guaranteed to be both large and churning.
    local arr = nil
    local okr = pcall(function() arr = dir.RequiredAssignWorks end)
    if not okr then
        out("      RequiredAssignWorks : READ THREW")
        caps.queue = false
    elseif arr == nil then
        out("      RequiredAssignWorks : nil (absent on this build)")
        caps.queue = false
    else
        local t0 = os.clock()
        local len = arrayLen(arr)
        local ms = (os.clock() - t0) * 1000
        if len == nil then
            out("      RequiredAssignWorks : present but GetArrayNum unreadable")
            caps.queue = false
        else
            out(string.format("      RequiredAssignWorks : length %d   (%.3fms — one "
                .. "FScriptArray::Num() read, independent of depth)", len, ms))
            out("        elements deliberately NOT read: zero reflected members.")
            caps.queue = len
        end
    end

    -- (2) WaitingWorkerIndividualIds — the idle trigger. FPalInstanceID IS fully
    -- reflected, so entries should yield the engine's palKey. Bounded index
    -- loop, never ForEach; DebugName (FString) is never touched.
    local warr = nil
    local okw = pcall(function() warr = dir.WaitingWorkerIndividualIds end)
    if not okw then
        out("      WaitingWorkerIndividualIds : READ THREW")
        caps.waiting = false
    elseif warr == nil then
        out("      WaitingWorkerIndividualIds : nil (absent on this build)")
        caps.waiting = false
    else
        local len = arrayLen(warr)
        if len == nil then
            out("      WaitingWorkerIndividualIds : present but GetArrayNum unreadable")
            caps.waiting = false
        else
            out(string.format("      WaitingWorkerIndividualIds : length %d", len))
            caps.waiting = len
            if len > 0 then
                detectIndexBase(warr, palKeyOf, "WaitingWorkerIndividualIds")
                if indexBase == nil then
                    out("        (elements NOT walked: index base undetermined)")
                else
                    local n2 = arrayLen(warr) or 0   -- re-read, immediately before
                    local lim = (n2 < WAIT_WALK_CAP) and n2 or WAIT_WALK_CAP
                    local got = 0
                    for i = 0, lim - 1 do
                        local idx = i + indexBase
                        local k = nil
                        pcall(function() k = palKeyOf(warr[idx]) end)
                        if k then got = got + 1 end
                        out(string.format("        [%d] palKey %s", idx, k or "UNREADABLE"))
                    end
                    if n2 > lim then
                        out(string.format("        (... %d more, capped)", n2 - lim))
                    end
                    caps.waitKeys = (got > 0)
                end
            else
                out("        (empty right now — press F5 again while a pal is idle)")
            end
        end
    end

    -- (3) WorkerTasks — reported so nobody mistakes it for a work queue again.
    -- UPalBaseCampWorkerTaskBase is near-empty and its task enum is
    -- {Undefined, IgnitionTorchAtNight}: scheduled base chores, not worker state.
    local tarr = nil
    local okt = pcall(function() tarr = dir.WorkerTasks end)
    if not okt or tarr == nil then
        out(string.format("      WorkerTasks : %s   (scheduled base chores, NOT a work queue)",
            okt and "nil" or "READ THREW"))
    else
        out(string.format("      WorkerTasks : length %s   (scheduled base chores, NOT a work queue)",
            tostring(arrayLen(tarr))))
    end
end

-- UPalWorkProgressManager: the game's own work registry and station table. The
-- data is header-verified; what is unverified is whether Lua can get at a TMap
-- at all on this build, which is why both key lookup and iteration are tried.
local function probeWorkProgressManager()
    local v = { found = false, key = "not attempted", iter = "not attempted",
                workMap = "not attempted" }
    out("")
    out("  --- WORK PROGRESS MANAGER (define map + work registry) ---")
    out("  WorkAssignDefineMap is the game's OWN station table, keyed by")
    out("  AssignDefineDataId, carrying WorkSuitability / WorkType / WorkerMaxNum /")
    out("  WorkSuitabilityRank. If it reads, the hand-maintained WORKTYPE_TO_SUIT +")
    out("  STATION_SUIT maps become a fallback and OilExtraction stops being a hole.")
    out("  WorkMap_InServer is every live UPalWorkBase, keyed by work GUID.")

    local wpm = nil
    if not pcall(function() wpm = FindFirstOf("PalWorkProgressManager") end) then
        out("    FindFirstOf(\"PalWorkProgressManager\") : THREW")
        v.found = false
        return v
    end
    if not alive(wpm) then
        out("    PalWorkProgressManager : NOT FOUND (or not alive) — nothing else to test")
        return v
    end
    v.found = true
    out("    PalWorkProgressManager : FOUND, alive")

    -- WorkAssignDefineMap: (a) key lookup, (b) iteration.
    local dmap = nil
    if not (pcall(function() dmap = wpm.WorkAssignDefineMap end) and dmap ~= nil) then
        out("    WorkAssignDefineMap : UNREADABLE (property read threw or returned nil)")
        v.key, v.iter = "map unreadable", "map unreadable"
    else
        local n, how = mapLength(dmap)
        out(string.format("    WorkAssignDefineMap : readable (lua type %s), length %s%s",
            type(dmap), n and tostring(n) or "NOT OBTAINABLE",
            how and (" via " .. how) or ""))

        if lastAssignId == nil then
            out("      (a) key lookup SKIPPED — no AssignDefineDataId seen yet. Let hook A")
            out("          pulse for a few seconds, then press F5 again.")
            v.key = "skipped (no key seen yet)"
        else
            out(string.format("      (a) key lookup with a real id: %q", lastAssignId))
            local keys = { { "raw string", lastAssignId } }
            local fnm = nil
            if pcall(function() fnm = FName(lastAssignId) end) and fnm ~= nil then
                keys[#keys + 1] = { "FName", fnm }
            else
                out("          (FName() constructor unavailable — string key only)")
            end
            v.key = "all forms failed"
            for _, kk in ipairs(keys) do
                local got, threw = nil, false
                if not pcall(function() got = dmap[kk[2]] end) then threw = true end
                if threw then
                    out(string.format("          [%s] THREW", kk[1]))
                elseif got == nil then
                    out(string.format("          [%s] nil — wrong key type, or the "
                        .. "wrapper has no __index", kk[1]))
                else
                    out(string.format("          [%s] HIT -> %s", kk[1], describeDefineRow(got)))
                    v.key = "WORKS via " .. kk[1]
                end
            end
        end

        out("      (b) iteration (ForEach, capped at 3, early break):")
        local shown, ierr = mapIterate(dmap, 3, function(k, val)
            out(string.format("          key=%s  row=%s",
                tostring(fstr(k) or k), describeDefineRow(val)))
        end)
        if ierr then
            out("          THREW — " .. ierr)
            v.iter = "threw"
        elseif shown == 0 then
            out("          ForEach yielded nothing (no map ForEach on this wrapper)")
            v.iter = "yielded nothing"
        else
            out(string.format("          %d element(s) read", shown))
            v.iter = "WORKS"
        end
    end

    -- WorkMap_InServer.
    local wmap = nil
    if not (pcall(function() wmap = wpm.WorkMap_InServer end) and wmap ~= nil) then
        out("    WorkMap_InServer : UNREADABLE")
        v.workMap = "unreadable"
    else
        local n, how = mapLength(wmap)
        out(string.format("    WorkMap_InServer : readable (lua type %s), length %s%s",
            type(wmap), n and tostring(n) or "NOT OBTAINABLE",
            how and (" via " .. how) or ""))
        local shown, ierr = mapIterate(wmap, 2, function(k, val)
            out(string.format("        key=%s  value=%s",
                tostring(guidStr(k) or k), describeElement(val)))
        end)
        v.workMap = string.format("len %s, iteration %s",
            n and tostring(n) or "?",
            ierr and "threw" or (shown > 0 and "works" or "yielded nothing"))
        if ierr then out("        iteration THREW — " .. ierr) end
    end

    -- WorkTypeAssignPriorityMap: report only.
    local pmap = nil
    if pcall(function() pmap = wpm.WorkTypeAssignPriorityMap end) and pmap ~= nil then
        local n, how = mapLength(pmap)
        out(string.format("    WorkTypeAssignPriorityMap : readable, length %s%s",
            n and tostring(n) or "NOT OBTAINABLE", how and (" via " .. how) or ""))
    else
        out("    WorkTypeAssignPriorityMap : UNREADABLE")
    end

    return v
end

-- The chain that replaces GetWorkAssignInfo. Needs a live work object, which
-- hook A hands us for free.
local function probeOccupancyChain()
    out("")
    out("  --- OCCUPANCY CHAIN (replaces GetWorkAssignInfo) ---")
    out("  Per-slot occupancy is fully reflected on UPalWorkBase, so the banned")
    out("  out-param getter is not needed for it: AssignLocations gives the slots,")
    out("  AssignRepInfoArray.Items gives one FPalWorkAssignRepInfo per slot, each")
    out("  carrying a UPalWorkAssign with State / WorkingState /")
    out("  AssignedIndividualId / bFixed. If this reads, the redesign gets real")
    out("  'is this job actually being worked' data instead of a pulse guess.")

    local w = lastWork
    if not alive(w) then
        out("    no live work object retained yet — let hook A pulse, then press F5")
        out("    again (best while a pal is visibly working a station).")
        return "no work object"
    end
    out("    work object : " .. describeElement(w))

    -- F4: the work GUID is a private-but-reflected property named ID. There is
    -- NO property called WorkId — GetWorkId()/GetId() are BlueprintPure wrappers
    -- around it. If they agree, the engine can drop a native call per pulse.
    local idProp, idFn = nil, nil
    pcall(function() idProp = guidStr(w.ID) end)
    pcall(function() idFn = guidStr(w:GetWorkId()) end)
    out(string.format("    w.ID            = %s", tostring(idProp)))
    out(string.format("    w:GetWorkId()   = %s   -> %s", tostring(idFn),
        (idProp and idFn and idProp == idFn)
            and "AGREE (property read can replace the call)"
            or  "DISAGREE or unreadable — keep calling GetWorkId()"))

    local wt = nil
    local okwt = pcall(function() wt = w:GetWorkType() end)
    out(string.format("    w:GetWorkType() = %s", okwt and tostring(wt)
        or "NOT CALLABLE — surprising: a shipping mod (PalJobsPreferred) calls this "
           .. "from Lua on this build"))

    local al = nil
    if pcall(function() al = w.AssignLocations end) and al ~= nil then
        out(string.format("    AssignLocations : length %s   (slot count for this work)",
            tostring(arrayLen(al))))
    else
        out("    AssignLocations : UNREADABLE")
    end

    local rep = nil
    if not (pcall(function() rep = w.AssignRepInfoArray end) and rep ~= nil) then
        out("    AssignRepInfoArray : UNREADABLE  <- chain stops here")
        return "AssignRepInfoArray unreadable"
    end
    out("    AssignRepInfoArray : readable (FFastArraySerializer struct)")

    local items = nil
    if not (pcall(function() items = rep.Items end) and items ~= nil) then
        out("    AssignRepInfoArray.Items : UNREADABLE  <- chain stops here")
        return ".Items unreadable"
    end
    local n = arrayLen(items)
    out(string.format("    AssignRepInfoArray.Items : length %s", tostring(n)))
    if type(n) ~= "number" or n < 1 then
        out("      (nothing assigned to this work right now — press F5 again while a")
        out("       pal is actually working a station)")
        return "readable, empty"
    end

    detectIndexBase(items, repItemSig, "AssignRepInfoArray.Items")
    if indexBase == nil then
        out("      (elements NOT walked: index base undetermined)")
        return "readable, walk blocked on index base"
    end

    local n2 = arrayLen(items) or 0          -- re-read, immediately before the loop
    local lim = (n2 < OCC_WALK_CAP) and n2 or OCC_WALK_CAP
    local readOne = false
    for i = 0, lim - 1 do
        local idx = i + indexBase
        local it = nil
        if not pcall(function() it = items[idx] end) or it == nil then
            out(string.format("      [%d] element unreadable", idx))
        else
            local li, wa = nil, nil
            pcall(function() li = it.LocationIndex end)
            pcall(function() wa = it.WorkAssign end)
            if not alive(wa) then
                out(string.format("      [%d] LocationIndex=%s  WorkAssign=<empty / not alive>",
                    idx, tostring(li)))
            else
                local st, wst, fx, who = nil, nil, nil, nil
                pcall(function() st = wa.State end)
                pcall(function() wst = wa.WorkingState end)
                pcall(function() fx = wa.bFixed end)
                pcall(function() who = palKeyOf(wa.AssignedIndividualId) end)
                out(string.format("      [%d] loc=%s  State=%s(%s)  WorkingState=%s(%s)  "
                    .. "bFixed=%s  pal=%s",
                    idx, tostring(li),
                    tostring(st), enumName(WORKER_STATE, st),
                    tostring(wst), enumName(WORKING_STATE, wst),
                    tostring(fx), who or "UNREADABLE"))
                readOne = true
            end
        end
    end
    if n2 > lim then out(string.format("      (... %d more, capped)", n2 - lim)) end
    return readOne and "READS END TO END" or "Items read, WorkAssign did not"
end

local function directorAnatomy()
    out("")
    out("############################################################")
    out("# F5 STEP-3 ARCHITECTURE PROBE")
    out("# 1 index base   2 idle list   3 occupancy chain   4 TMap access")
    out("# Everything the 1.3 redesign reads instead of guessing is verified here.")
    out("############################################################")

    local dirs = nil
    pcall(function() dirs = FindAllOf("PalBaseCampWorkerDirector") end)
    if not dirs then
        out("  FindAllOf returned nothing — are you in a loaded base?")
        return
    end

    local swept = false
    local caps = {}
    local n = 0

    for _, dir in ipairs(dirs) do
        pcall(function()
            if not alive(dir) then return end
            local full = nil
            pcall(function() full = dir:GetFullName() end)
            if type(full) == "string" and full:find("Default__", 1, true) then return end
            n = n + 1

            local camp = guidStr(dir.BaseCampId)
            out("")
            out(string.format("  CAMP %s", tostring(camp)))

            -- The backstop: the full property list, once. Values only for scalars.
            if not swept then
                swept = true
                out("    -- every property on PalBaseCampWorkerDirector --")
                out("    (array/object/struct values are NEVER read here, only named)")
                pcall(function()
                    local cls = dir:GetClass()
                    cls:ForEachProperty(function(prop)
                        pcall(function()
                            local pname = prop:GetFName():ToString()
                            local ptype = prop:GetClass():GetFName():ToString()
                            if SCALAR_PROP_TYPES[ptype] then
                                out(string.format("      %s : %s = %s",
                                    pname, ptype, tostring(dir[pname])))
                            else
                                out(string.format("      %s : %s", pname, ptype))
                            end
                        end)
                    end)
                end)
            end

            probeDirectorArrays(dir, caps)
        end)
    end

    local mapv = probeWorkProgressManager()
    local occ = probeOccupancyChain()

    out("")
    out("  --- VERDICT ---")
    if n == 0 then
        out("  No live director found. Stand in a loaded base and press F5 again.")
        return
    end
    out("  index base                 : " .. indexBaseVerdict)
    out(string.format("  RequiredAssignWorks        : %s",
        (caps.queue ~= false and caps.queue ~= nil)
            and "length READABLE -> exact queue depth, no estimator needed (step 3)"
            or  "NOT USABLE -> fall back to hardening the estimator"))
    out(string.format("  WaitingWorkerIndividualIds : %s",
        (caps.waiting == false or caps.waiting == nil)
            and "NOT USABLE -> idle trigger degrades to a 1Hz poll"
            or ((caps.waitKeys == true)
                and "READABLE + yields palKeys -> idle is a fact (step 4)"
                or  "length readable; palKeys UNPROVEN (list was empty or unreadable)")))
    out("  occupancy chain            : " .. tostring(occ))
    out(string.format("  WorkProgressManager        : %s", mapv.found and "found" or "NOT FOUND"))
    out("    WorkAssignDefineMap key  : " .. tostring(mapv.key))
    out("    WorkAssignDefineMap iter : " .. tostring(mapv.iter))
    out("    WorkMap_InServer         : " .. tostring(mapv.workMap))
    out("  From here the periodic report prints the director's own queue length")
    out("  next to the pulse-derived count every window. Let it run — the")
    out("  divergence is the bug.")
end

pcall(function()
    RegisterKeyBind(Key.F5, function() pcall(directorAnatomy) end)
end)

-- ---------------------------------------------------------------------------
-- F8: work anatomy. One record per distinct job signature seen since load.
--
-- Answers three open questions in one dump:
--   * which stations are still invisible to WORKTYPE_TO_SUIT / STATION_SUIT
--     (resolved = nil), including the OilExtraction hole — suitability 9 has no
--     mapping at all today, so an oil priority is silently inert;
--   * which work is CONTINUOUS (RequiredWorkAmount = 0 with a non-zero
--     AutoWorkSelfAmountBySec never completes, so it must stay preemptible even
--     once finish-the-job becomes the default);
--   * what EPalWorkType 17 actually is — currently inferred as Collection(6),
--     and if it is really ground-pickup hauling then transport demand has been
--     credited to the wrong type all along.
-- ---------------------------------------------------------------------------
local function workAnatomy()
    out("")
    out("############################################################")
    out("# F8 WORK ANATOMY")
    out(string.format("# %d distinct job signature(s) seen since load", workSigCount))
    out("# Walk past oil rig / mill / cooler / medicine bench / lab / farm plot /")
    out("# ranch / furnace, then press F8 again — only work that has PULSED")
    out("# appears here.")
    out("############################################################")

    if workSigCount == 0 then
        out("  Nothing seen yet. Either no pending work, or this is a client")
        out("  (OnRequiredAssignWork is server-internal).")
        return
    end

    local rows = {}
    for _, r in pairs(workSigs) do rows[#rows + 1] = r end
    table.sort(rows, function(a, b)
        local at, bt = a.t or 99, b.t or 99
        if at ~= bt then return at < bt end
        return tostring(a.assignId) < tostring(b.assignId)
    end)

    local unresolved, continuous = 0, 0
    for _, r in ipairs(rows) do
        local label = r.t and (WORKNAME[r.t] or ("type" .. r.t)) or "*** UNRESOLVED ***"
        if not r.t then unresolved = unresolved + 1 end
        local cont = (r.req == 0) and (type(r.auto) == "number" and r.auto > 0)
        if cont then continuous = continuous + 1 end
        out("")
        out(string.format("  %s%s", label, cont and "   [CONTINUOUS - never completes]" or ""))
        out(string.format("    class            : %s", tostring(r.cls)))
        out(string.format("    AssignDefineDataId: %s", tostring(r.assignId)))
        out(string.format("    OverrideWorkType : %s", tostring(r.wt)))
        out(string.format("    RequiredWorkAmount / AutoWorkSelfAmountBySec : %s / %s",
            tostring(r.req), tostring(r.auto)))
        out(string.format("    pulses seen      : %d", r.n))
    end

    out("")
    out(string.format("  %d signature(s), %d UNRESOLVED (invisible to priorities), "
        .. "%d continuous", #rows, unresolved, continuous))
    if unresolved > 0 then
        out("  Each UNRESOLVED row needs an entry: OverrideWorkType -> WORKTYPE_TO_SUIT,")
        out("  or AssignDefineDataId (trailing _N stripped) -> STATION_SUIT.")
    end
end

pcall(function()
    RegisterKeyBind(Key.F8, function() pcall(workAnatomy) end)
end)

-- ---------------------------------------------------------------------------
-- F7: unhook test. The pulse counter is its own evidence — pulses/sec should
-- drop to zero while detached and recover after re-attaching.
-- ---------------------------------------------------------------------------
local detachAt = nil
local DETACH_SECONDS = 20

pcall(function()
    RegisterKeyBind(Key.F7, function()
        pcall(function()
            if detachAt then
                out("  F7: a detach test is already running — wait for it to finish.")
                return
            end
            if hookPre == nil or hookPost == nil then
                out("")
                out("  F7 UNHOOK TEST CANNOT RUN: RegisterHook did not return ids on")
                out("  this build. That alone is the answer — record it and stop.")
                return
            end
            out("")
            out("############################################################")
            out("# F7 UNHOOK TEST")
            out(string.format("# Detaching %s", HOOK_A))
            out(string.format("# ids pre=%s post=%s", tostring(hookPre), tostring(hookPost)))
            out("# Expect: next report shows ~0 pulses. Then it re-attaches and")
            out("# pulses should return. If they never return, the engine must")
            out("# NOT rely on detaching under load.")
            out("############################################################")
            local ok, err = pcall(function()
                UnregisterHook(HOOK_A, hookPre, hookPost)
            end)
            if ok then
                hookAttached = false
                detachAt = os.time()
                out("  UnregisterHook returned without error.")
            else
                out("  UnregisterHook FAILED: " .. tostring(err))
            end
        end)
    end)
end)

-- ---------------------------------------------------------------------------
-- The loop: periodic report, plus the F7 re-attach timer.
-- ---------------------------------------------------------------------------
local sampledThisWindow = false

pcall(function()
    LoopAsync(1000, function()
        pcall(function()
            local elapsed = os.time() - windowStart
            -- Sample the director one second ahead of the report so the
            -- game-thread hop has landed by the time we print. Once per window,
            -- not once per second: this probe exists to measure game-thread
            -- starvation and must not contribute to it.
            if elapsed >= (REPORT_SECONDS - 1) and not sampledThisWindow then
                sampledThisWindow = true
                ExecuteInGameThread(function() pcall(sampleDirectors) end)
            end
            if elapsed >= REPORT_SECONDS then
                sampledThisWindow = false
                report()
            end
            if detachAt and (os.time() - detachAt) >= DETACH_SECONDS then
                detachAt = nil
                out("")
                out("  F7: re-attaching hook A now.")
                if attachHookA() then
                    out("  Re-attach reported OK — watch the next report for pulses.")
                else
                    out("  RE-ATTACH FAILED. Restart the game before further testing,")
                    out("  and record this: detach-under-load is NOT safe on this build.")
                end
            end
        end)
        return false
    end)
end)

-- ---------------------------------------------------------------------------
-- F9: fixed-assign reachability. Reports only, never sends.
--
-- Per-job pinning is out of scope for the redesign — it would make the mod
-- responsible for each pal's work lifecycle forever, and a missed completion
-- signal strands the pal — so the only question worth asking is "would the RPC
-- be there if we ever wanted it". Naming a pal and a job to pin would alter the
-- player's save to answer a question nobody asked, so this key checks that the
-- two RPCs exist on the component and stops.
-- ---------------------------------------------------------------------------
pcall(function()
    RegisterKeyBind(Key.F9, function()
        pcall(function()
            out("")
            out("############################################################")
            out("# F9 FIXED-ASSIGN REACHABILITY  (reports only, never sends)")
            out("############################################################")
            local comp = nil
            pcall(function() comp = FindFirstOf("PalNetworkBaseCampComponent") end)
            if not alive(comp) then
                out("  No PalNetworkBaseCampComponent found — cannot test.")
                return
            end
            for _, m in ipairs({ "RequestFixedAssignWorkInBaseCamp_ToServer",
                                 "RequestUnassignWorkInBaseCamp_ToServer" }) do
                -- Indexing a UObject for a name it does not carry can throw on
                -- this build, so even the existence check is protected.
                local okm, v = pcall(function() return comp[m] end)
                out(string.format("  %s : %s", m,
                    (okm and v ~= nil) and "present on the component"
                    or (okm and "ABSENT" or "lookup threw")))
            end
        end)
    end)
end)

out("")
out("############################################################")
out(string.format("# TransportLoadProbe v%s session start", VERSION))
out(string.format("# reporting every %ds; sample budget %d/sec; walk caps: idle %d, "
    .. "occupancy %d, roster %d", REPORT_SECONDS, SAMPLE_BUDGET,
    WAIT_WALK_CAP, OCC_WALK_CAP, PAL_WALK_CAP))
out("############################################################")

log(string.format("v%s ready. Dump file: %s", VERSION, OUT_PATH))
log("Reports print automatically every 15s.")
log("  F5 = STEP-3 ARCHITECTURE PROBE  <- press first, then again after a minute")
log("  F8 = work/station anatomy (press again after visiting more stations)")
log("  F6 = capacity + idle signals   F7 = unhook test")
log("  F9 = fixed-assign reachability (reports only, never sends)")
log("Run on the machine that owns the pals (single-player / host / server).")
