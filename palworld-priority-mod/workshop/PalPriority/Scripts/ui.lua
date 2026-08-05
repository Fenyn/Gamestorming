-- ============================================================================
-- PalPriority — interface half. Renders each work-suitability cell's priority
-- number (1-5) on the vanilla "Work Suitability Preference" screen, attests
-- this client's clicks to the engine, and adds the right-click decrement.
-- Ported from the 1.2.0 PalPriorityUI mod.
--
-- main.lua owns the loop, the keybinds and every hook EXCEPT the lazy
-- BindFromSlot registration below (which must retry until the BP class loads).
--
-- Priority state arrives from the engine over Notify_RequestClient_int32 — the
-- only path that reaches remote clients on dedicated servers, and it executes
-- locally on listen-server/single-player too. Reading priorities.lua from disk
-- is bootstrap/fallback only.
--
-- A configured pal shows its number on each work type (blank at 0, so the
-- vanilla unchecked 'X' shows through). Unconfigured pals show a dim monochrome
-- PREVIEW of the defaults a first click would create, computed client-side from
-- their current toggles — colored numbers mean the engine manages the pal, dim
-- ones are display-only.
--
-- SAFETY: this touches live UI widgets every 500ms. See shared.lua's crash
-- rules. Degraded paths log once, never in a loop; a cell that fails is skipped.
-- ============================================================================

local S = require("shared")
local R = require("registry")
local log, logOnce, alive = S.log, S.logOnce, S.alive

local U = {}

-- ---------------------------------------------------------------------------
-- Known BP class names (the _C suffix is required for FindAllOf — verified:
-- without it, FindAllOf finds nothing for Blueprint-generated classes).
-- ---------------------------------------------------------------------------
local MENU_CLASS = "WBP_WorkSuitabilityPreferenceMenu_C"
local CELL_CLASS = "WBP_WorkSuitabilityPreference_CheckBox_0_C"
-- Game's own typo "Worl" (not "Work") — keep it exactly, it is the real class name.
local ROW_CLASS  = "WBP_WorlSuitabilityPreference_PalList_C"
local WORK_MAX   = 13 -- highest valid EPalWorkSuitability value

-- ---------------------------------------------------------------------------
-- Config load (READ-ONLY) — bootstrap/fallback; the sync channel is the real
-- source. Same parsing as the engine's loadConfig.
-- ---------------------------------------------------------------------------
local config = { pals = {} } -- last good config; kept on any reload failure
local CONFIG_PATH = "Mods/PalPriority/priorities.lua"

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
        end
    end
    return result
end

-- The engine's priorities.lua now lives in THIS mod's folder, so modDir() is the
-- answer whatever the install layout or cwd; the rest are cwd-relative guesses
-- kept for builds where package.path has a surprise shape.
-- Returns (path, foundOnDisk).
local function resolveConfigPath()
    local candidates = {
        "Mods/PalPriority/priorities.lua",
        "ue4ss/Mods/PalPriority/priorities.lua",
        "priorities.lua",
        -- Steam-workshop UE4SS layout (tester-verified): mods live under
        -- <game>/Pal/Mods/NativeMods/UE4SS/Mods/ while cwd sits in Win64.
        "../../../Mods/NativeMods/UE4SS/Mods/PalPriority/priorities.lua",
    }
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

-- Silent on failure: the engine rewrites the file atomically, so a transient
-- mid-write read just retries with the last good copy still in hand.
local function reloadConfig()
    local cfg = loadConfig(CONFIG_PATH)
    if cfg then config = cfg end
end

-- ---------------------------------------------------------------------------
-- Per-cell caches (keyed by cell:GetFullName()).
-- ---------------------------------------------------------------------------
local injected = {}     -- cellFullName -> injected TextBlock widget
local lastText = {}     -- cellFullName -> last style-qualified token we SetText'd
local origCbVis = {}    -- cellFullName -> the PalCheckBox's original visibility
local ftextMethod = nil -- "direct" | "kismet" — probed once, process-wide
local kismetLib = nil   -- cached Default__KismetTextLibrary for the fallback path

-- UE4SS 3.x usually has FText(str); some builds need the KismetTextLibrary
-- conversion. Probe once, then cache the working method.
local function makeFText(str)
    if ftextMethod == "direct" then
        local ft = nil
        local ok = pcall(function() ft = FText(str) end)
        if ok then return ft end
        return nil
    elseif ftextMethod == "kismet" then
        if not kismetLib then return nil end
        local ft = nil
        local ok = pcall(function() ft = kismetLib:Conv_StringToText(str) end)
        if ok then return ft end
        return nil
    end

    local ft = nil
    local ok = pcall(function() ft = FText(str) end)
    if ok and ft ~= nil then
        ftextMethod = "direct"
        return ft
    end

    local lib = nil
    pcall(function() lib = StaticFindObject("/Script/Engine.Default__KismetTextLibrary") end)
    if lib then
        local ok2 = pcall(function() ft = lib:Conv_StringToText(str) end)
        if ok2 and ft ~= nil then
            ftextMethod = "kismet"
            kismetLib = lib
            return ft
        end
    end

    logOnce("ftext", "no working FText construction path found — numbers cannot render")
    return nil
end

-- Priority colors (RimWorld scale: 1 = most important). Green fades through
-- yellow/orange to red as importance drops; X (never) is neutral gray.
local PRIO_COLORS = {
    ["1"] = { R = 0.25, G = 0.90, B = 0.25 },
    ["2"] = { R = 0.60, G = 0.88, B = 0.20 },
    ["3"] = { R = 0.95, G = 0.85, B = 0.15 },
    ["4"] = { R = 0.95, G = 0.55, B = 0.10 },
    ["5"] = { R = 0.90, G = 0.25, B = 0.15 },
    ["X"] = { R = 0.62, G = 0.62, B = 0.62 },
}

