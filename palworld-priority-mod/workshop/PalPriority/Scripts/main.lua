-- ============================================================================
-- PalPriority — RimWorld-style work priorities for Palworld base pals.
-- UE4SS (Okaetsu fork) Lua mod. Palworld 1.0.
--
-- ONE INSTALL. This mod contains both halves and turns on whichever the machine
-- actually needs, so single-player, co-op host, remote client and dedicated
-- server all install the same thing:
--
--   engine (priority logic, config, work shaping)  <- runs where there is AUTHORITY
--   interface (numbers on the work screen, clicks) <- runs where there is a LOCAL PLAYER
--
-- Those are independent questions, not one role: a remote client has no
-- authority but does need the interface, and a dedicated server is the reverse.
-- Both gates are re-evaluated per session, because the game does not restart
-- between "play single-player" and "join a friend's server" — latching the
-- engine on would leave it shaping pals it has no authority over.
--
-- Hooks are registered ONCE and always, and the handlers check their gate instead
-- of being attached and detached. NOTE: the original reason given for this was
-- "UE4SS has no reliable unhook", which is wrong for this build — UnregisterHook
-- (UFunctionName, PreId, PostId) is documented in ue4ss/Mods/shared/Types.lua and
-- used in production by ConsoleEnablerMod. The gate-check design is kept because
-- it is simpler and a failed re-register would silently stop the engine, not
-- because detaching is impossible. The hook ids used to be captured here against
-- a hypothetical detach-under-load path; nothing ever read them, so they are
-- gone. probe/TransportLoadProbe (F7) is where detaching gets tested, and the id
-- capture belongs there, not in the shipped mod.
--
-- SAFETY
--   A Lua error thrown from a hook can crash the game. Every game-object access
--   is pcall-wrapped and alive()-gated. See shared.lua for the crash rules.
-- ============================================================================

local VERSION = "1.3.0"

-- Dev diagnostics (F8 reload, F9 roster dump, F10 interface dump). Ships false.
local DEBUG = false

-- Routine per-operation logging. Ships false; DEBUG implies it.
local VERBOSE = false

-- FINISH THE JOB. A pal preempted by a more important type keeps its current
-- type enabled long enough to finish what it is carrying, instead of dropping a
-- half-done haul the instant a priority-1 job pulses.
--
-- This used to ship off because CONTINUOUS work has nothing to finish: a lit
-- campfire never completes, so a pal protected on one would never be preemptible
-- again. The engine now identifies those types per camp from the job's own
-- RequiredWorkAmount and excepts them, so a ranching pal still leaves for a cold
-- campfire while an in-progress haul survives.
local PROTECT_CURRENT = true

local S = require("shared")
S.DEBUG, S.VERBOSE = DEBUG, VERBOSE
local log, alive = S.log, S.alive

log(string.format("v%s loading...", VERSION))

-- ---------------------------------------------------------------------------
-- Migration guard. Two engines fighting over the same pals is far worse than
-- the install confusion this release exists to fix: duplicate work-shaping RPCs,
-- two processes writing priorities.lua, and every click cycling twice because
-- two interfaces each attest it. Refuse to start rather than half-work.
-- ---------------------------------------------------------------------------
local function legacyUIPresent()
    local dir = S.modDir()
    if not dir then return nil end
    local sibling = dir:gsub("[/\\]PalPriority$", "") .. "/PalPriorityUI/Scripts/main.lua"
    local f = io.open(sibling, "r")
    if not f then return nil end
    f:close()
    return sibling
end

do
    local legacy = legacyUIPresent()
    if legacy then
        log("=====================================================================")
        log("NOT STARTING — the old separate interface mod is still installed:")
        log("  " .. legacy)
        log("Since 1.3.0 this mod contains BOTH halves in one install.")
        log("Remove the PalPriorityUI mod (in Vortex: disable/remove 'PalPriority")
        log("UI'; manual installs: delete the ue4ss/Mods/PalPriorityUI folder),")
        log("then restart. Your priorities in PalPriority/priorities.lua are kept.")
        log("=====================================================================")
        return
    end
end

local R = require("registry")
local Engine = require("engine")
local UI = require("ui")

Engine.configure({
    protectCurrent = PROTECT_CURRENT,
    debug = DEBUG,
})

-- ---------------------------------------------------------------------------
-- Role gates
-- ---------------------------------------------------------------------------
local engineActive, uiActive = false, false
local sawServerEvent = false      -- a server-internal hook fired => we have authority
local gsRef, gsName = nil, nil    -- game state, the session identity
local lastBootstrapAt = -math.huge
local BOOTSTRAP_SEARCHING = 1.0   -- while a gate is still undecided
local BOOTSTRAP_SETTLED   = 5.0   -- once both are decided: just watch for a new session

