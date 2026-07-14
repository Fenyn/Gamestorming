-- PrioProbe v4: workstation "look-at" UI discovery for the force-job feature.
-- Stand at a workstation with an ACTIVE job (queue something at a bench), look
-- at it so the vanilla job info shows, then press F7. Dumps every live
-- work-related widget: class functions/properties + one instance's values,
-- hunting for the property that references the work object / work id.

local function log(msg)
    print(string.format("[PrioProbe] %s\n", msg))
end

local function alive(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

local function classNameOf(obj)
    local name = nil
    pcall(function() name = obj:GetClass():GetFName():ToString() end)
    return name
end

log("v4 (workstation UI dump) loading...")

-- Class-name substrings that mark a widget as work/station related.
local PATTERNS = { "PalWork", "WorkerInfo", "AccessPoint", "CampInfo", "Monitoring_Work" }

local function isTarget(cls)
    for _, p in ipairs(PATTERNS) do
        if cls:find(p, 1, true) then return true end
    end
    return false
end

local function dumpClass(cls)
    local name = cls:GetFName():ToString()
    log("== CLASS " .. name .. " ==")
    pcall(function()
        cls:ForEachFunction(function(fn)
            pcall(function() log("  FUNC " .. fn:GetFName():ToString()) end)
        end)
    end)
    pcall(function()
        cls:ForEachProperty(function(prop)
            pcall(function()
                log(string.format("  PROP %s : %s",
                    prop:GetFName():ToString(), prop:GetClass():GetFName():ToString()))
            end)
        end)
    end)
end

-- Dump one live instance: simple values, object-ref classes, struct guesses.
-- NEVER read SoftObjectProperty values (native crash — crash rule #2); the
-- class dump above already tells us where soft refs are by property TYPE.
local function dumpInstance(inst, softProps)
    log("== INSTANCE " .. inst:GetFullName() .. " ==")
    local vis = "?"
    pcall(function() vis = tostring(inst:IsVisible()) end)
    log("  visible=" .. vis)
    pcall(function()
        inst:GetClass():ForEachProperty(function(prop)
            pcall(function()
                local pname = prop:GetFName():ToString()
                if softProps[pname] then
                    log("  SOFT " .. pname .. " (skipped: unsafe to read)")
                    return
                end
                local v = inst[pname]
                local tv = type(v)
                if tv == "number" or tv == "boolean" or tv == "string" then
                    log(string.format("  VAL %s = %s", pname, tostring(v)))
                elseif tv == "userdata" then
                    local cls = nil
                    pcall(function() cls = v:GetClass():GetFName():ToString() end)
                    if cls then
                        log(string.format("  REF %s -> %s", pname, cls))
                    else
                        -- Struct wrapper (e.g. FGuid): try reading GUID-ish fields.
                        local a = nil
                        pcall(function() a = v.A end)
                        if type(a) == "number" then
                            local b, c, d = 0, 0, 0
                            pcall(function() b = v.B end)
                            pcall(function() c = v.C end)
                            pcall(function() d = v.D end)
                            log(string.format("  GUID? %s = %08X-%08X-%08X-%08X",
                                pname, a % 0x100000000, b % 0x100000000,
                                c % 0x100000000, d % 0x100000000))
                        else
                            log("  STRUCT " .. pname)
                        end
                    end
                end
            end)
        end)
    end)
end

pcall(function()
    RegisterKeyBind(Key.F7, function()
        local ok, err = pcall(function()
            local widgets = FindAllOf("UserWidget")
            if not widgets then log("no widgets") return end
            local dumpedClass = {}
            local found = 0
            for _, w in ipairs(widgets) do
                pcall(function()
                    if not alive(w) then return end
                    local cls = classNameOf(w)
                    if not cls or not isTarget(cls) then return end
                    local fname = w:GetFullName()
                    if fname:find("Default__", 1, true) then return end
                    found = found + 1
                    if not dumpedClass[cls] then
                        dumpedClass[cls] = {}
                        local c = w:GetClass()
                        -- Record soft-object property names so the instance dump
                        -- can skip them (reading one crashes natively).
                        pcall(function()
                            c:ForEachProperty(function(prop)
                                pcall(function()
                                    if prop:GetClass():GetFName():ToString() == "SoftObjectProperty" then
                                        dumpedClass[cls][prop:GetFName():ToString()] = true
                                    end
                                end)
                            end)
                        end)
                        dumpClass(c)
                        dumpInstance(w, dumpedClass[cls])
                    end
                end)
            end
            log(string.format("F7 done: %d live work-related widget instances", found))
        end)
        if not ok then log("F7 error: " .. tostring(err)) end
    end)
end)

log("v4 loaded. Look at a workstation with an active job, then press F7.")
