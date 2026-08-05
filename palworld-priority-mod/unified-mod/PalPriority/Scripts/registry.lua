-- Who is playing, and which network component is theirs.
--
-- Four call sites used to answer that by walking the ENTIRE UObject array
-- (FindAllOf, ~29ms measured live): the role gate in main.lua, both owner
-- lookups in engine.lua, and the interface's own-component resolve. Each kept
-- its own cache, and each cached only SUCCESS — a miss re-scanned on the very
-- next call. So an offline owner, or a dedicated server with no local player to
-- find, paid a full walk on a timer forever. That is the hitch the mod got
-- uninstalled over.
--
-- One dictionary answers all four now:
--   * a scan runs only when a caller MISSES, never on a schedule;
--   * at most one scan per SCAN_MIN_GAP, so N callers missing in the same tick
--     cost one walk between them, not N;
--   * each distinct question backs off on its own while it keeps coming up
--     empty, to a 120s ceiling (30s for the local-player question, where the
--     sawControllers test does the real work) — see BACKOFF_MAX below;
--   * anything that proves the world changed (a hook delivering a component we
--     have never indexed, a session change) re-arms instantly.
--
-- CRASH RULES apply here as everywhere: alive() before EVERY member call on
-- EVERY received object.

local S = require("shared")
local alive, guidStr = S.alive, S.guidStr

local R = {}

local players = {}        -- uidHex -> { ctrl, comp }
local compOwner = {}      -- component full name -> uidHex
local localHex = nil      -- uid of the local controller; nil on a dedicated server
local sawControllers = false  -- last walk found at least one PalPlayerController
local misses = {}         -- question tag -> { at, gap }
local lastScanAt = -math.huge
local worldCtx = nil      -- WorldContextObject for the dedicated-server probe
local dedicated = nil     -- true/false once known; nil = not answerable

local SCAN_MIN_GAP = 2    -- floor between any two walks, whoever asks
local BACKOFF_MIN = 5
-- Must sit WELL above every caller's own polling interval or it buys nothing:
-- the adopt sweep runs every 30s, so a 30s ceiling walked on every sweep anyway.
-- Safe to make this long because a player who reconnects re-arms their question
-- through R.note() the moment they send anything, and any walk that sees the
-- player set change clears every backoff.
local BACKOFF_MAX = 120
local LOCAL_BACKOFF_MAX = 30   -- the sawControllers test does the real work here

local function due(tag, now)
    local m = misses[tag]
    return m == nil or (now - m.at) >= m.gap
end

local function missed(tag, now)
    local m = misses[tag]
    misses[tag] = { at = now, gap = m and math.min(BACKOFF_MAX, m.gap * 2) or BACKOFF_MIN }
end

-- The one walk. Rebuilds both dictionaries from scratch so dead controllers and
-- recycled component names cannot accumulate over a long server uptime.
-- Returns false when the floor gap declined it — callers must then NOT record a
-- miss, or a declined scan would inflate their backoff for free.
local function scan(now)
    if (now - lastScanAt) < SCAN_MIN_GAP then return false end
    lastScanAt = now
    local np, nc, nlocal = {}, {}, nil
    pcall(function()
        local ctrls = FindAllOf("PalPlayerController")
        if not ctrls then return end
        for _, ctrl in ipairs(ctrls) do
            pcall(function()
                if not alive(ctrl) then return end
                if S.isDefaultObject(S.fullNameOf(ctrl)) then return end
                local uid = ctrl:GetPlayerUId()
                if uid == nil then return end
                local hex = guidStr(uid)
                local comp = nil
                local tx = ctrl.Transmitter
                if alive(tx) then
                    local bc = tx.BaseCamp
                    if alive(bc) then comp = bc end
                end
                np[hex] = { ctrl = ctrl, comp = comp }
                if comp ~= nil then
                    local n = S.fullNameOf(comp)
                    if n then nc[n] = hex end
                end
                local isLocal = false
                pcall(function() isLocal = ctrl:IsLocalController() end)
                if isLocal == true then nlocal = hex end
            end)
        end
    end)
    -- The player set changing is the only thing that can turn a previously
    -- unanswerable question answerable, and this walk is where we find out.
    local changed = false
    for hex in pairs(np) do
        if players[hex] == nil then changed = true break end
    end
    if not changed then
        for hex in pairs(players) do
            if np[hex] == nil then changed = true break end
        end
    end
    players, compOwner, localHex = np, nc, nlocal
    sawControllers = next(np) ~= nil
    if changed then misses = {} end
    return true