-- Default-preview glyphs render in ONE uniform dim gray, deliberately outside
-- the green->red scale, so managed pals and previews differ at a glance.
local PREVIEW_COLOR = { R = 0.75, G = 0.75, B = 0.75 }

-- Callers gate on lastText first so we don't rebuild an FText every 500ms. The
-- cached token is STYLE-QUALIFIED ("3" real vs "3~" preview) so a same-glyph
-- preview<->real transition still restyles.
local function setText(tb, cellName, str, isPreview)
    local ft = makeFText(str)
    if ft == nil then return end
    local ok = pcall(function() tb:SetText(ft) end)
    if ok then
        lastText[cellName] = isPreview and (str .. "~") or str
        local c = isPreview and PREVIEW_COLOR or PRIO_COLORS[str]
        if c then
            pcall(function()
                tb:SetColorAndOpacity({
                    SpecifiedColor = { R = c.R, G = c.G, B = c.B, A = 1.0 },
                    ColorUseRule = 0,
                })
            end)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Row + pal-key resolution.
-- ---------------------------------------------------------------------------

-- Cell -> row association. Verified dead ends: the cell's OUTER chain goes to the
-- GameInstance (dynamic CreateWidget), and the row's HorizontalBox_CheckBox has 0
-- children at runtime (the game re-parents the cells after construction). What
-- works: the cell's SLATE parent (GetParent(), the panel it actually renders in)
-- lives inside the row's widget tree, so parent -> Outer chain reaches the row.
local function rowOfCell(cell)
    local node = nil
    pcall(function() node = cell:GetParent() end)
    if not alive(node) then return nil end
    for _ = 1, 5 do
        if S.classNameOf(node) == ROW_CLASS then return node end
        local outer = nil
        pcall(function() outer = node:GetOuter() end)
        if not alive(outer) then return nil end
        node = outer
    end
    return nil
end

-- Poll-loop caches. FindAllOf(CELL_CLASS) and the per-cell parent/outer walk are
-- the two expensive things a tick does, and neither changes while the same rows
-- stay bound. Dropped on rebind, on losing the menu, or on any dead cached cell —
-- correctness first: rescan rather than render from a stale list.
local cellCache = nil   -- array of cell widgets (revalidated with alive() per use)
local cellRowName = {}  -- cellFullName -> rowFullName
-- Per-cell facts that CANNOT change while the same rows stay bound: which work
-- type the cell is, and whether it is the battle-mode variant we skip. Re-read
-- every 500ms for every cell on screen before this; ~13 cells per visible row
-- made that the interface's dominant cost while the screen is open.
local cellFacts = {}    -- cellFullName -> { skip = true } | { t = <work type> }
-- Generation stamp for the vanilla-checkbox hide. Bumped on rebind and on a
-- slow timer, so the hide is re-asserted when it can actually have been undone
-- instead of on every cell on every tick.
local visGen = 0
local cbGen = {}        -- cellFullName -> visGen it was last hidden at
local lastVisSweepAt = -math.huge
local VIS_REASSERT_SECONDS = 5
local function invalidateCells()
    cellCache = nil
    cellRowName = {}
    cellFacts = {}
    visGen = visGen + 1
end

-- CRASH RULE #2 (from a live crash): merely READING the row's `bindedSlot`
-- SoftObjectProperty crashes natively inside UE4SS (push_softobjectproperty ->
-- FString::operator= AV) — the crash is in the property read itself, before Lua
-- sees anything, so alive()/pcall cannot help. NEVER read bindedSlot. Instead:
-- the row's BindFromSlot is a BLUEPRINT function (always executes via the
-- hookable reflection layer); hook it and capture the row -> pal-key mapping at
-- bind time, with the slot arriving as a safe hook arg.
local rowKeyCache = {} -- rowFullName -> { key, raw, preview? } (rows recycle)
local bindHooked = false       -- process-wide: UE4SS has no unhook, survives reset()
local lastHookTry = -math.huge -- os.clock() of the last registration attempt
local HOOK_RETRY_SEC = 5       -- LoadAsset+RegisterHook are costly; don't spin at tick rate
local bindCaptures = 0
-- Screen-open signal. BindFromSlot fires on every screen open/rebind (verified),
-- so it doubles as our "the work screen is (probably) up" flag. While false,
-- wantsTick() and the right-click handler bail on a plain Lua read — no game
-- calls, no game-thread hop — which is the whole idle cost of this half.
local menuLikelyOpen = false
local menuRef = nil           -- cached menu widget while open (avoids FindAllOf per tick)
local uiInternal = false      -- true while WE call the toggle RPC (right-click path)
local lastPingAt = -math.huge -- os.clock() of the last SUCCESSFUL PrioMod_Ping
local firstPingAt = nil       -- os.clock() of the FIRST successful ping (sync watchdog)

-- Server-pushed priority state. Once ANY sync message parses, `synced`
-- supersedes the file-read `config`.
local synced = { pals = {} }
local syncReceived = false
local syncLogs = 0 -- first-few sync messages get logged, then quiet

local ROW_BP_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/WorkSuitabilityPreference/WBP_WorlSuitabilityPreference_PalList.WBP_WorlSuitabilityPreference_PalList_C"
local ROW_BIND_FN = ROW_BP_CLASS .. ":BindFromSlot"

