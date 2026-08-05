-- Tests for planner.lua — the priority decision, as a pure function.
--
-- planner.lua deliberately touches no game objects and no globals, so it runs in
-- a bare interpreter. Needs Lua 5.3+ for the bitwise operators.
--
--   cd palworld-priority-mod
--   lua tests/planner_test.lua
--
-- Sections marked PENDING describe behaviour the redesign is going to add. They
-- report as pending rather than failing, so this file can be written before the
-- change and flipped on with it. See the plan's step 4/5.

package.path = "unified-mod/PalPriority/Scripts/?.lua;"
    .. "../unified-mod/PalPriority/Scripts/?.lua;" .. package.path

local P = require("planner")

-- ---------------------------------------------------------------------------
-- Tiny harness
-- ---------------------------------------------------------------------------
local pass, fail, pending = 0, 0, 0
local failures = {}

local function check(name, cond, detail)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = name .. (detail and ("\n      " .. detail) or "")
    end
end

local function todo(name)
    pending = pending + 1
    print(string.format("  PENDING  %s", name))
end

-- Work types used below, by their EPalWorkSuitability numbers.
local KINDLING, WATERING, HANDCRAFT = 1, 2, 5
local COLLECTION, MINING, TRANSPORT = 6, 8, 12

local ALL = 0
for t = P.WORK_MIN, P.WORK_MAX do ALL = ALL | P.bit(t) end

-- A pal that can do everything, with the given priorities.
local function pal(key, prio, opts)
    opts = opts or {}
    return {
        key = key,
        prio = prio,
        managed = opts.managed or ALL,
        current = opts.current,
        rank = opts.rank,
    }
end

local function maskOf(res, key) return res[key] and res[key].enabled or 0 end
local function claimOf(res, key) return res[key] and res[key].claim or nil end
local function barOf(res, key) return res[key] and res[key].bar or nil end

