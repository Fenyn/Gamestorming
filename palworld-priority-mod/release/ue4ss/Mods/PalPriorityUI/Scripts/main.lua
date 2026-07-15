-- ============================================================================
-- PalPriorityUI — client-side DISPLAY mod for PalPriority.
-- UE4SS (Okaetsu fork) Lua mod. Palworld 1.0.
--
-- WHAT IT DOES
--   Renders each work-suitability cell's priority number (1-5) directly on the
--   vanilla "Work Suitability Preference" screen. Pure display: no click handling,
--   no RPCs, no writes. It READS the same priorities.lua that the server engine
--   (PalPriority) writes — in single-player / on the host these live in the same
--   process and the same files, so we resolve the ENGINE's config path.
--
--   A configured pal shows its priority number on each work type (blank when the
--   priority is 0, so the vanilla unchecked 'X' shows through). Unconfigured pals
--   are left untouched.
--
-- SAFETY
--   This poll loop touches live UI widgets every 500ms. A Lua error on the game
--   thread crashes the game, so EVERY game-object access is pcall-wrapped and the
--   whole screen must survive any single failing cell. Degraded paths log once,
--   never in a loop. A cell that fails is simply skipped this tick.
-- ============================================================================

local VERSION = "0.9.0"

local function log(msg)
    print(string.format("[PalPriorityUI] %s\n", msg))
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
-- Known BP class names (must include the _C suffix for FindAllOf — verified:
-- without _C, FindAllOf finds nothing for Blueprint-generated classes).
-- ---------------------------------------------------------------------------
local MENU_CLASS = "WBP_WorkSuitabilityPreferenceMenu_C"
local CELL_CLASS = "WBP_WorkSuitabilityPreference_CheckBox_0_C"
-- Game's own typo "Worl" (not "Work") — keep it exactly, it is the real class name.
local ROW_CLASS  = "WBP_WorlSuitabilityPreference_PalList_C"
local WORK_MAX   = 13 -- highest valid EPalWorkSuitability value

-- DEBUG: enables the dev diagnostics (F10 UI pipeline dump). Ships false in
-- release; flip to true when the overlay misbehaves after a game patch.
local DEBUG = false

-- ---------------------------------------------------------------------------
-- Pal-key helpers — MUST match the engine's exactly, or keys won't line up with
-- what the engine wrote into priorities.lua.
-- ---------------------------------------------------------------------------

-- FGuid int32 fields come back sign-extended; mask to unsigned 32-bit so the same
-- pal always produces the same key. Lua '%' follows the divisor's sign.
local function norm(v)
    return v % 0x100000000
end

-- Canonical, session-stable pal key: two 32-hex-char halves joined by '-'.
local function palKey(playerUId, instanceId)
    return string.format("%08X%08X%08X%08X-%08X%08X%08X%08X",
        norm(playerUId.A), norm(playerUId.B), norm(playerUId.C), norm(playerUId.D),
        norm(instanceId.A), norm(instanceId.B), norm(instanceId.C), norm(instanceId.D))
end

-- Class-name of a UObject, or nil. Central pcall choke-point for the many places
-- that identify a widget/row/panel by its class name.
local function classNameOf(obj)
    local name = nil
    pcall(function() name = obj:GetClass():GetFName():ToString() end)
    return name
end