end

-- A dedicated server has no local controller, ever, so the role gate must stop
-- looking for one instead of backing off to a 30s heartbeat. Same static-library
-- call shape the interface already uses for KismetTextLibrary. Unanswerable
-- (library missing, call not marshalable) stays nil and the backoff covers us.
function R.isDedicatedServer()
    if dedicated ~= nil then return dedicated end
    if not alive(worldCtx) then return false end
    local v = nil
    pcall(function()
        local lib = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        if not alive(lib) then return end
        v = lib:IsDedicatedServer(worldCtx)
    end)
    if type(v) == "boolean" then dedicated = v end
    return v == true
end

-- main.lua hands us the game state each bootstrap pass; it is the only module
-- that tracks session identity.
function R.setWorld(obj)
    worldCtx = obj
end

-- The local player's controller, or nil (dedicated server, or the world has not
-- spawned one yet).
function R.localController(now)
    now = now or os.clock()
    local p = localHex and players[localHex] or nil
    if p and alive(p.ctrl) then return p.ctrl end
    if localHex then players[localHex] = nil end
    localHex = nil
    if R.isDedicatedServer() then return nil end
    if not due("local", now) then return nil end
    if not scan(now) then return nil end
    p = localHex and players[localHex] or nil
    if p and alive(p.ctrl) then
        misses["local"] = nil
        return p.ctrl
    end
    -- No local controller. The walk itself tells us which case this is, which
    -- beats guessing from elapsed time: controllers present but none of them
    -- ours means this process serves players it is not one of (a dedicated
    -- server), so stop looking; no controllers at all means the world is still
    -- streaming in, so stay responsive.
    misses["local"] = { at = now, gap = sawControllers and LOCAL_BACKOFF_MAX or BACKOFF_MIN }
    return nil
end

-- The local player's own base-camp network component. Read live off the cached
-- controller: Transmitter.BaseCamp can become valid after the scan that found
-- the controller, and re-reading it is O(1) either way.
function R.localComp(now)
    local ctrl = R.localController(now)
    if not alive(ctrl) then return nil end
    local comp = nil
    pcall(function()
        local tx = ctrl.Transmitter
        if alive(tx) then
            local bc = tx.BaseCamp
            if alive(bc) then comp = bc end
        end
    end)
    return comp
end

-- That player's component, for routing an RPC at them. nil means they are not
-- connected (or not connected yet) — callers must defer, never fall back to
-- somebody else's component.
function R.compOf(uidHex, now)
    if type(uidHex) ~= "string" then return nil end
    now = now or os.clock()
    local p = players[uidHex]
    if p and alive(p.comp) then return p.comp end
    local tag = "comp:" .. uidHex
    if not due(tag, now) then return nil end
    if not scan(now) then return nil end
    p = players[uidHex]
    if p and alive(p.comp) then
        misses[tag] = nil
        return p.comp
    end
    missed(tag, now)
    return nil
end

-- Which player owns the component an RPC arrived on, as the 32-hex PlayerUId.
-- Matching is by GetFullName() STRING — wrapper equality across separate UE4SS
-- calls is unreliable.
function R.ownerOf(compName, now)
    if type(compName) ~= "string" then return nil end
    now = now or os.clock()
    local hex = compOwner[compName]
    if hex then return hex end
    local tag = "owner:" .. compName
    if not due(tag, now) then return nil end
    if not scan(now) then return nil end
    hex = compOwner[compName]
    if hex then
        misses[tag] = nil
        return hex
    end
    missed(tag, now)
    return nil
end

-- Event feed: a hook delivered a live component. A name we have never indexed
-- is proof of a player the dictionary is missing, so drop that question's
-- backoff and let the next ask scan immediately.
function R.note(compName)
    if type(compName) ~= "string" then return end
    if compOwner[compName] == nil then
        misses["owner:" .. compName] = nil
    end
end

function R.reset()
    players, compOwner, misses = {}, {}, {}
    localHex, dedicated, worldCtx = nil, nil, nil
    sawControllers = false
    lastScanAt = -math.huge
end

return R