-- BP classes load on demand, so hook registration fails until the class exists —
-- and rows bound BEFORE registration are never captured. Force-load the class
-- eagerly with LoadAsset so the hook is in place before the screen first opens.
-- Game thread only (LoadAsset); callers are already on it.
local function tryHookBind()
    if bindHooked then return end
    pcall(function() LoadAsset(ROW_BP_CLASS) end)
    local ok = pcall(function()
        RegisterHook(ROW_BIND_FN, function(Context, SlotParam)
            -- Our own hook: nothing above catches a throw, so the body is wrapped.
            pcall(function()
                local row = Context:get()
                if not alive(row) then return end
                local rname = S.fullNameOf(row)
                if not rname then return end
                local slot = SlotParam:get()
                if not alive(slot) then return end
                local handle = slot.Handle
                if not alive(handle) then return end
                local id = handle:GetIndividualID()
                if id == nil then return end
                local okk, key = pcall(function()
                    return S.palKey(id.PlayerUId, id.InstanceId)
                end)
                if okk and key then
                    -- Keep the RAW (unnormalized) guid ints too: right-click needs
                    -- them verbatim to address this pal in the toggle RPC.
                    local raw = nil
                    pcall(function()
                        raw = {
                            PlayerUId  = { A = id.PlayerUId.A,  B = id.PlayerUId.B,
                                           C = id.PlayerUId.C,  D = id.PlayerUId.D },
                            InstanceId = { A = id.InstanceId.A, B = id.InstanceId.B,
                                           C = id.InstanceId.C, D = id.InstanceId.D },
                        }
                    end)
                    rowKeyCache[rname] = { key = key, raw = raw }
                    menuLikelyOpen = true -- rows binding == the screen is opening
                    invalidateCells() -- rows rebinding == the cell list/mapping moved
                    bindCaptures = bindCaptures + 1
                    if bindCaptures <= 5 then
                        log(string.format("interface: bind capture #%d: %s", bindCaptures, key))
                    end
                    -- DEFAULT PREVIEW (display-only, no server traffic). Without
                    -- a config entry the row shows nothing until first click; so
                    -- precompute the row the engine's auto-config WOULD create
                    -- (enabled work types -> 3, off-list types -> 0/X) from the
                    -- pal's own replicated data. Runs strictly AFTER the key/raw
                    -- capture — any failure here just leaves .preview nil and the
                    -- row keeps its vanilla checkboxes; the capture itself must
                    -- never be blocked. A rebind recomputes, so the preview
                    -- tracks vanilla toggle changes made while unconfigured.
                    -- TryGetIndividualParameter may legitimately fail on remote
                    -- clients when the parameter isn't replicated yet.
                    pcall(function()
                        local param = nil
                        pcall(function() param = handle:TryGetIndividualParameter() end)
                        if not alive(param) then return end
                        -- The pal's vanilla off-list (unchecked work types).
                        local off = {}
                        pcall(function()
                            local list = param.SaveParameter.WorkSuitabilityOptionInfo.OffWorkSuitabilityList
                            S.arrayForEach(list, function(v)
                                if type(v) == "number" then off[v] = true end
                            end)
                        end)
                        local prio = {}
                        local any = false
                        for t = 1, WORK_MAX do
                            local has = false
                            pcall(function() has = param:HasWorkSuitability(t) end)
                            if has == true then
                                prio[t] = off[t] and 0 or 3
                                any = true
                            end
                        end
                        if any then
                            rowKeyCache[rname].preview = { prio = prio, preview = true }
                        end
                    end)
                end
            end)
        end)
    end)
    if ok then
        bindHooked = true
        log("interface: BindFromSlot hook registered — row->pal mapping active")
    end
end

-- Row -> pal key, from the bind-time cache only. nil until the row (re)binds
-- after our hook registered — the screen re-opening always repopulates it.
local function resolveKey(rowName)
    local e = rowKeyCache[rowName]
    return e and e.key or nil
end

-- Row -> raw pal identity (for addressing the pal in an RPC), or nil.
local function resolveRaw(rowName)
    local e = rowKeyCache[rowName]
    return e and e.raw or nil
end

-- ---------------------------------------------------------------------------
-- Our OWN network component. The engine identifies modded clients by WHICH
-- component their messages arrive on, so FindFirstOf("PalNetworkBaseCampComponent")
-- is a multiplayer correctness bug: it can return a stale instance or ANOTHER
-- player's component, making the engine read this player's toggles as unmodded
-- and RELEASE the pal (the "numbers disappear" reports). Resolve ours via the
-- local PalPlayerController's Transmitter.BaseCamp (callpath-map: RPC surface).
-- ---------------------------------------------------------------------------
local ownCompCache = nil
-- true when the cached component did NOT come from the local controller (global
-- fallback / hook adoption): good enough to send on, never trustworthy enough to
-- decide that some OTHER component isn't ours.
local ownCompFallback = false
-- A nil answer used to cache nothing, so isOwnComp() on a listen host walked the
-- whole object array TWICE per unresolved call. The registry rate-limits the
-- controller side; this gaps the FindFirstOf fallback behind it.
local lastFallbackAt = -math.huge
local FALLBACK_GAP = 10
local function getOwnBaseCampComp()
    if alive(ownCompCache) then return ownCompCache end
    ownCompCache = nil
    ownCompFallback = false
    local comp = R.localComp()
    if not alive(comp) then
        comp = nil
        -- Degraded: the old global search. Wrong-component risk returns, but a
        -- possibly-right component still beats none at all.
        if (os.clock() - lastFallbackAt) >= FALLBACK_GAP then
            lastFallbackAt = os.clock()
            pcall(function()
                local c = FindFirstOf("PalNetworkBaseCampComponent")
                if alive(c) then comp = c end
            end)
            if comp ~= nil then
                ownCompFallback = true
                logOnce("owncomp-fb",
                    "own base-camp component unresolved — FindFirstOf fallback (may be another player's)")
            end
        end
    end
    ownCompCache = comp
    return comp