-- CRASH-CRITICAL: UE4SS returns a WRAPPER object (not nil) for null UObject
-- properties, and pcall CANNOT catch the native access violation that calling a
-- method on a null/stale wrapper causes (learned from a live crash: AV reading
-- 0x10 inside the Lua member-function invoker). So before ANY member call on ANY
-- object we received, require IsValid() to affirmatively return true. IsValid()
-- itself is safe on null/stale wrappers (it checks the engine's object array).
local function alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

-- ---------------------------------------------------------------------------
-- Config load (READ-ONLY) — same parsing as the engine's loadConfig.
-- ---------------------------------------------------------------------------
local config = { pals = {} } -- last good config; kept on any reload failure
local CONFIG_PATH = "Mods/PalPriority/priorities.lua"

-- Parse + validate the engine's config file. Returns (table) or (nil, errmsg).
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

-- Resolve the ENGINE's config path (Mods/PalPriority/..., NOT PalPriorityUI). We
-- read what the engine writes. Same candidate strategy as the engine so cwd
-- differences don't matter. Returns (path, foundOnDisk).
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

-- Reload the config; on any failure keep the last good copy (silent — the file is
-- rewritten atomically by the engine, so a transient mid-write read just retries).
local function reloadConfig()
    local cfg = loadConfig(CONFIG_PATH)
    if cfg then config = cfg end
end

-- ---------------------------------------------------------------------------
-- Per-cell caches (keyed by cell:GetFullName()).
-- ---------------------------------------------------------------------------
local injected = {}     -- cellFullName -> injected TextBlock widget
local lastText = {}     -- cellFullName -> last string we SetText'd (avoid churn)
local origCbVis = {}    -- cellFullName -> the PalCheckBox's original visibility (for restore)
local ftextMethod = nil -- "direct" | "kismet" — which FText build path works here
local kismetLib = nil   -- cached Default__KismetTextLibrary for the fallback path

-- ---------------------------------------------------------------------------
-- FText construction. UE4SS 3.x usually has FText(str); some builds need the
-- KismetTextLibrary conversion. Probe once, then cache the working method.
-- ---------------------------------------------------------------------------
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

    -- First call: probe. Prefer the direct constructor.
    local ft = nil
    local ok = pcall(function() ft = FText(str) end)
    if ok and ft ~= nil then
        ftextMethod = "direct"
        return ft
    end

    -- Fallback: KismetTextLibrary::Conv_StringToText.
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

-- Set a cell's overlay text (and its matching color), only through the
-- changed-value gate below — the caller compares against lastText first, so we
-- don't rebuild an FText or restyle every 500ms.
local function setText(tb, cellName, str)
    local ft = makeFText(str)
    if ft == nil then return end
    local ok = pcall(function() tb:SetText(ft) end)
    if ok then
        lastText[cellName] = str
        local c = PRIO_COLORS[str]
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
        if classNameOf(node) == ROW_CLASS then return node end
        local outer = nil
        pcall(function() outer = node:GetOuter() end)
        if not alive(outer) then return nil end
        node = outer
    end
    return nil
end

-- CRASH-CRITICAL #2 (from a second live crash): merely READING the row's
-- `bindedSlot` SoftObjectProperty crashes natively inside UE4SS
-- (push_softobjectproperty -> FString::operator= AV) — the crash is in the
-- property read itself, before Lua sees anything, so alive()/pcall cannot help.
-- NEVER read bindedSlot. Instead: the row's BindFromSlot is a BLUEPRINT function
-- (always executes via the hookable reflection layer); hook it and capture the
-- row -> pal-key mapping at bind time, with the slot arriving as a safe hook arg.
local rowKeyCache = {} -- rowFullName -> palKey (rows are recycled; rebind overwrites)
local bindHooked = false
local bindCaptures = 0
-- Screen-open signal. BindFromSlot fires on every screen open/rebind (verified),
-- so it doubles as our "the work screen is (probably) up" flag. While false, the
-- poll loop and the right-click handler bail on a plain Lua read — zero game
-- calls, no game-thread hop — which is the whole idle cost of this mod.
local menuLikelyOpen = false
local menuRef = nil -- cached menu widget while open (avoids FindAllOf per tick)
local uiInternal = false -- true while WE call the toggle RPC (right-click path)
local helloSent = false  -- PrioMod_Ping announced this session

local ROW_BP_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/WorkSuitabilityPreference/WBP_WorlSuitabilityPreference_PalList.WBP_WorlSuitabilityPreference_PalList_C"
local ROW_BIND_FN = ROW_BP_CLASS .. ":BindFromSlot"

-- BP classes load on demand, so hook registration fails until the class exists —
-- and rows bound BEFORE registration are never captured. Force-load the class
-- eagerly with LoadAsset so the hook is in place before the screen first opens.
local function tryHookBind()
    if bindHooked then return end
    -- Eager class load; harmless no-op once loaded. pcall: LoadAsset may not
    -- exist on every UE4SS build, and must run on the game thread (we are).
    pcall(function() LoadAsset(ROW_BP_CLASS) end)
    local ok = pcall(function()
        RegisterHook(ROW_BIND_FN, function(Context, SlotParam)
            pcall(function()
                local row = Context:get()
                if not alive(row) then return end
                local rname = row:GetFullName()
                local slot = SlotParam:get()
                if not alive(slot) then return end
                local handle = slot.Handle
                if not alive(handle) then return end
                local id = handle:GetIndividualID()
                if id == nil then return end
                local okk, key = pcall(function()
                    return palKey(id.PlayerUId, id.InstanceId)
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
                    bindCaptures = bindCaptures + 1
                    -- Log the first few captures so a live session shows the
                    -- mapping actually happening (then go quiet).
                    if bindCaptures <= 5 then
                        log(string.format("bind capture #%d: %s", bindCaptures, key))
                    end
                end
            end)
        end)
    end)
    if ok then
        bindHooked = true
        log("BindFromSlot hook registered — row->pal mapping active")
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

    if classNameOf(root) == "Overlay" then
        return root, true, tree
    end

    -- Breadth-first scan for an Overlay, capped so a pathological tree can't spin.
    local queue = { root }
    local visited = 0
    while #queue > 0 and visited < 20 do
        local node = table.remove(queue, 1)
        visited = visited + 1
        if classNameOf(node) == "Overlay" then
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

    -- No Overlay found: fall back to the root widget (caller tries AddChild).
    return root, false, tree
end

-- Insert the text block as a SIBLING of the hidden PalCheckBox in the SAME
-- parent panel, copying its slot geometry — identical placement by construction.
-- The cell's internals are canvas-style (absolute layout: slot mirror of
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

    local slotCls = classNameOf(cbSlot) or ""
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
    logOnce("injectmode", "number placement: checkbox-sibling (" .. slotCls .. ")")
    return true
end

-- Verify a cached widget is still live. STRICT: only IsValid()==true counts.
-- (An earlier version fell back to probing GetVisibility() when IsValid was
-- unavailable — that probe itself can be a native crash on a stale wrapper.)
local function widgetStillValid(tb)
    return alive(tb)
end

-- Ensure a TextBlock overlay exists on this cell; returns it or nil. Cached by
-- cellName; stale/invalid caches are dropped and re-injected. Never throws.
local function ensureTextBlock(cell, cellName)
    local cached = injected[cellName]
    if cached then
        if widgetStillValid(cached) then return cached end
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
        -- Fallback: previous overlay/root insertion, centered (may be offset).
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
                logOnce("injectmode", "number placement: overlay fallback (may be offset)")
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
-- Handle one cell belonging to a row whose config entry is `entry` (may be nil
-- for an unconfigured pal).
local function handleCell(cell, entry)
    -- Cell must be affirmatively alive (widgets can be mid-teardown between
    -- polls), and never touch class defaults.
    if not alive(cell) then return end
    local cellName = nil
    pcall(function() cellName = cell:GetFullName() end)
    if not cellName or cellName:find("Default__", 1, true) then return end

    -- Skip the battle-suitability checkbox variant entirely.
    local battle = false
    pcall(function() battle = cell.IsBattleSettingMode end)
    if battle == true then return end

    -- Work type (EPalWorkSuitability). 0 or out of range -> not a work cell we show.
    local t = nil
    pcall(function() t = cell.BindedSuitability end)
    if type(t) ~= "number" or t <= 0 or t > WORK_MAX then return end

    -- Look up this pal + work type's priority. nil => pal not configured for it.
    local prio = nil
    if entry and entry.prio then prio = entry.prio[t] end

    if prio == nil then
        -- Unconfigured pal: we don't manage it. Clear a previously-injected overlay
        -- and restore the vanilla checkbox if we ever hid it (pal lost its config).
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
        end
        return
    end

    -- Configured: the vanilla check must not show at all — the number IS the state.
    -- Hide the PalCheckBox (Hidden=2 keeps its layout space so the grid doesn't
    -- shift) every tick, because the vanilla row refresh can re-show it. Remember
    -- its original visibility once, for restore if the pal is ever unconfigured.
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

    -- Ensure the overlay exists, then show the number, or "X" when disabled (0).
    local tb = ensureTextBlock(cell, cellName)
    if not tb then return end

    local desired = (prio > 0) and tostring(prio) or "X"
    if lastText[cellName] ~= desired then
        setText(tb, cellName, desired)
    end
end

-- Handle one cell top-to-bottom: find its row via the slate-parent chain, its
-- pal via the bind-time cache, then render. Cells whose row/key can't resolve
-- are skipped entirely (never cleared — we may just be mid-bind).
local function handleCellTop(cell)
    if not alive(cell) then return end

    local row = rowOfCell(cell)
    if not row then return end
    local rowName = nil
    pcall(function() rowName = row:GetFullName() end)
    if not rowName then return end

    local key = resolveKey(rowName)
    if not key then return end

    handleCell(cell, config.pals[key])
end

-- ---------------------------------------------------------------------------
-- Poll tick. Runs ON the game thread (via ExecuteInGameThread).
-- ---------------------------------------------------------------------------
-- Is the work screen actually showing? Fast path: the cached menu widget is
-- alive AND visible. Cache miss: rescan — multiple menu instances coexist
-- (seen live: a hidden/stale one alongside the open one), so we must cache a
-- VISIBLE instance, never just the first alive one. IsVisible failing to call
-- counts as visible (fall back to pre-optimization behavior, don't go dark).
local function isShowing(m)
    local okv, vis = pcall(function() return m:IsVisible() end)
    if not okv then return true end
    return vis == true
end

local function menuIsShowing()
    if alive(menuRef) and isShowing(menuRef) then return true end
    menuRef = nil
    local menus = nil
    pcall(function() menus = FindAllOf(MENU_CLASS) end)
    if not menus then return false end
    for _, m in ipairs(menus) do
        if alive(m) then
            local mname = nil
            pcall(function() mname = m:GetFullName() end)
            if mname and not mname:find("Default__", 1, true) and isShowing(m) then
                menuRef = m
                return true
            end
        end
    end
    return false
end

local function tickBody()
    -- Heartbeat: proves game-thread hops still process for this mod.
    logOnce("alive-hop", "poll loop game-thread hop alive")

    -- 0. Keep trying to register the BindFromSlot hook until the BP class loads.
    tryHookBind()

    -- 1. Only do work while the vanilla screen is actually showing. When it is
    -- not, drop the open-flag so the loop goes back to zero-cost idle until the
    -- next BindFromSlot fires.
    if not menuIsShowing() then
        menuLikelyOpen = false
        return
    end

    -- Announce ourselves once per session (marks this client's component as
    -- modded server-side even before the first click).
    if not helloSent then
        pcall(function()
            local comp = FindFirstOf("PalNetworkBaseCampComponent")
            if alive(comp) then
                comp:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 },
                    FName("PrioMod_Ping"), 1)
                helloSent = true
            end
        end)
    end

    -- 2. Reload the engine's config (small file; keeps last good on failure).
    reloadConfig()

    -- 3. Update every cell on screen (cell -> slate-parent chain -> row -> pal).
    -- One bad cell must not stop the rest.
    local cells = nil
    pcall(function() cells = FindAllOf(CELL_CLASS) end)
    if not cells then return end
    for _, cell in ipairs(cells) do
        pcall(handleCellTop, cell)
    end
end

-- ---------------------------------------------------------------------------
-- Click attestation. The server engine only applies cycle semantics to toggles
-- from MODDED clients — everyone else's vanilla checkboxes bypass the mod. We
-- attest by sending a PrioMod_Dir marker before every toggle this client
-- originates: left-clicks are caught by hooking the toggle RPC client-side
-- (pre-hook runs before the call transmits, so the marker goes first on the
-- same ordered channel); the right-click path sends its own -1 marker and sets
-- uiInternal so this hook doesn't stack a +1 on top of it.
-- ---------------------------------------------------------------------------
pcall(function()
    local ok, err = pcall(function()
        RegisterHook("/Script/Pal.PalNetworkBaseCampComponent:RequestChangeWorkSuitability_ToServer",
            function(Context, TargetIndividualId, WorkSuitability, bOn)
                if uiInternal then return end -- right-click already sent its marker
                pcall(function()
                    local c = Context:get()
                    if alive(c) then
                        c:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 },
                            FName("PrioMod_Dir"), 1)
                    end
                end)
            end)
    end)
    log(ok and "HOOK OK toggle attestation (left-click marker)"
        or ("HOOK FAILED toggle attestation: " .. tostring(err)))