local function names(mask)
    local out = {}
    for t = P.WORK_MIN, P.WORK_MAX do
        if P.has(mask, t) then out[#out + 1] = t end
    end
    return "{" .. table.concat(out, ",") .. "}"
end

-- ---------------------------------------------------------------------------
-- Eligibility
-- ---------------------------------------------------------------------------
print("eligibility")

do
    -- Priority 0 means "never": not eligible, and never enabled.
    local res = P.plan({ pal("a", { [MINING] = 0, [HANDCRAFT] = 3 }) },
        { [MINING] = 5, [HANDCRAFT] = 5 })
    check("prio 0 is never claimed", claimOf(res, "a") == HANDCRAFT)
    check("prio 0 is never enabled", not P.has(maskOf(res, "a"), MINING),
        "mask was " .. names(maskOf(res, "a")))
end

do
    -- A type the pal has no suitability for is invisible even with a priority.
    local res = P.plan({ pal("a", { [MINING] = 1 }, { managed = P.bit(HANDCRAFT) }) },
        { [MINING] = 5 })
    check("unmanaged type is not claimed", claimOf(res, "a") == nil)
    check("unmanaged type is not enabled", maskOf(res, "a") == 0)
end

-- ---------------------------------------------------------------------------
-- Allocation
-- ---------------------------------------------------------------------------
print("allocation")

do
    -- Two jobs, three willing pals: exactly two get claimed.
    local pals = {
        pal("a", { [TRANSPORT] = 1 }), pal("b", { [TRANSPORT] = 1 }),
        pal("c", { [TRANSPORT] = 1 }),
    }
    local res = P.plan(pals, { [TRANSPORT] = 2 })
    local n = 0
    for _, k in ipairs({ "a", "b", "c" }) do
        if claimOf(res, k) == TRANSPORT then n = n + 1 end
    end
    check("demand 2 claims exactly 2 of 3 pals", n == 2, "claimed " .. n)
end

do
    -- Zero demand claims nobody, and an unclaimed pal is left UNFENCED so it can
    -- still pick something up rather than standing next to work it is barred from.
    local res = P.plan({ pal("a", { [TRANSPORT] = 1, [MINING] = 4 }) }, {})
    check("no demand -> no claim", claimOf(res, "a") == nil)
    check("no demand -> no bar", barOf(res, "a") == nil)
    check("unclaimed pal keeps every eligible type",
        P.has(maskOf(res, "a"), TRANSPORT) and P.has(maskOf(res, "a"), MINING))
end

do
    -- Higher work-suitability rank wins the slot.
    local pals = {
        pal("a", { [MINING] = 1 }, { rank = { [MINING] = 1 } }),
        pal("b", { [MINING] = 1 }, { rank = { [MINING] = 4 } }),
    }
    local res = P.plan(pals, { [MINING] = 1 })
    check("higher rank wins the only slot",
        claimOf(res, "b") == MINING and claimOf(res, "a") == nil)
end

do
    -- Equal rank falls back to the key, so a plan is deterministic across ticks
    -- and the reconciler's "did anything change" compare stays meaningful.
    local pals = { pal("zeta", { [MINING] = 1 }), pal("alpha", { [MINING] = 1 }) }
    local r1 = P.plan(pals, { [MINING] = 1 })
    local r2 = P.plan({ pals[2], pals[1] }, { [MINING] = 1 })
    check("equal rank breaks on key, stable under input order",
        claimOf(r1, "alpha") == MINING and claimOf(r2, "alpha") == MINING)
end

-- ---------------------------------------------------------------------------
-- Priority ordering — the property the whole mod exists for
-- ---------------------------------------------------------------------------
print("priority ordering")

do
    -- LEVEL-MAJOR. b is the only pal that can do the priority-1 kindling job.
    -- Walking pals one at a time down their own lists (the literal RimWorld
    -- shape) would let a claim b at priority 5 first and leave the campfire
    -- cold; level-major gives every pal its priority-1 chance first.
    local pals = {
        pal("a", { [TRANSPORT] = 5 }),
        pal("b", { [KINDLING] = 1, [TRANSPORT] = 5 }),
    }
    local res = P.plan(pals, { [KINDLING] = 1, [TRANSPORT] = 9 })
    check("level-major: the only kindling-capable pal takes the kindling job",
        claimOf(res, "b") == KINDLING,
        "b claimed " .. tostring(claimOf(res, "b")))
    check("level-major: the other pal still hauls", claimOf(res, "a") == TRANSPORT)
end

do
    -- Preemption falls out of the ascending walk: a pal on priority-4 work is
    -- reconsidered at priority 1 before its current type is ever visited.
    local res = P.plan({ pal("a", { [KINDLING] = 1, [TRANSPORT] = 4 },
        { current = TRANSPORT }) }, { [KINDLING] = 1, [TRANSPORT] = 9 })
    check("priority 1 preempts in-progress priority 4",
        claimOf(res, "a") == KINDLING)
    check("preempted type is dropped from the mask",
        not P.has(maskOf(res, "a"), TRANSPORT),
        "mask was " .. names(maskOf(res, "a")))
end

do
    -- The stability pass: a pal already doing a type keeps it, and does so
    -- without consuming one of that type's slots.
    local pals = {
        pal("a", { [MINING] = 3 }, { current = MINING }),
        pal("b", { [MINING] = 3 }),
    }
    local res = P.plan(pals, { [MINING] = 1 })
    check("pal already working a type keeps it", claimOf(res, "a") == MINING)
    check("and the free claim leaves the slot for someone else",
        claimOf(res, "b") == MINING)
end

do
    -- Types MORE important than the bar stay enabled, so a priority-1 job
    -- appearing can be taken without waiting for the next plan.
    local res = P.plan({ pal("a", { [KINDLING] = 1, [MINING] = 3, [TRANSPORT] = 5 }) },
        { [MINING] = 1 })
    local m = maskOf(res, "a")
    check("claimed at 3: more important type stays enabled", P.has(m, KINDLING))
    check("claimed at 3: the claimed type is enabled", P.has(m, MINING))
    check("claimed at 3: less important type is disabled", not P.has(m, TRANSPORT),
        "mask was " .. names(m))
end

-- ---------------------------------------------------------------------------
-- protectCurrent
-- ---------------------------------------------------------------------------
print("protectCurrent")

do
    local pals = { pal("a", { [KINDLING] = 1, [TRANSPORT] = 4 }, { current = TRANSPORT }) }
    local demand = { [KINDLING] = 1, [TRANSPORT] = 9 }
    local off = P.plan(pals, demand)
    local on = P.plan(pals, demand, { protectCurrent = true })
    check("protectCurrent off: the haul is cancelled",
        not P.has(maskOf(off, "a"), TRANSPORT))
    check("protectCurrent on: the haul survives the preemption",
        P.has(maskOf(on, "a"), TRANSPORT))
    check("protectCurrent on: the new work is still enabled",
        P.has(maskOf(on, "a"), KINDLING))
end

do
    -- CONTINUOUS work has no completion to finish. A lit campfire reports
    -- RequiredWorkAmount = 0 and burns AutoWorkSelfAmountBySec forever, so
    -- protecting a pal on one would pin it there for as long as the fire is lit —
    -- which is why finish-the-job could not ship until this exception existed.
    local pals = { pal("a", { [KINDLING] = 4, [MINING] = 1 }, { current = KINDLING }) }
    local demand = { [KINDLING] = 9, [MINING] = 1 }
    local plain = P.plan(pals, demand, { protectCurrent = true })
    local cont = P.plan(pals, demand,
        { protectCurrent = true, continuous = { [KINDLING] = true } })
    check("both plans preempt onto the priority-1 work",
        claimOf(plain, "a") == MINING and claimOf(cont, "a") == MINING)
    check("protectCurrent keeps a completable current type",
        P.has(maskOf(plain, "a"), KINDLING), "mask was " .. names(maskOf(plain, "a")))
    check("a CONTINUOUS current type stays preemptible",
        not P.has(maskOf(cont, "a"), KINDLING), "mask was " .. names(maskOf(cont, "a")))
end

do
    -- continuous only modulates protection of the pal's CURRENT type; a
    -- continuous type it is not standing on must change nothing.
    local pals = { pal("a", { [TRANSPORT] = 4, [MINING] = 1 }, { current = TRANSPORT }) }
    local res = P.plan(pals, { [TRANSPORT] = 9, [MINING] = 1 },
        { protectCurrent = true, continuous = { [KINDLING] = true } })
    check("a continuous type that is not the current one is inert",
        P.has(maskOf(res, "a"), TRANSPORT), "mask was " .. names(maskOf(res, "a")))
end

-- ---------------------------------------------------------------------------
-- demandMask (change detection)
-- ---------------------------------------------------------------------------
print("demandMask")

do
    check("demandMask is presence-only today",
        P.demandMask({ [MINING] = 1 }) == P.demandMask({ [MINING] = 9 }))
    check("demandMask distinguishes which types are present",
        P.demandMask({ [MINING] = 1 }) ~= P.demandMask({ [TRANSPORT] = 1 }))
    check("zero and absent are the same", P.demandMask({ [MINING] = 0 }) == 0)
end

-- ---------------------------------------------------------------------------
-- Redesign targets — see the plan, steps 4 and 5
-- ---------------------------------------------------------------------------
print("redesign (not yet implemented)")

todo("fence to the CLAIM, not the level: a pal allocated Mining-at-3 should not "
    .. "keep Handcraft-at-3 enabled")
todo("free claims consume a slot: N jobs + N pals already on them should claim N "
    .. "pals total, not 2N")
todo("idle ask: re-planning with a pal marked idle gives it the most important "
    .. "unmet work it is eligible for")
todo("unproductive pair: a pal marked unproductive for type T is not allocated to "
    .. "T while the cooldown holds")
todo("count-sensitive change detection: 1 -> 2 jobs on a priority-1 type changes "
    .. "the signature")

-- ---------------------------------------------------------------------------
print("")
if fail > 0 then
    print(string.format("FAILED  %d passed, %d failed, %d pending", pass, fail, pending))
    for _, f in ipairs(failures) do print("  FAIL  " .. f) end
    os.exit(1)
end
print(string.format("ok      %d passed, %d pending", pass, pending))
