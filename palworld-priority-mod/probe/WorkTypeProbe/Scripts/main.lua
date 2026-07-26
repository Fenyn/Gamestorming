-- ============================================================================
-- WorkTypeProbe — read-only discovery mod for PalPriority.
-- UE4SS (Okaetsu fork) Lua mod. Palworld 1.0. DEV ONLY — never shipped.
--
-- WHY
--   The engine's pending-work tracker can only see a job whose required
--   EPalWorkSuitability it can resolve. Today that is a 3-entry class-name map
--   plus OverrideWorkType -> WORKTYPE_TO_SUIT, and OverrideWorkType reads as
--   None/0 on most STATION jobs (furnaces, benches, mills, ranches, farm plots).
--   Those jobs are therefore invisible: the priority bar never rises for them,
--   so pals never get fenced toward them. This probe finds the field that
--   actually carries a station job's suitability.
--
-- WHAT IT CAPTURES
--   1. The EPalWorkType and EPalWorkSuitability enums straight from reflection
--      (if the build exposes them) — this alone can replace the hand-guessed
--      WORKTYPE_TO_SUIT map with the real declaration order.
--   2. One full dump per distinct job SIGNATURE (class + AssignDefineDataId +
--      OverrideWorkType). Keying on the signature, not just the class name,
--      matters: PalWorkProgress covers furnace/bench/mill/ranch alike, and
--      class-only dedupe would show exactly one of them.
--   3. The owning director's BaseCampId, which the rebuild needs to scope
--      pending work per base camp.
--
-- SAFETY (these rules are why the mod does not crash — see ../../docs/callpath-map.md)
--   - alive() (strict IsValid) before EVERY member call on EVERY received object.
--   - Property VALUES are read only for the scalar types in SCALAR_PROP_TYPES.
--     Object / Struct / Array / SoftObject values are logged by name+type only:
--     reading a SoftObjectProperty is a native access violation that pcall
--     CANNOT catch.
--   - GetWorkAssignInfo is never called (removed crash suspect).
--   - Everything is pcall-wrapped; a failed read is skipped, never retried.
--
-- HOW TO RUN
--   1. Copy this WorkTypeProbe folder into  ...\Win64\ue4ss\Mods\
--      (alongside PalPriority). It ships an enabled.txt, so no mods.txt edit.
--   2. Load a single-player save and go to a base. Leave the game running for
--      a couple of minutes with work happening:
--        - light a FURNACE / campfire        (Kindling)
--        - queue something at a WORKBENCH    (Handcraft)
--        - have a pal in a RANCH             (MonsterFarm)
--        - a watered/seeded FARM PLOT        (Watering / Seeding)
--        - a MILL, a cooler, a medicine bench if you have them
--      Press F7 whenever you start a new station, to drop a marker in the log
--      (the signatures that appear after marker N are that station's).
--   3. Press F8 for a summary of everything seen so far.
--   4. Send me  ue4ss\Mods\WorkTypeProbe\worktype-dump.txt
--
--   The dump file is what matters — the console shows the same lines but
--   scrolls. New signatures stop appearing once every station type has been
--   seen once; that is when you are done.
-- ============================================================================

local VERSION = "1.0"

local function log(msg)
    print(string.format("[WorkTypeProbe] %s\n", msg))
end

log(string.format("v%s loading...", VERSION))

-- ---------------------------------------------------------------------------
-- Safety helpers (same contracts as the engine — see the header).
-- ---------------------------------------------------------------------------

-- UE4SS returns a WRAPPER object, not nil, for null UObject properties, and
-- pcall cannot catch the native AV from calling a method on a null/stale one.
-- IsValid() itself is safe on those wrappers, so it is the only trustworthy gate.
local function alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

-- FString/FName values arrive as a plain string or as userdata with :ToString().
local function fstr(x)
    if x == nil then return nil end
    if type(x) == "string" then return x end
    local ok, s = pcall(function() return x:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

local function norm(v)
    return v % 0x100000000
end

-- Property TYPES whose value is safe to marshal into Lua. Anything else is
-- logged by name+type only.
local SCALAR_PROP_TYPES = {
    ByteProperty = true, EnumProperty = true, IntProperty = true,
    Int64Property = true, BoolProperty = true, FloatProperty = true,
    DoubleProperty = true, NameProperty = true, StrProperty = true,
}

-- Field names that plausibly carry an EPalWorkSuitability. Reads are guarded;
-- a miss is silent. Cast wide — a hit here is the answer we are looking for.
local SUIT_FIELD_GUESSES = {
    "WorkSuitability", "RequiredWorkSuitability", "TargetWorkSuitability",
    "RequireWorkSuitability", "NeedWorkSuitability", "WorkSuitabilityType",
    "AssignableWorkSuitability", "WorkableSuitability", "Suitability",
    "WorkHardType", "WorkType", "OverrideWorkType", "WorkSuitabilityRank",
    "RequiredRank", "RequiredWorkAmount", "WorkAmount", "Rank",
}

-- ---------------------------------------------------------------------------
-- Output: console + append-only file, so the handoff is one file rather than a
-- scraped console. Written only on NEW signatures (a few dozen per session),
-- and closed every time so a crash never loses what was already found.
-- ---------------------------------------------------------------------------
local OUT_PATH = "Mods/WorkTypeProbe/worktype-dump.txt"

-- Derive this mod's absolute directory from package.path (UE4SS seeds it with
-- each mod's Scripts dir), so the file lands next to the mod whatever the cwd.
pcall(function()
    for entry in string.gmatch(package.path or "", "[^;]+") do
        local base = entry:match("^(.*[/\\]Mods[/\\]WorkTypeProbe)[/\\]Scripts[/\\]%?%.lua$")
        if base then
            OUT_PATH = base .. "/worktype-dump.txt"
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
-- Enum dump. If this build exposes UEnum reflection, these two tables settle
-- the EPalWorkType -> EPalWorkSuitability mapping outright, with no
-- station-by-station correlation needed. Both access paths are attempted;
-- failure is harmless and expected on some builds.
-- ---------------------------------------------------------------------------
local function dumpEnum(path)
    out("--- ENUM " .. path .. " ---")
    local e = nil
    pcall(function() e = StaticFindObject(path) end)
    if not alive(e) then
        out("  (not found / not reflectable on this build)")
        return
    end

    local got = 0
    -- Preferred: iterate every declared name.
    pcall(function()
        e:ForEachName(function(name, value)
            pcall(function()
                local n = fstr(name) or tostring(name)
                out(string.format("  %s = %s", n, tostring(value)))
                got = got + 1
            end)
        end)
    end)

    -- Fallback: probe values by index. Bounded well above any plausible size.
    if got == 0 then
        for i = 0, 100 do
            pcall(function()
                local n = e:GetNameByValue(i)
                local s = fstr(n)
                if s and #s > 0 and s ~= "None" then
                    out(string.format("  %d = %s", i, s))
                    got = got + 1
                end
            end)
        end
    end

    if got == 0 then out("  (no names readable)") end
end

-- ---------------------------------------------------------------------------
-- Per-signature job dump.
-- ---------------------------------------------------------------------------
local seen = {}        -- signature -> true
local seenCount = 0
local markerN = 0
local sigList = {}     -- ordered, for the F8 summary

local function guidStr(g)
    local s = nil
    pcall(function()
        s = string.format("%08X%08X%08X%08X", norm(g.A), norm(g.B), norm(g.C), norm(g.D))
    end)
    return s
end

-- The director that raised this job. Also the camp-scoping check the rebuild
-- depends on: if BaseCampId reads here, pending work can be keyed per camp.
local function dumpDirector(ctx)
    local dir = nil
    pcall(function() dir = ctx:get() end)
    if not alive(dir) then
        out("  DIRECTOR: (not readable)")
        return
    end
    local full = nil
    pcall(function() full = dir:GetFullName() end)
    out("  DIRECTOR: " .. tostring(full))
    local camp = nil
    pcall(function() camp = guidStr(dir.BaseCampId) end)
    out("  DIRECTOR.BaseCampId: " .. tostring(camp) ..
        (camp and "" or "   <<< camp id NOT readable — tell me, it changes the design"))
end

local function dumpWork(w, reqParam, ctx, className, assignId, overrideType)
    out("")
    out("============================================================")
    out(string.format("SIGNATURE #%d  (after marker %d)", seenCount, markerN))
    out("  class            : " .. tostring(className))
    out("  AssignDefineDataId: " .. tostring(assignId))
    out("  OverrideWorkType : " .. tostring(overrideType))
    out("============================================================")

    dumpDirector(ctx)

    pcall(function()
        local camp = guidStr(w.BaseCampIdBelongTo)
        out("  WORK.BaseCampIdBelongTo: " .. tostring(camp))
    end)

    -- (1) Full reflection dump of the work object's own properties. The field
    -- we are hunting shows up here by name, with its value, ready to read
    -- directly in getWorkType.
    out("  -- properties --")
    pcall(function()
        local cls = w:GetClass()
        cls:ForEachProperty(function(prop)
            pcall(function()
                local pname = prop:GetFName():ToString()
                local ptype = prop:GetClass():GetFName():ToString()
                if SCALAR_PROP_TYPES[ptype] then
                    local v = w[pname]
                    out(string.format("    %s : %s = %s", pname, ptype, tostring(v)))
                else
                    out(string.format("    %s : %s (value skipped — unsafe)", pname, ptype))
                end
            end)
        end)
    end)

    -- (2) Named-field pokes on the work object, in case ForEachProperty did not
    -- surface something readable.
    out("  -- named guesses on the work object --")
    for _, fname in ipairs(SUIT_FIELD_GUESSES) do
        pcall(function()
            local v = w[fname]
            if type(v) == "number" or type(v) == "boolean" then
                out(string.format("    %s = %s", fname, tostring(v)))
            else
                local s = fstr(v)
                if s and #s > 0 then out(string.format("    %s = %s", fname, s)) end
            end
        end)
    end

    -- (3) The same pokes on the hook's FPalWorkAssignRequirementParameter.
    -- Structs do not enumerate like UObjects, so named guesses are the only way in.
    if reqParam ~= nil then
        out("  -- named guesses on RequirementParameter --")
        local rp = reqParam
        pcall(function() rp = reqParam:get() end)
        for _, fname in ipairs(SUIT_FIELD_GUESSES) do
            pcall(function()
                local v = rp[fname]
                if type(v) == "number" or type(v) == "boolean" then
                    out(string.format("    %s = %s", fname, tostring(v)))
                else
                    local s = fstr(v)
                    if s and #s > 0 then out(string.format("    %s = %s", fname, s)) end
                end
            end)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Hook: the job-needs-worker intake. Same event the engine's pending tracker
-- feeds from, so whatever this probe can see there, the engine can too.
-- Read-only: the probe never writes game state.
-- ---------------------------------------------------------------------------
local okA, errA = pcall(function()
    RegisterHook("/Script/Pal.PalBaseCampWorkerDirector:OnRequiredAssignWork_ServerInternal",
        function(Context, Work, RequirementParameter)
            pcall(function()
                local w = nil
                pcall(function() w = Work:get() end)
                if not alive(w) then return end

                local className = nil
                pcall(function() className = w:GetClass():GetFullName() end)
                if not className then return end

                local assignId = "?"
                pcall(function() assignId = fstr(w.AssignDefineDataId) or "?" end)
                local overrideType = "?"
                pcall(function() overrideType = tostring(w.OverrideWorkType) end)

                -- Signature, not class name: PalWorkProgress covers every
                -- station, and class-only dedupe would capture just one.
                local sig = className .. "|" .. assignId .. "|" .. overrideType
                if seen[sig] then return end
                seen[sig] = true
                seenCount = seenCount + 1
                sigList[#sigList + 1] = string.format(
                    "#%d  %s  assignId=%s  overrideWorkType=%s",
                    seenCount, className, assignId, overrideType)

                dumpWork(w, RequirementParameter, Context, className, assignId, overrideType)
                log(string.format("captured signature #%d (%s / %s) — F8 for summary",
                    seenCount, assignId, overrideType))
            end)
        end)
end)
log(okA and "HOOK OK OnRequiredAssignWork_ServerInternal"
    or ("HOOK FAILED OnRequiredAssignWork_ServerInternal: " .. tostring(errA)))

-- ---------------------------------------------------------------------------
-- F7: drop a labelled marker. Press it right before you start a station, so the
-- signatures that follow can be attributed to it.
-- ---------------------------------------------------------------------------
pcall(function()
    RegisterKeyBind(Key.F7, function()
        pcall(function()
            markerN = markerN + 1
            out("")
            out(string.format(">>> MARKER %d <<<   (next signatures belong to whatever you just started)", markerN))
            log(string.format("marker %d dropped", markerN))
        end)
    end)
end)

-- ---------------------------------------------------------------------------
-- F8: summary of every signature captured so far.
-- ---------------------------------------------------------------------------
pcall(function()
    RegisterKeyBind(Key.F8, function()
        pcall(function()
            log("=== SUMMARY: " .. seenCount .. " distinct job signature(s) ===")
            for _, s in ipairs(sigList) do log("  " .. s) end
            log("=== dump file: " .. OUT_PATH .. (outFailed and "  (FILE WRITE FAILED — console only)" or "") .. " ===")
        end)
    end)
end)

-- ---------------------------------------------------------------------------
-- Startup: enum dump (needs no game world, but the enums may only resolve once
-- Pal content is loaded — so it is retried once from the first captured job).
-- ---------------------------------------------------------------------------
out("")
out("############################################################")
out(string.format("# WorkTypeProbe v%s session start", VERSION))
out("############################################################")
dumpEnum("/Script/Pal.EPalWorkType")
dumpEnum("/Script/Pal.EPalWorkSuitability")

log(string.format("v%s ready. Dump file: %s", VERSION, OUT_PATH))
log("F7 = drop a marker before starting a station.  F8 = summary.")