end

-- Is this hook Context OUR component? Returns (isOwn, known). known=false means
-- we could not authoritatively resolve our own component, and callers must keep
-- the unguarded behavior — a solo player must never lose the feature.
-- LISTEN SERVER: the host runs remote players' Server RPCs in-process, so the
-- component hooks fire for other players too; acting on those attests THEIR
-- vanilla clicks as modded cycles.
local function isOwnComp(c)
    local own = getOwnBaseCampComp()
    if not alive(own) or ownCompFallback then return false, false end
    local a, b = S.fullNameOf(c), S.fullNameOf(own)
    if a == nil or b == nil then return false, false end
    return a == b, true
end

-- ---------------------------------------------------------------------------
-- TextBlock injection into a cell's widget tree.
-- ---------------------------------------------------------------------------

-- Locate an insertion target in the cell's widget tree. Returns (target, isOverlay,
-- tree). Prefers an "Overlay" panel (so the number can center over the checkbox);
-- otherwise falls back to the RootWidget and lets the caller try plain AddChild.
local function findInsertTarget(cell)
    local tree = nil
    pcall(function() tree = cell.WidgetTree end)
    if not alive(tree) then return nil, false, nil end

    local root = nil
    pcall(function() root = tree.RootWidget end)
    if not alive(root) then return nil, false, tree end

    if S.classNameOf(root) == "Overlay" then
        return root, true, tree
    end

    -- Breadth-first scan for an Overlay, capped so a pathological tree can't spin.
    local queue = { root }
    local visited = 0
    while #queue > 0 and visited < 20 do
        local node = table.remove(queue, 1)
        visited = visited + 1
        if S.classNameOf(node) == "Overlay" then
            return node, true, tree
        end
        local n = 0
        pcall(function() n = node:GetChildrenCount() end)
        if type(n) == "number" then
            for i = 0, n - 1 do
                local child = nil
                pcall(function() child = node:GetChildAt(i) end)
                if alive(child) then queue[#queue + 1] = child end
            end
        end
    end

    return root, false, tree
end

-- Insert the text block as a SIBLING of the hidden PalCheckBox in the SAME
-- parent panel, copying its slot geometry — identical placement by construction.
-- The cell's internals are canvas-style (absolute layout: a slot mirror of
-- alignment properties failed live, and overlay-centering landed a full column
-- off), so geometry must be copied, not inferred.
local function injectAtCheckbox(cell, tb)
    local cb = nil
    pcall(function() cb = cell.PalCheckBox end)
    if not alive(cb) then return false end
    local parent = nil
    pcall(function() parent = cb:GetParent() end)
    if not alive(parent) then return false end
    local cbSlot = nil
    pcall(function() cbSlot = cb.Slot end)
    if not alive(cbSlot) then return false end

    local newSlot = nil
    local okAdd = pcall(function() newSlot = parent:AddChild(tb) end)
    if not okAdd or not alive(newSlot) then return false end

    local slotCls = S.classNameOf(cbSlot) or ""
    if slotCls == "CanvasPanelSlot" then
        -- Absolute layout: replicate the checkbox's exact rectangle, draw above it.
        pcall(function() newSlot:SetAnchors(cbSlot:GetAnchors()) end)
        pcall(function() newSlot:SetPosition(cbSlot:GetPosition()) end)
        pcall(function() newSlot:SetSize(cbSlot:GetSize()) end)
        pcall(function() newSlot:SetAlignment(cbSlot:GetAlignment()) end)
        pcall(function() newSlot:SetZOrder(cbSlot:GetZOrder() + 1) end)
    else
        -- Box/overlay-style layout: copy alignment + padding where present.
        pcall(function() newSlot:SetHorizontalAlignment(cbSlot.HorizontalAlignment) end)
        pcall(function() newSlot:SetVerticalAlignment(cbSlot.VerticalAlignment) end)
        pcall(function() newSlot:SetPadding(cbSlot.Padding) end)
    end
    logOnce("injectmode", "interface: number placement — checkbox-sibling (" .. slotCls .. ")")
    return true
end