end)

-- ---------------------------------------------------------------------------
-- Right-click decrement. A right-mouse keybind that acts only when the work
-- screen is open AND the pointer is over a work cell (IsHovered). It sends a
-- PrioMod_Dir=-1 marker through the custom transport, then the same vanilla
-- toggle RPC a left-click produces — the engine sees marker+toggle on the same
-- ordered reliable channel and cycles -1 instead of +1.
-- ---------------------------------------------------------------------------
local function sendDecrement(cell)
    local t = nil
    pcall(function() t = cell.BindedSuitability end)
    if type(t) ~= "number" or t <= 0 or t > WORK_MAX then return end

    local row = rowOfCell(cell)
    if not row then return end
    local rname = nil
    pcall(function() rname = row:GetFullName() end)
    if not rname then return end
    local raw = resolveRaw(rname)
    if not raw then return end

    local comp = FindFirstOf("PalNetworkBaseCampComponent")
    if not alive(comp) then
        logOnce("rclick-comp", "right-click: no PalNetworkBaseCampComponent found")
        return
    end
    local ok, err = pcall(function()
        comp:Request_Server_int32({ A = 0, B = 0, C = 0, D = 0 }, FName("PrioMod_Dir"), -1)
        -- uiInternal keeps the attestation hook from stacking a +1 marker on
        -- top of the -1 we just sent.
        uiInternal = true
        comp:RequestChangeWorkSuitability_ToServer(
            { PlayerUId = raw.PlayerUId, InstanceId = raw.InstanceId, DebugName = "" },
            t, false) -- bOn is ignored by the engine's cycle logic
        uiInternal = false
    end)
    uiInternal = false -- ensure cleared even if the call threw
    if not ok then logOnce("rclick-send", "right-click send failed: " .. tostring(err)) end
