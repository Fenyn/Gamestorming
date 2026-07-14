-- PrioProbe v3: UI structure dump for the work-suitability screen revamp.
-- Safe to run alongside PalPriority (no RPC replays, no toggle interference).
-- F7 (with the pal work screen OPEN) dumps, for each target widget class:
--   - all function names (click handlers live here)
--   - all property names + types (the work-type field lives here)
--   - for one live checkbox instance: int/enum/bool property values + widget tree

local function log(msg)
    print(string.format("[PrioProbe] %s\n", msg))
end

log("v3 (UI dump) loading...")

local TARGETS = {
    "WBP_WorkSuitabilityPreference_CheckBox_0_C",
    "WBP_WorkSuitabilityPreference_C",
    "WBP_WorkSuitabilityPreferenceMenu_C",
    "WBP_WorlSuitabilityPreference_PalList_C", -- game's own typo, intentional
}

local function dumpClass(cls)
    local name = cls:GetFName():ToString()
    log("== CLASS " .. name .. " ==")
    local okF = pcall(function()
        cls:ForEachFunction(function(fn)
            pcall(function()
                log("  FUNC " .. fn:GetFName():ToString())
            end)
        end)
    end)
    if not okF then log("  (ForEachFunction unavailable)") end
    local okP = pcall(function()
        cls:ForEachProperty(function(prop)
            pcall(function()
                log(string.format("  PROP %s : %s",
                    prop:GetFName():ToString(), prop:GetClass():GetFName():ToString()))
            end)
        end)
    end)
    if not okP then log("  (ForEachProperty unavailable)") end
end

-- Walk one instance's simple property values (ints/enums/bools) so we can spot
-- the work-type field by its value, and dump its widget child tree.
local function dumpInstance(inst)
    log("== INSTANCE " .. inst:GetFullName() .. " ==")
    pcall(function()
        inst:GetClass():ForEachProperty(function(prop)
            pcall(function()
                local pname = prop:GetFName():ToString()
                local v = inst[pname]
                local tv = type(v)
                if tv == "number" or tv == "boolean" then
                    log(string.format("  VAL %s = %s", pname, tostring(v)))
                elseif tv == "userdata" then
                    -- Widget refs: show their class so we learn the visual makeup.
                    pcall(function()
                        log(string.format("  REF %s -> %s", pname, v:GetClass():GetFName():ToString()))
                    end)
                end
            end)
        end)
    end)
end

-- Find live instances of a BP widget class. FindAllOf wants the registered
-- class name (WITH the _C suffix for blueprint-generated classes); if that
-- yields nothing, scan all UserWidgets and match by class name — the same
-- approach that worked for the session-2 widget discovery.
local function findWidgetInstances(cname)
    local insts = nil
    pcall(function() insts = FindAllOf(cname) end)
    if insts and #insts > 0 then return insts end
    local matched = {}
    pcall(function()
        local widgets = FindAllOf("UserWidget")
        if not widgets then return end
        for _, w in ipairs(widgets) do
            pcall(function()
                if w:GetClass():GetFName():ToString() == cname then
                    matched[#matched + 1] = w
                end
            end)
        end
    end)
    return matched
end

pcall(function()
    RegisterKeyBind(Key.F7, function()
        local ok, err = pcall(function()
            local dumpedInstance = false
            for _, cname in ipairs(TARGETS) do
                local insts = findWidgetInstances(cname)
                if insts and #insts > 0 then
                    dumpClass(insts[1]:GetClass())
                    -- Deep-dump one live checkbox cell only (the revamp target).
                    if cname:find("CheckBox") and not dumpedInstance then
                        dumpedInstance = true
                        dumpInstance(insts[1])
                        log(string.format("  (%d live instances of the checkbox cell)", #insts))
                    end
                else
                    log("no instances of " .. cname .. " (is the pal work screen open?)")
                end
            end
            log("F7 dump complete")
        end)
        if not ok then log("F7 error: " .. tostring(err)) end
    end)
end)

log("v3 loaded. Open the pal work screen, then press F7.")