-- Cached so the steady-state check is an alive() call rather than a scan.
local function gameState()
    if alive(gsRef) then return gsRef end
    gsRef = nil
    pcall(function()
        -- BP classes need the _C suffix for FindFirstOf; the native parent is
        -- tried too in case a future build changes the hierarchy.
        for _, cls in ipairs({ "BP_PalGameStateInGame_C", "PalGameStateInGame" }) do
            local o = FindFirstOf(cls)
            if alive(o) and not S.isDefaultObject(S.fullNameOf(o)) then
                gsRef = o
                return
            end
        end
    end)
    return gsRef
end

-- Authority. Primary signal is that a server-internal hook has fired, which is
-- proven on this build and cannot be wrong. HasAuthority() is BlueprintCallable
-- but unverified here, so it is only a fast path for the case where no work has
-- pulsed yet (an empty base, a fresh dedicated server).
local function hasAuthority()
    if sawServerEvent then return true end
    local auth = nil
    pcall(function()
        local gs = gameState()
        if alive(gs) then auth = gs:HasAuthority() end
    end)
    return auth == true
end

-- Registry-backed: this used to walk the whole object array on EVERY bootstrap
-- pass, and the pass stays on its 1s searching interval for as long as either
-- gate is undecided — i.e. forever on a dedicated server, which never has a
-- local player to find. Now it is a dictionary read, and the walk behind it is
-- rate-limited, backed off, and skipped outright once the process identifies
-- itself as dedicated.
local function hasLocalPlayer(now)
    return R.localController(now) ~= nil
end

local function bootstrapTick(now)
    local due = (engineActive and uiActive) and BOOTSTRAP_SETTLED or BOOTSTRAP_SEARCHING
    if (now - lastBootstrapAt) < due then return end
    lastBootstrapAt = now

    -- New session? The process survives menu -> single-player -> join server,
    -- and the role can be different each time.
    local gs = gameState()
    local name = S.fullNameOf(gs)
    if name ~= gsName then
        if gsName ~= nil then
            log("session changed — re-evaluating this machine's role")
            if engineActive then pcall(Engine.reset) end
            if uiActive then pcall(UI.reset) end
            S.clearLogOnce()
        end
        pcall(R.reset)
        gsName = name
        engineActive, uiActive, sawServerEvent = false, false, false
    end
    if name == nil then return end   -- no world yet (main menu)
    R.setWorld(gs)

    if not engineActive and hasAuthority() then
        engineActive = true
        local ok, err = pcall(Engine.activate)
        if ok then
            log("engine active — this machine has authority over base pals")
        else
            engineActive = false
            log("engine activation failed: " .. tostring(err))
        end
    end

    if not uiActive and hasLocalPlayer(now) then
        uiActive = true
        local ok, err = pcall(UI.activate)
        if ok then
            log("interface active — local player present")
        else
            uiActive = false
            log("interface activation failed: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Hooks. Registered once; each handler checks its own gate.
-- ---------------------------------------------------------------------------

-- Pending-work intake. Server-internal, so its firing is the authority proof.
-- This is the mod's highest-frequency hook by a wide margin: it pulses every 1-4s
-- PER UNFILLED JOB, so a base whose production outruns its hauling drives it into
-- the hundreds-to-thousands of calls per second.
local HOOK_A = "/Script/Pal.PalBaseCampWorkerDirector:OnRequiredAssignWork_ServerInternal"

local okA, errA = pcall(function()
    RegisterHook(HOOK_A,
        function(Context, Work, RequirementParameter)
            sawServerEvent = true
            if not engineActive then return end
            local ok, err = pcall(Engine.onRequiredAssignWork, Context, Work, RequirementParameter)
            if not ok then S.logOnce("assignhook", "assign hook error: " .. tostring(err)) end
        end)
end)
log(okA and "HOOK OK OnRequiredAssignWork_ServerInternal"
    or ("HOOK FAILED OnRequiredAssignWork_ServerInternal: " .. tostring(errA)))

local okA2, errA2 = pcall(function()
    RegisterHook("/Script/Pal.PalBaseCampWorkerDirector:OnNotifiedUnassignWork_ServerInternal",
        function(Context, Work, IndividualId)
            sawServerEvent = true
            if not engineActive then return end
            local ok, err = pcall(Engine.onUnassignWork, Context, Work, IndividualId)
            if not ok then S.logOnce("unassignhook", "unassign hook error: " .. tostring(err)) end
        end)
end)
log(okA2 and "HOOK OK OnNotifiedUnassignWork_ServerInternal"
    or ("HOOK FAILED OnNotifiedUnassignWork_ServerInternal: " .. tostring(errA2)))

-- The vanilla toggle. BOTH halves care: the interface attests the click, the
-- engine applies cycle semantics. One registration, both notified — and because
-- they now share a process we can tell the engine's own writes apart directly,
-- instead of the interface attesting them by accident as it did when the two
-- were separate mods on a host.
local okB, errB = pcall(function()
    RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:RequestChangeWorkSuitability_ToServer",
        function(Context, TargetIndividualId, WorkSuitability, bOn)
            local internal = engineActive and Engine.isInternalCall()
            if uiActive and not internal then
                local ok, err = pcall(UI.onToggle, Context, TargetIndividualId, WorkSuitability, bOn)
                if not ok then S.logOnce("uitoggle", "interface toggle hook error: " .. tostring(err)) end
            end
            if engineActive then
                local ok, err = pcall(Engine.onToggle, Context, TargetIndividualId, WorkSuitability, bOn)
                if not ok then S.logOnce("togglehook", "toggle hook error: " .. tostring(err)) end
            end
        end)
end)
log(okB and "HOOK OK RequestChangeWorkSuitability_ToServer"
    or ("HOOK FAILED RequestChangeWorkSuitability_ToServer: " .. tostring(errB)))