end

pcall(function()
    local rmb = Key.RIGHT_MOUSE_BUTTON
    if rmb == nil then
        log("Key.RIGHT_MOUSE_BUTTON not available in this UE4SS build — right-click decrement disabled")
        return
    end
    RegisterKeyBind(rmb, function()
        local ok, err = pcall(function()
            -- Fast bail on a plain Lua flag when the work screen isn't up, so
            -- gameplay right-clicks (aiming etc.) cost literally nothing.
            if not menuLikelyOpen then return end

            local cells = nil
            pcall(function() cells = FindAllOf(CELL_CLASS) end)
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
        end)
        if not ok then logOnce("rclick", "right-click handler error: " .. tostring(err)) end
    end)
    log("right-click decrement bound")
end)

-- ---------------------------------------------------------------------------
-- F10 diagnostic: verbosely walk the display path for the first few cells and
-- report exactly where it stops. Pure logging — the fastest way to find which
-- silent skip is eating the overlay when numbers don't render.
-- ---------------------------------------------------------------------------
pcall(function()
    if not DEBUG then return end -- dev-only diagnostic (see DEBUG flag at top)
    RegisterKeyBind(Key.F10, function()
        local ok, err = pcall(function()
            log("=== F10 DIAG ===")
            log("config path=" .. CONFIG_PATH)
            local n = 0
            for _ in pairs(config.pals) do n = n + 1 end
            log(string.format("config pals=%d ftextMethod=%s bindHooked=%s cachedRows=%d",
                n, tostring(ftextMethod), tostring(bindHooked), (function()
                    local c = 0
                    for _ in pairs(rowKeyCache) do c = c + 1 end
                    return c
                end)()))

            local menus = nil
            pcall(function() menus = FindAllOf(MENU_CLASS) end)
            log("menus found: " .. tostring(menus and #menus or 0))

            local cells = nil
            pcall(function() cells = FindAllOf(CELL_CLASS) end)
            log("cells found: " .. tostring(cells and #cells or 0))
            if not cells then log("=== END DIAG ===") return end

            local shown = 0
            for _, cell in ipairs(cells) do
                if shown >= 3 then break end
                local okc, errc = pcall(function()
                    if not alive(cell) then return end
                    local cname = "?"
                    pcall(function() cname = cell:GetFullName() end)
                    if cname:find("Default__", 1, true) then return end
                    local battle = nil
                    pcall(function() battle = cell.IsBattleSettingMode end)
                    if battle == true then return end
                    shown = shown + 1

                    local t = nil
                    pcall(function() t = cell.BindedSuitability end)

                    -- Show the slate-parent chain so a failed row resolution tells
                    -- us exactly what sits between the cell and its row.
                    local chain = {}
                    local node = nil
                    pcall(function() node = cell:GetParent() end)
                    for _ = 1, 5 do
                        if not alive(node) then break end
                        chain[#chain + 1] = classNameOf(node) or "?"
                        if classNameOf(node) == ROW_CLASS then break end
                        local outer = nil
                        pcall(function() outer = node:GetOuter() end)
                        node = outer
                    end
                    log(string.format("cell#%d suit=%s parent chain: %s",
                        shown, tostring(t), table.concat(chain, " > ")))

                    local row = rowOfCell(cell)
                    log("  row: " .. (row and "FOUND" or "NOT FOUND"))
                    if not row then return end

                    local rname = nil
                    pcall(function() rname = row:GetFullName() end)
                    local key = rname and resolveKey(rname) or nil
                    log("  key: " .. tostring(key) ..
                        (key and (config.pals[key] and " (configured)" or " (unconfigured)") or ""))
                    if not key then return end

                    local target, isOverlay, tree = findInsertTarget(cell)
                    log(string.format("  insert target=%s overlay=%s tree=%s",
                        target and (classNameOf(target) or "?") or "NONE",
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
            log("=== END DIAG ===")
        end)
        if not ok then log("F10 error: " .. tostring(err)) end
    end)
end)

-- ---------------------------------------------------------------------------
-- Poll loop. LoopAsync runs OFF the game thread, so hop game access onto the game
-- thread via ExecuteInGameThread. Return false to keep looping (UE4SS convention).
-- ---------------------------------------------------------------------------
pcall(function()
    LoopAsync(500, function()
        -- Heartbeat: proves this mod's async thread + queue survived startup.
        logOnce("alive-thread", "poll loop thread alive")
        local ok, err = pcall(function()
            -- Zero-cost idle: while the hook is registered and no screen-open
            -- signal has fired, don't even hop to the game thread. (Before the
            -- hook registers we must hop — tryHookBind needs the game thread.)
            if bindHooked and not menuLikelyOpen then return end
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
-- Startup: resolve + load the engine's config, report state.
-- ---------------------------------------------------------------------------
do
    local resolved, found = resolveConfigPath()
    CONFIG_PATH = resolved
    log(string.format("engine config path: %s (%s)", CONFIG_PATH, found and "found" or "NOT found on disk"))

    local cfg, lerr = loadConfig(CONFIG_PATH)
    if cfg then
        config = cfg
        local n = 0
        for _ in pairs(config.pals) do n = n + 1 end
        log(string.format("config loaded: %d pal(s) configured", n))
    else
        config = { pals = {} }
        log("config load failed (" .. tostring(lerr) .. ") — will retry each poll")
    end
end

-- First hook attempt. Mod startup runs OFF the game thread, and LoadAsset (used
-- inside tryHookBind) is game-thread-only — so hop, same as the poll loop does.
pcall(function()
    ExecuteInGameThread(function()
        pcall(tryHookBind)
    end)
end)

log(string.format("v%s ready. Poll 500ms; display-only overlay.", VERSION))