-- Ensure a TextBlock overlay exists on this cell; returns it or nil. Cached by
-- cellName; stale/invalid caches are dropped and re-injected. Never throws.
local function ensureTextBlock(cell, cellName)
    local cached = injected[cellName]
    if cached then
        -- STRICT alive() only: an earlier version probed GetVisibility() when
        -- IsValid was unavailable, and that probe is itself a native crash on a
        -- stale wrapper.
        if alive(cached) then return cached end
        injected[cellName] = nil
        lastText[cellName] = nil
    end

    local tree = nil
    pcall(function() tree = cell.WidgetTree end)
    if not alive(tree) then
        logOnce("inject:" .. CELL_CLASS,
            "number overlay injection failed — priorities work but are display-less; check log")
        return nil
    end

    local tbClass = nil
    pcall(function() tbClass = StaticFindObject("/Script/UMG.TextBlock") end)
    if not tbClass then
        logOnce("inject:" .. CELL_CLASS,
            "number overlay injection failed — priorities work but are display-less; check log")
        return nil
    end

    -- Outer = the WidgetTree, so the new widget is owned by the cell's tree.
    local tb = nil
    pcall(function() tb = StaticConstructObject(tbClass, tree) end)
    if not alive(tb) then
        logOnce("inject:" .. CELL_CLASS,
            "number overlay injection failed — priorities work but are display-less; check log")
        return nil
    end

    -- Primary: sibling-of-checkbox with copied slot geometry (exact placement).
    local added = injectAtCheckbox(cell, tb)
    if not added then
        -- Fallback: overlay/root insertion, centered (may be offset).
        local target, isOverlay = findInsertTarget(cell)
        if target then
            if isOverlay then
                local oslot = nil
                local oka = pcall(function() oslot = target:AddChildToOverlay(tb) end)
                if oka and oslot then
                    added = true
                    pcall(function() oslot:SetHorizontalAlignment(2) end)
                    pcall(function() oslot:SetVerticalAlignment(2) end)
                end
            end
            if not added then
                local oka2 = pcall(function() target:AddChild(tb) end)
                if oka2 then added = true end
            end
            if added then
                logOnce("injectmode", "interface: number placement — overlay fallback (may be offset)")
            end
        end
    end
    if not added then
        logOnce("inject:" .. CELL_CLASS,
            "number overlay injection failed — priorities work but are display-less; check log")
        return nil
    end

    -- HitTestInvisible (3): the number must let clicks pass through to the button.
    pcall(function() tb:SetVisibility(3) end)

    -- Centered glyph within the box the slot gives us (the slot geometry itself
    -- was copied from the checkbox at injection time).
    pcall(function() tb:SetJustification(1) end)

    -- Cosmetics — each independently guarded; a failure just means plainer text.
    pcall(function()
        tb:SetColorAndOpacity({
            SpecifiedColor = { R = 1.0, G = 0.85, B = 0.1, A = 1.0 },
            ColorUseRule = 0,
        })
    end)
    pcall(function() tb:SetShadowOffset({ X = 1, Y = 1 }) end)

    injected[cellName] = tb
    return tb
end

-- ---------------------------------------------------------------------------
-- Per-cell handling.
-- ---------------------------------------------------------------------------
-- One cell of a row whose entry is `entry` (nil for an unconfigured pal, or the
-- display-only default preview). `cellName` is the caller's resolved GetFullName.
local function handleCell(cell, cellName, entry)
    -- Widgets can be mid-teardown between polls.
    if not alive(cell) then return end

    -- Battle-mode variant (skipped entirely) and work type (EPalWorkSuitability;
    -- 0 or out of range means not a work cell we show). Both are fixed for the
    -- life of the binding, so they are read once and cached.
    local facts = cellFacts[cellName]
    if facts == nil then
        local battle = false
        pcall(function() battle = cell.IsBattleSettingMode end)
        if battle == true then
            cellFacts[cellName] = { skip = true }
            return
        end
        local t = nil
        pcall(function() t = cell.BindedSuitability end)
        if type(t) ~= "number" or t <= 0 or t > WORK_MAX then
            cellFacts[cellName] = { skip = true }
            return
        end
        facts = { t = t }
        cellFacts[cellName] = facts
    end
    if facts.skip then return end
    local t = facts.t

    local prio = nil
    local isPreview = false
    if entry and entry.prio then
        prio = entry.prio[t]
        isPreview = entry.preview == true
    end

    if prio == nil then
        -- Unconfigured: we don't manage it. Clear any overlay and restore the
        -- vanilla checkbox if we ever hid it (pal lost its config).
        local tb = injected[cellName]
        if tb and lastText[cellName] ~= "" then
            setText(tb, cellName, "")
        end
        if origCbVis[cellName] ~= nil then
            pcall(function()
                local cb = cell.PalCheckBox
                if alive(cb) then cb:SetVisibility(origCbVis[cellName]) end
            end)
            origCbVis[cellName] = nil
            -- Forget the hide stamp too: this pal can become configured again
            -- WITHOUT a rebind (a click creates its config and the sync channel
            -- delivers it), and a stale stamp would skip the re-hide.
            cbGen[cellName] = nil
        end
        return
    end

    -- Configured: the vanilla check must not show at all — the number IS the
    -- state. Hide the PalCheckBox (Hidden=2 keeps its layout space so the grid
    -- doesn't shift). Only a vanilla row refresh can re-show it, and that means
    -- a rebind, which bumps visGen; the slow timer bump is the safety net for
    -- any path we have not identified. Remember its original visibility once,
    -- for restore if the pal is ever unconfigured.
    if cbGen[cellName] ~= visGen then
        cbGen[cellName] = visGen
        pcall(function()
            local cb = cell.PalCheckBox
            if alive(cb) then
                if origCbVis[cellName] == nil then
                    local okv, v = pcall(function() return cb:GetVisibility() end)
                    origCbVis[cellName] = (okv and type(v) == "number") and v or 0
                end
                cb:SetVisibility(2)
            end
        end)
    end

    local tb = ensureTextBlock(cell, cellName)
    if not tb then return end

    -- Compare the style-qualified token, not just the glyph: a preview->real
    -- transition with the same glyph must still restyle.
    local desired = (prio > 0) and tostring(prio) or "X"
    local token = isPreview and (desired .. "~") or desired
    if lastText[cellName] ~= token then
        setText(tb, cellName, desired, isPreview)
    end
end

-- Display source: server-pushed sync once ANY sync message has arrived, else the
-- file read. The file fallback keeps single-player/host working even if the sync
-- channel breaks after a game patch — deliberate resilience.
local function activeEntry(key)
    if syncReceived then return synced.pals[key] end
    return config.pals[key]
end

-- Cells whose row/key can't resolve are skipped entirely (never cleared — we may
-- just be mid-bind).
local function handleCellTop(cell)
    if not alive(cell) then return end
    local cellName = S.fullNameOf(cell)
    if not cellName or S.isDefaultObject(cellName) then return end

    -- Cached parent/outer walk; the cache dies with the binding that produced it.
    local rowName = cellRowName[cellName]
    if not rowName then
        local row = rowOfCell(cell)
        if not row then return end
        rowName = S.fullNameOf(row)
        if not rowName then return end
        cellRowName[cellName] = rowName
    end

    local key = resolveKey(rowName)
    if not key then return end

    -- Real entries (file or synced) always win; an unconfigured pal falls back
    -- to the bind-time default preview (may be nil -> vanilla checkboxes).
    local entry = activeEntry(key)
    if entry == nil then
        local rc = rowKeyCache[rowName]
        entry = rc and rc.preview or nil
    end
    handleCell(cell, cellName, entry)