-- Client -> server transport (engine side).
local okC, errC = pcall(function()
    RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:Request_Server_int32",
        function(Context, BaseCampId, FunctionName, Value)
            if not engineActive then return end
            local ok, err = pcall(Engine.onServerInt32, Context, BaseCampId, FunctionName, Value)
            if not ok then S.logOnce("transporthook", "transport hook error: " .. tostring(err)) end
        end)
end)
log(okC and "HOOK OK Request_Server_int32"
    or ("HOOK FAILED Request_Server_int32: " .. tostring(errC)))

-- Server -> client priority sync (interface side).
local okD, errD = pcall(function()
    RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:Notify_RequestClient_int32",
        function(Context, BaseCampId, FunctionName, Value)
            if not uiActive then return end
            local ok, err = pcall(UI.onNotifyClient, Context, BaseCampId, FunctionName, Value)
            if not ok then S.logOnce("synchook", "sync hook error: " .. tostring(err)) end
        end)
end)
log(okD and "HOOK OK Notify_RequestClient_int32"
    or ("HOOK FAILED Notify_RequestClient_int32: " .. tostring(errD)))

-- ---------------------------------------------------------------------------
-- Keybinds (dev-only; inert in release)
-- ---------------------------------------------------------------------------
pcall(function()
    if not DEBUG then return end
    RegisterKeyBind(Key.F8, function()
        if engineActive then pcall(Engine.reload) end
    end)
    RegisterKeyBind(Key.F9, function()
        if engineActive then pcall(Engine.dumpRoster) end
    end)
    RegisterKeyBind(Key.F10, function()
        if uiActive then pcall(UI.diagnostic) end
    end)
end)

pcall(function()
    local rmb = Key.RIGHT_MOUSE_BUTTON
    if rmb == nil then
        log("Key.RIGHT_MOUSE_BUTTON unavailable in this UE4SS build — right-click decrement disabled")
        return
    end
    RegisterKeyBind(rmb, function()
        if not uiActive then return end
        local ok, err = pcall(UI.onRightClick)
        if not ok then S.logOnce("rclick", "right-click handler error: " .. tostring(err)) end
    end)
end)

-- ---------------------------------------------------------------------------
-- The one loop. LoopAsync runs OFF the game thread, so game access hops on.
-- The hop only happens when something actually wants it: an idle client with
-- the work screen closed, or a settled server with nothing changing, costs a
-- couple of plain Lua comparisons per pass.
-- ---------------------------------------------------------------------------
local ENGINE_INTERVAL = 1.0
local lastEngineAt = -math.huge

pcall(function()
    LoopAsync(500, function()
        local ok, err = pcall(function()
            local now = os.clock()
            local bootstrapDue = (now - lastBootstrapAt)
                >= ((engineActive and uiActive) and BOOTSTRAP_SETTLED or BOOTSTRAP_SEARCHING)
            local engineDue = engineActive and ((now - lastEngineAt) >= ENGINE_INTERVAL)
            local uiDue = uiActive and UI.wantsTick()
            if not (bootstrapDue or engineDue or uiDue) then return end

            ExecuteInGameThread(function()
                local okt, errt = pcall(function()
                    bootstrapTick(os.clock())
                    if engineActive and (os.clock() - lastEngineAt) >= ENGINE_INTERVAL then
                        lastEngineAt = os.clock()
                        Engine.tick()
                    end
                    if uiActive then UI.tick() end
                end)
                if not okt then S.logOnce("tick", "tick error: " .. tostring(errt)) end
            end)
        end)
        if not ok then S.logOnce("loop", "LoopAsync error: " .. tostring(err)) end
        return false
    end)
end)

log(string.format("v%s ready — single install; engine and interface each start when needed.%s",
    VERSION, DEBUG and " Keys: F8 reload, F9 roster, F10 interface." or ""))
