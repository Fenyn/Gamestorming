-- PalPriority planner — the priority decision as a pure function.
-- No game objects, no I/O, no globals. Testable without the game
-- (../../../tests/planner_test.lua).
--
-- Per camp: walk priority levels 1..5 and hand out the pending jobs of each
-- type to the pals that rank it there. A pal that gets a job is fenced to its
-- level; a pal that gets none is left unfenced rather than idling next to work
-- it is barred from. Pals already working a type keep it; a more important type
-- with pending work still preempts.
--
-- Sets are 13-bit masks so "did anything change" is an integer compare, which
-- is what lets the reconciler skip a camp. Needs Lua 5.3+ (UE4SS is 5.4).

local P = {}

P.WORK_MIN, P.WORK_MAX = 1, 13
P.PRIO_MIN, P.PRIO_MAX = 1, 5   -- 0 = never, so simply not eligible

function P.bit(t)
    return 1 << (t - 1)
end

function P.has(mask, t)
    return (mask & (1 << (t - 1))) ~= 0
end

function P.maskFromSet(set)
    local m = 0
    for t, on in pairs(set or {}) do
        if on and type(t) == "number" and t >= P.WORK_MIN and t <= P.WORK_MAX then
            m = m | P.bit(t)
        end
    end
    return m
end

function P.listFromMask(mask)
    local out = {}
    for t = P.WORK_MIN, P.WORK_MAX do
        if P.has(mask, t) then out[#out + 1] = t end
    end
    return out
end

-- Change-detection signature: which types have pending work at all. Counts are
-- deliberately excluded — a queue going 4 -> 3 changes no pal's allowed set.
function P.demandMask(demand)
    local m = 0
    for t = P.WORK_MIN, P.WORK_MAX do
        local c = demand and demand[t] or 0
        if type(c) == "number" and c > 0 then m = m | P.bit(t) end
    end
    return m
end

-- pals: array of { key, prio = {[t]=0..5}, managed = mask, current = t|nil,
--                  rank = {[t]=number}|nil }
-- demand: { [t] = count } — UNFILLED jobs in this camp. A pal's in-progress job
--   is not in here, which is why the stability pass claims without a slot.
-- opts.allocate       (default true)  false = pre-1.2 per-pal bar, for comparison
-- opts.protectCurrent (default false) keep the current type enabled when preempted
-- returns { [key] = { enabled = mask, bar = p|nil, claim = t|nil } }
function P.plan(pals, demand, opts)
    opts = opts or {}
    local allocate = opts.allocate ~= false
    local protectCurrent = opts.protectCurrent == true

    local elig = {}   -- elig[i][t] = priority
    for i = 1, #pals do
        local prio = pals[i].prio or {}
        local managed = pals[i].managed or 0
        local e = {}
        for t = P.WORK_MIN, P.WORK_MAX do
            if P.has(managed, t) then
                local p = prio[t]
                if type(p) == "number" and p >= P.PRIO_MIN then
                    e[t] = (p > P.PRIO_MAX) and P.PRIO_MAX or p
                end
            end
        end
        elig[i] = e
    end

    local claim, bar = {}, {}

    if allocate then
        local remaining = {}
        for t = P.WORK_MIN, P.WORK_MAX do
            local c = demand and demand[t] or 0
            remaining[t] = (type(c) == "number" and c > 0) and c or 0
        end

        -- Ascending levels: reaching a lower level means everything above was
        -- unwanted or full. Preemption falls out of that ordering.
        for p = P.PRIO_MIN, P.PRIO_MAX do
            for t = P.WORK_MIN, P.WORK_MAX do
                local cands = nil
                for i = 1, #pals do
                    if claim[i] == nil and elig[i][t] == p then
                        if pals[i].current == t then
                            claim[i] = t   -- already working it; costs no slot
                        else
                            cands = cands or {}
                            cands[#cands + 1] = i
                        end
                    end
                end

                if cands and remaining[t] > 0 then
                    table.sort(cands, function(a, b)
                        local ra = (pals[a].rank and pals[a].rank[t]) or 0
                        local rb = (pals[b].rank and pals[b].rank[t]) or 0
                        if ra ~= rb then return ra > rb end
                        return tostring(pals[a].key) < tostring(pals[b].key)
                    end)
                    local n = remaining[t]
                    if n > #cands then n = #cands end
                    for k = 1, n do
                        claim[cands[k]] = t
                        remaining[t] = remaining[t] - 1
                    end
                end
            end
        end

        for i = 1, #pals do
            if claim[i] then bar[i] = elig[i][claim[i]] end
        end
    else
        for i = 1, #pals do
            local e, b = elig[i], nil
            for t, p in pairs(e) do
                local c = demand and demand[t] or 0
                if type(c) == "number" and c > 0 and (not b or p < b) then b = p end
            end
            local cur = pals[i].current
            if cur and e[cur] and (not b or e[cur] < b) then b = e[cur] end
            bar[i] = b
        end
    end

    local out = {}
    for i = 1, #pals do
        local e, b = elig[i], bar[i]
        local mask = 0
        for t, p in pairs(e) do
            -- Types above the bar stay enabled: nothing pending on them, and it
            -- lets the pal take new high-priority work without waiting a tick.
            if b == nil or p <= b then mask = mask | P.bit(t) end
        end
        if protectCurrent then
            local cur = pals[i].current
            if cur and e[cur] then mask = mask | P.bit(cur) end
        end
        out[pals[i].key] = { enabled = mask, bar = b, claim = claim[i] }
    end
    return out
end

return P