end

-- ---------------------------------------------------------------------------
-- Poll tick (game thread).
-- ---------------------------------------------------------------------------
-- Multiple menu instances coexist (seen live: a hidden/stale one alongside the
-- open one), so we must cache a VISIBLE instance, never just the first alive
-- one. IsVisible failing to call counts as visible — don't go dark.
local function isShowing(m)
    local okv, vis = pcall(function() return m:IsVisible() end)
    if not okv then return true end
    return vis == true
end

local function menuIsShowing()
    if alive(menuRef) and isShowing(menuRef) then return true end
    -- Lost the cached menu: any cells we cached belong to a screen that is gone
    -- or being rebuilt.
    menuRef = nil
    invalidateCells()
    local menus = nil
    pcall(function() menus = FindAllOf(MENU_CLASS) end)
    if not menus then return false end
    for _, m in ipairs(menus) do
        if alive(m) then
            local mname = S.fullNameOf(m)
            if mname and not S.isDefaultObject(mname) and isShowing(m) then
                menuRef = m
                return true
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Right-click decrement. Acts only when the work screen is open AND the pointer
-- is over a work cell (IsHovered). Sends a PrioMod_Dir=-1 marker through the
-- custom transport, then the same vanilla toggle RPC a left-click produces — the
-- engine sees marker+toggle on the same ordered reliable channel and cycles -1.
-- ---------------------------------------------------------------------------
local function sendDecrement(cell)
    local t = nil
    pcall(function() t = cell.BindedSuitability end)
    if type(t) ~= "number" or t <= 0 or t > WORK_MAX then return end

    local row = rowOfCell(cell)
    if not row then return end
    local rname = S.fullNameOf(row)
    if not rname then return end
    local raw = resolveRaw(rname)
    if not raw then return end

    -- MUST be our own component: the engine keys its modded-client marking on the
    -- arrival component, and a wrong one downgrades this toggle to the vanilla
    -- release path (see getOwnBaseCampComp).
    local comp = getOwnBaseCampComp()
    if not alive(comp) then
        logOnce("rclick-comp", "right-click: no base-camp network component resolvable")
        return
    end
    local ok, err = pcall(function()
        comp:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 }, FName("PrioMod_Dir"), -1)
        -- uiInternal keeps the attestation path from stacking a +1 marker on top
        -- of the -1 we just sent.
        uiInternal = true
        comp:RequestChangeWorkSuitability_ToServer(
            { PlayerUId = raw.PlayerUId, InstanceId = raw.InstanceId, DebugName = "" },
            t, false) -- bOn is ignored by the engine's cycle logic
        uiInternal = false
    end)
    uiInternal = false -- ensure cleared even if the call threw
    if not ok then logOnce("rclick-send", "right-click send failed: " .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Exports (main.lua owns the loop, the keybinds and the shared hooks).
-- ---------------------------------------------------------------------------

-- Per-session state only. bindHooked STAYS true: UE4SS cannot unregister a hook,
-- so the registration outlives every session in this process.
function U.reset()
    rowKeyCache = {}
    synced = { pals = {} }
    syncReceived = false
    syncLogs = 0
    invalidateCells()
    injected = {}
    lastText = {}
    origCbVis = {}
    cbGen = {}
    lastVisSweepAt = -math.huge
    ownCompCache = nil
    ownCompFallback = false
    lastFallbackAt = -math.huge
    menuRef = nil
    menuLikelyOpen = false
    lastPingAt = -math.huge
    firstPingAt = nil
    bindCaptures = 0
    uiInternal = false
end

-- Game thread (main.lua calls this from its bootstrap tick), which tryHookBind
-- requires for LoadAsset.
function U.activate()
    local resolved, found = resolveConfigPath()
    CONFIG_PATH = resolved
    local cfg, lerr = loadConfig(CONFIG_PATH)
    if cfg then
        config = cfg
        local n = 0
        for _ in pairs(config.pals) do n = n + 1 end
        log(string.format("interface: config bootstrap %s (%s) — %d pal(s)",
            CONFIG_PATH, found and "found" or "NOT on disk", n))
    else
        config = { pals = {} }
        log("interface: config bootstrap failed (" .. tostring(lerr)
            .. ") — retrying each poll; the sync channel is the real source")
    end
    lastHookTry = os.clock()
    tryHookBind()
end

-- PURE LUA — no game calls. main.lua uses this to decide whether to hop to the
-- game thread at all, so a wrong `true` costs every idle client a hop.
function U.wantsTick()
    if not bindHooked then
        return (os.clock() - lastHookTry) >= HOOK_RETRY_SEC
    end
    return menuLikelyOpen
end

function U.tick()
    -- main.lua ticks us whenever ANYTHING is due, so re-check our own gate.
    if not U.wantsTick() then return end

    -- Nothing can render without the row->pal mapping, so until the hook takes,
    -- retry slowly and skip the rest of the tick entirely.
    if not bindHooked then
        lastHookTry = os.clock()
        tryHookBind()
        return
    end

    logOnce("alive-hop", "interface: poll loop game-thread hop alive")

    -- Only work while the vanilla screen is actually showing. When it is not,
    -- drop the open-flag so we go back to zero-cost idle until the next
    -- BindFromSlot fires.
    if not menuIsShowing() then
        menuLikelyOpen = false
        return
    end

    -- Re-ping every 60s while the screen is up: the engine marks this client's
    -- component as modded with a 600s TTL, and each ping also triggers a full
    -- priority re-sync. A one-shot ping let long sessions expire the TTL, which
    -- downgraded the next click to the vanilla release path. The timestamp
    -- advances only on a successful send, so a failure just retries next tick.
    if os.clock() - lastPingAt >= 60 then
        pcall(function()
            local comp = getOwnBaseCampComp()
            if alive(comp) then
                comp:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 },
                    FName("PrioMod_Ping"), 1)
                lastPingAt = os.clock()
                if firstPingAt == nil then firstPingAt = os.clock() end
                logOnce("ping-sent",
                    "interface: announced to server (PrioMod_Ping) — awaiting sync reply")
            else
                logOnce("ping-nocomp",
                    "interface: cannot announce — no base-camp network component resolvable yet (will keep trying)")
            end
        end)
    end

    if firstPingAt ~= nil and not syncReceived
        and os.clock() - firstPingAt > 15 then
        logOnce("no-sync-reply",
            "no sync reply from server 15s after announcing — server engine missing, older than 1.1.0, or not receiving; numbers stay display-only previews")
    end

    -- Reload the file config only until the sync channel delivers: after that
    -- the file is moot, and on a host the 500ms reads can collide with saves.
    if not syncReceived then
        reloadConfig()
    end

    -- Safety net for any path that re-shows a vanilla checkbox WITHOUT a rebind.
    -- Rebinds bump visGen themselves; this just guarantees an upper bound on how
    -- long a stray checkbox could linger.
    if (os.clock() - lastVisSweepAt) >= VIS_REASSERT_SECONDS then
        lastVisSweepAt = os.clock()
        visGen = visGen + 1
    end

    -- Update every cell on screen. One bad cell must not stop the rest. A dead
    -- cached cell means the whole list is suspect, so drop it and rescan next
    -- tick instead of rendering from it.
    if cellCache == nil then
        local cells = nil
        pcall(function() cells = FindAllOf(CELL_CLASS) end)
        if not cells then return end
        cellCache = cells
    end
    for _, cell in ipairs(cellCache) do
        if not alive(cell) then
            invalidateCells()
            return
        end
        pcall(handleCellTop, cell)
    end
end

-- Click attestation. The engine only applies cycle semantics to toggles from
-- MODDED clients, so we send a PrioMod_Dir marker before every toggle this
-- client originates. main.lua calls this from the shared toggle hook (pre-hook,
-- so the marker goes first on the same ordered channel) and already filters out
-- the engine's own writes; uiInternal filters ours.
function U.onToggle(Context, TargetIndividualId, WorkSuitability, bOn)
    local c = Context:get()
    if not alive(c) then return end
    -- Ours only. On a listen server the host also runs remote players' toggles
    -- through here; marking one makes the engine read that player's vanilla
    -- click as a modded cycle.
    local isOwn, known = isOwnComp(c)
    if known and not isOwn then
        logOnce("attest-remote",
            "toggle on a component that is not ours — not attested (expected for other players on a listen server)")
        return
    end
    if not known then
        logOnce("attest-degraded",
            "own component unresolved — attesting every toggle (correct solo; a listen-server host may mark other players' clicks)")
    end
    local n = S.fullNameOf(c)
    if n and not S.isDefaultObject(n) then
        ownCompCache = c
        ownCompFallback = not known
    end
    if uiInternal then return end -- right-click already sent its marker
    c:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 }, FName("PrioMod_Dir"), 1)
end

-- Server->client priority sync. The FName carries the payload:
--   "PrioSync|<palkey>|<13 chars>"  full row for one pal; work types 1..13 in
--       order, '0'-'5' = explicit priority ('0' renders X/never), '-' = no entry.
--   "PrioDrop|<palkey>"             pal released/unconfigured; drop it.
--   "PrioReset"                     precedes a full-state batch (ping reply).
-- <palkey> CONTAINS a '-', so messages split on '|', never on '-'. Any other
-- FName passes through silently (this is the game's generic notify surface).
function U.onNotifyClient(Context, BaseCampId, FunctionName, Value)
    -- Adopt Context as OUR component only when it is ours (this fires for other
    -- players' components on a listen server). Payload parsing below is
    -- unconditional — the priority data is global, whoever it arrived for.
    pcall(function()
        -- Skip the lookup when we already hold a trusted comp; an untrusted
        -- (fallback) one still self-heals here.
        if alive(ownCompCache) and not ownCompFallback then return end
        local c = Context:get()
        if not alive(c) then return end
        local isOwn, known = isOwnComp(c)
        if known and not isOwn then return end
        local n = S.fullNameOf(c)
        if n and not S.isDefaultObject(n) then
            ownCompCache = c
            ownCompFallback = not known
        end
    end)

    local name = nil
    pcall(function() name = S.fstr(FunctionName:get()) end)
    if type(name) ~= "string" then return end
    local parsed = false
    if name:sub(1, 9) == "PrioSync|" then
        local key, rowStr = name:match("^PrioSync|([^|]+)|(.+)$")
        if key and rowStr and #rowStr == 13 then
            local entry = { prio = {} }
            for t = 1, 13 do
                local ch = rowStr:sub(t, t)
                if ch >= "0" and ch <= "5" then
                    entry.prio[t] = tonumber(ch)
                end
                -- '-' (or anything else): no entry -> cell blank
            end
            synced.pals[key] = entry
            parsed = true
        end
    elseif name:sub(1, 9) == "PrioDrop|" then
        local key = name:sub(10)
        if #key > 0 then
            synced.pals[key] = nil
            parsed = true
        end
    elseif name == "PrioReset" then
        -- Precedes a full-state batch: forget pals released while we were
        -- disconnected. Deliberately not `parsed` — a lone reset must not latch
        -- syncReceived and blank the display.
        synced.pals = {}
        logOnce("sync-reset", "interface: PrioReset — cleared cached pal state before resync")
    end
    if parsed then
        syncReceived = true
        if syncLogs < 5 then
            syncLogs = syncLogs + 1
            log(string.format("interface: sync #%d: %s", syncLogs, name))
        end
    end
end

function U.onRightClick()
    -- Fast bail on a plain Lua flag when the work screen isn't up, so gameplay
    -- right-clicks (aiming etc.) cost nothing.
    if not menuLikelyOpen then return end

    -- The poll tick already holds the cell list for this screen (it refreshed at
    -- most 500ms ago and drops the cache the moment a cell dies), so a click no
    -- longer costs an object-array walk. Only a click that beats the first tick
    -- after the screen opened falls through to one.
    local cells = cellCache
    if cells == nil then
        pcall(function() cells = FindAllOf(CELL_CLASS) end)
    end
    if not cells then return end
    for _, cell in ipairs(cells) do
        local hovered = false
        pcall(function()
            if alive(cell) then hovered = cell:IsHovered() end
        end)
        if hovered == true then
            sendDecrement(cell)
            return -- exactly one cell can be hovered
        end
    end
end

-- Dev diagnostic (F10 in main.lua, DEBUG builds): walk the display path for the
-- first few cells and report exactly where it stops.
function U.diagnostic()
    log("=== interface diag ===")
    log("config path=" .. CONFIG_PATH)
    local n = 0
    for _ in pairs(config.pals) do n = n + 1 end
    local rows = 0
    for _ in pairs(rowKeyCache) do rows = rows + 1 end
    log(string.format("config pals=%d ftextMethod=%s bindHooked=%s cachedRows=%d syncReceived=%s",
        n, tostring(ftextMethod), tostring(bindHooked), rows, tostring(syncReceived)))

    local menus = nil
    pcall(function() menus = FindAllOf(MENU_CLASS) end)
    log("menus found: " .. tostring(menus and #menus or 0))

    local cells = nil
    pcall(function() cells = FindAllOf(CELL_CLASS) end)
    log("cells found: " .. tostring(cells and #cells or 0))
    if not cells then log("=== end diag ===") return end

    local shown = 0
    for _, cell in ipairs(cells) do
        if shown >= 3 then break end
        local okc, errc = pcall(function()
            if not alive(cell) then return end
            local cname = S.fullNameOf(cell)
            if not cname or S.isDefaultObject(cname) then return end
            local battle = nil
            pcall(function() battle = cell.IsBattleSettingMode end)
            if battle == true then return end
            shown = shown + 1

            local t = nil
            pcall(function() t = cell.BindedSuitability end)

            -- The slate-parent chain: a failed row resolution shows exactly what
            -- sits between the cell and its row.
            local chain = {}
            local node = nil
            pcall(function() node = cell:GetParent() end)
            for _ = 1, 5 do
                if not alive(node) then break end
                chain[#chain + 1] = S.classNameOf(node) or "?"
                if S.classNameOf(node) == ROW_CLASS then break end
                local outer = nil
                pcall(function() outer = node:GetOuter() end)
                node = outer
            end
            log(string.format("cell#%d suit=%s parent chain: %s",
                shown, tostring(t), table.concat(chain, " > ")))

            local row = rowOfCell(cell)
            log("  row: " .. (row and "FOUND" or "NOT FOUND"))
            if not row then return end

            local rname = S.fullNameOf(row)
            local key = rname and resolveKey(rname) or nil
            log("  key: " .. tostring(key) ..
                (key and (activeEntry(key) and " (configured)" or " (unconfigured)") or ""))
            if not key then return end

            local target, isOverlay, tree = findInsertTarget(cell)
            log(string.format("  insert target=%s overlay=%s tree=%s",
                target and (S.classNameOf(target) or "?") or "NONE",
                tostring(isOverlay), tostring(tree ~= nil)))

            local tb = ensureTextBlock(cell, cname)
            log("  textblock: " .. (tb and "OK" or "FAILED"))
            if tb then
                setText(tb, cname, "9")
                log("  test text '9' set — check the screen")
            end
        end)
        if not okc then log("cell diag error: " .. tostring(errc)) end
    end
    log("=== end diag ===")
end

return U
