local _, ISC = ...
local P = ISC.pixelPerfectFuncs

local UnitName = UnitName
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerOrPetInRaid = UnitPlayerOrPetInRaid
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local CombatLog_Object_IsA = CombatLog_Object_IsA
local COMBATLOG_FILTER_HOSTILE_UNITS = COMBATLOG_FILTER_HOSTILE_UNITS

local C_Timer = {}
local timerFrame = CreateFrame("Frame")
local timers = {}
local timerCount = 0
timerFrame:Hide()

timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = timerCount, 1, -1 do
        local timer = timers[i]
        timer.remaining = timer.remaining - elapsed
        if timer.remaining <= 0 then
            timers[i] = timers[timerCount]
            timers[timerCount] = nil
            timerCount = timerCount - 1

            local callback = timer.callback
            timer.callback = nil
            callback()
        end
    end

    if timerCount == 0 then self:Hide() end
end)

function C_Timer.After(delay, callback)
    timerCount = timerCount + 1
    timers[timerCount] = {
        remaining = math.max(0.01, delay),
        callback = callback,
    }
    timerFrame:Show()
end

local function GetTheSpellInfo(spellId)
    local name, _, icon, _, _, _, castTime = GetSpellInfo(spellId)
    return name, icon or "Interface\\Icons\\INV_Misc_QuestionMark", castTime
end

local spellDescriptionTooltip = CreateFrame("GameTooltip", "ISCSpellDescriptionTooltip", UIParent, "GameTooltipTemplate")
spellDescriptionTooltip:SetFrameLevel(UIParent:GetFrameLevel() + 1)
spellDescriptionTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetTheSpellDescription(spellId)
    spellDescriptionTooltip:ClearLines()
    spellDescriptionTooltip:SetHyperlink("spell:" .. spellId)

    for i = 1, spellDescriptionTooltip:GetNumRegions() do
        local region = select(i, spellDescriptionTooltip:GetRegions())
        if region:GetObjectType() == "FontString" and select(3, region:GetTextColor()) == 0 then
            return region:GetText() or ""
        end
    end
    return ""
end

---------------------------------------------------------------------
-- debuff type color
---------------------------------------------------------------------
local DebuffTypeColor = {
    -- ["Bleed"] = {1, 0.2, 0.6},
    ["Disease"] = {0.6, 0.4, 0},
    ["Poison"] = {0, 0.6, 0},
    ["Curse"] = {0.6, 0, 1},
    ["Magic"] = {0.2, 0.6, 1},
}

---------------------------------------------------------------------
-- InstanceSpellCollectorFrame
---------------------------------------------------------------------
local currentInstanceName, currentInstanceID
local currentEncounterID, currentEncounterName = "* ", nil
local AddCurrentInstance, LoadInstances, LoadEnemies, LoadAuras, LoadCasts, Export, NpcsToString, AurasToString, CastsToString
local RegisterEvents, UnregisterEvents

local collectorFrame = CreateFrame("Frame", "InstanceSpellCollectorFrame", UIParent)
collectorFrame:Hide()

collectorFrame:SetSize(825, 419)
collectorFrame:SetPoint("CENTER")
collectorFrame:SetFrameStrata("HIGH")
collectorFrame:SetFrameLevel(UIParent:GetFrameLevel() + 1)
collectorFrame:SetMovable(true)
collectorFrame:SetUserPlaced(true)
collectorFrame:SetClampedToScreen(true)
collectorFrame:SetClampRectInsets(0, 0, 0, 0)
-- tinsert(UISpecialFrames, "InstanceSpellCollectorFrame")

collectorFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
collectorFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
collectorFrame:SetBackdropBorderColor(0, 0, 0, 1)

collectorFrame:EnableMouse(true)
collectorFrame:RegisterForDrag("LeftButton")
collectorFrame:SetScript("OnDragStart", function()
    collectorFrame:StartMoving()
end)
collectorFrame:SetScript("OnDragStop", function()
    collectorFrame:StopMovingOrSizing()
    P:PixelPerfectPoint(collectorFrame)
end)

-- title
local title = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_TITLE")
title:SetPoint("TOP", 0, -3)
title:SetText("Instance Spell Collector")
title:SetTextColor(1, 0.19, 0.19)

local init
collectorFrame:SetScript("OnShow", function()
    if not init then
        init = true
        LoadInstances()
    end
    P:PixelPerfectPoint(collectorFrame)
    title:SetText("Instance Spell Collector |cffc0c0c0" .. ISC.version .. "|r")
end)
-- collectorFrame:SetScript("OnHide", function()
--     ISCTooltip:Hide()
-- end)

local instanceIDText = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
instanceIDText:SetPoint("TOPLEFT", 5, -25)

local instanceNameText = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
instanceNameText:SetPoint("LEFT", instanceIDText, "RIGHT", 10, 0)

local statusText = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
statusText:SetPoint("LEFT", instanceNameText, "RIGHT", 10, 0)

-- close
local closeBtn = ISC:CreateButton(collectorFrame, "X", "red", {20, 20})
closeBtn:SetPoint("TOPRIGHT")
closeBtn:SetScript("OnClick", function()
    collectorFrame:Hide()
end)

-- reset
local resetBtn = ISC:CreateButton(collectorFrame, "Reset", "magenta", {50, 20})
resetBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", 1, 0)
resetBtn:RegisterForClicks("MiddleButtonUp")
resetBtn:SetScript("OnClick", function()
    if IsControlKeyDown() then
        ISC_Config = nil
        ISC_Data = nil
        ReloadUI()
    end
end)

resetBtn:HookScript("OnEnter", function()
    ISCTooltip:SetOwner(resetBtn, "ANCHOR_NONE")
    ISCTooltip:SetPoint("BOTTOMRIGHT", resetBtn, "TOPRIGHT", 0, 1)
    ISCTooltip:AddLine("Ctrl + Middle-Click to reset & reload")
    ISCTooltip:Show()
end)
resetBtn:HookScript("OnLeave", function()
    ISCTooltip:Hide()
end)

-- scale slider
local scaleSlider = ISC:CreateSlider("", collectorFrame, 0.5, 3, 50, 0.25, nil, function(value)
    ISC_Config.scale = value
    ISC:Fire("UpdateScale")
end)
scaleSlider:SetPoint("TOPRIGHT", resetBtn, "TOPLEFT", -5, -5)
scaleSlider.currentEditBox:Hide()
scaleSlider.lowText:Hide()
scaleSlider.highText:Hide()

ISC:RegisterCallback("AddonLoaded", "Collector_AddonLoaded", function()
    scaleSlider:SetValue(ISC_Config.scale)
end)

-- add & track
local addBtn = ISC:CreateButton(collectorFrame, "Add Current Instance", "red", {200, 20})
addBtn:SetPoint("TOPLEFT", 5, -45)
addBtn:SetScript("OnClick", function()
    if currentInstanceName and currentInstanceID then
        if not ISC_Data[currentInstanceID] then
            AddCurrentInstance()
        end
    end
end)

-- tips
local tips = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
tips:SetPoint("LEFT", addBtn, "RIGHT", 5, 0)
tips:SetText("[Right-Click] track/untrack, [Ctrl-Click] delete")

-------------------------------------------------
-- list button
-------------------------------------------------
local function CreateListButton(parent)
    local b = ISC:CreateButton(parent, " ", "red-hover", {20, 20}, true)
    b:RegisterForClicks("AnyUp")
    b:GetFontString():ClearAllPoints()
    b:GetFontString():SetPoint("LEFT", 5, 0)
    b:GetFontString():SetPoint("RIGHT", -5, 0)
    b:GetFontString():SetJustifyH("LEFT")
    return b
end

-------------------------------------------------
-- instance list
-------------------------------------------------
local instanceListFrame = CreateFrame("Frame", nil, collectorFrame)
instanceListFrame:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(instanceListFrame)
instanceListFrame:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -5)
instanceListFrame:SetPoint("BOTTOMRIGHT", collectorFrame, "BOTTOMLEFT", 205, 5)

ISC:CreateScrollFrame(instanceListFrame)
local currentInstanceHighlight = CreateFrame("Frame", nil, collectorFrame)
currentInstanceHighlight:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(currentInstanceHighlight, {0, 0, 0, 0}, {0.2, 1, 0.2})

local sotredInstances = {}
local instanceButtons = {}
local selectedInstance
LoadInstances = function(scroll)
    wipe(sotredInstances)
    instanceListFrame.scrollFrame:Reset()

    for id in pairs(ISC_Data) do
        tinsert(sotredInstances, id)
    end
    table.sort(sotredInstances)

    local last
    for i, id in pairs(sotredInstances) do
        if not instanceButtons[i] then
            instanceButtons[i] = CreateListButton(instanceListFrame.scrollFrame.content)
        else
            instanceButtons[i]:ClearAllPoints()
            instanceButtons[i]:SetParent(instanceListFrame.scrollFrame.content)
            instanceButtons[i]:SetFrameLevel(instanceListFrame.scrollFrame.content:GetFrameLevel() + 1)
            instanceButtons[i]:Show()
        end

        local b = instanceButtons[i]

        if ISC_Data[id]["enabled"] then
            b:GetFontString():SetTextColor(1, 1, 1)
        else
            b:GetFontString():SetTextColor(0.4, 0.4, 0.4)
        end

        b:SetText(id == ISC_Data[id]["name"] and id or id .. " " .. ISC_Data[id]["name"])

        if last then
            b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 1)
        else
            b:SetPoint("TOPLEFT", 1, -1)
        end
        b:SetPoint("RIGHT", -1, 0)
        last = b

        b:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                currentInstanceHighlight:Hide()
                currentInstanceHighlight:ClearAllPoints()
                if IsControlKeyDown() then -- delete
                    if id == currentInstanceID then
                        statusText:SetText("")
                        UnregisterEvents()
                        if ISC_Data[id]["enabled"] then print("|cffff7700STOP TRACKING SPELLS!") end
                    end
                    ISC_Data[id] = nil
                    LoadInstances(instanceListFrame.scrollFrame:GetVerticalScroll())
                    if selectedInstance == id then
                        LoadEnemies()
                    end
                else -- show enemies
                    selectedInstance = id
                    currentInstanceHighlight:Show()
                    currentInstanceHighlight:SetAllPoints(b)
                    currentInstanceHighlight:SetParent(b)
                    currentInstanceHighlight:SetFrameLevel(b:GetFrameLevel() + 1)
                    LoadEnemies(ISC_Data[id]["data"])
                end
                LoadAuras()
                LoadCasts()
                Export()
            elseif button == "RightButton" then -- track/untrack
                ISC_Data[id]["enabled"] = not ISC_Data[id]["enabled"]
                if ISC_Data[id]["enabled"] then
                    b:GetFontString():SetTextColor(1, 1, 1, 1)
                else
                    b:GetFontString():SetTextColor(0.4, 0.4, 0.4, 1)
                end

                if id == currentInstanceID then
                    if ISC_Data[id]["enabled"] then
                        statusText:SetText("|cff55ff55TRACKING")
                        print("|cff77ff00[ISC] START TRACKING!")
                        RegisterEvents()
                    else
                        statusText:SetText("")
                        print("|cffff7700[ISC] STOP TRACKING!")
                        UnregisterEvents()
                    end
                end
            end
        end)
    end

    instanceListFrame.scrollFrame:SetContentHeight(20, #sotredInstances, -1)
    instanceListFrame.scrollFrame:VerticalScroll(scroll or 0)
end

-------------------------------------------------
-- enemy list
-------------------------------------------------
local enemyListFrame = CreateFrame("Frame", nil, collectorFrame)
enemyListFrame:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(enemyListFrame)
enemyListFrame:SetPoint("TOPLEFT", instanceListFrame, "TOPRIGHT", 5, 0)
enemyListFrame:SetPoint("BOTTOMRIGHT", instanceListFrame, "BOTTOMRIGHT", 205, 0)

ISC:CreateScrollFrame(enemyListFrame)
local currentEnemyHighlight = CreateFrame("Frame", nil, collectorFrame)
currentEnemyHighlight:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(currentEnemyHighlight, {0, 0, 0, 0}, {0.2, 1, 0.2})

local sortedEnemies = {}
local enemyButtons = {}
LoadEnemies = function(data, scroll)
    wipe(sortedEnemies)
    enemyListFrame.scrollFrame:Reset()
    currentEnemyHighlight:Hide()
    currentEnemyHighlight:ClearAllPoints()

    if not data then return end

    -- sort
    local enemies = {}
    for k in pairs(data) do
        enemies[k] = true
    end
    for k in pairs(enemies) do
        tinsert(sortedEnemies, k)
    end
    table.sort(sortedEnemies, function(a, b)
        if strfind(a, "|cff") and not strfind(b, "|cff") then
            return true
        elseif not strfind(a, "|cff") and strfind(b, "|cff") then
            return false
        elseif strfind(a, "*") and not strfind(b, "*") then
            return false
        elseif not strfind(a, "*") and strfind(b, "*") then
            return true
        else
            return a < b
        end
    end)

    local last
    for i, enemy in ipairs(sortedEnemies) do
        if not enemyButtons[i] then
            enemyButtons[i] = CreateListButton(enemyListFrame.scrollFrame.content)

            -- tooltip
            enemyButtons[i]:HookScript("OnEnter", function()
                if enemyButtons[i].npcId then
                    ISCTooltip:SetOwner(collectorFrame, "ANCHOR_NONE")
                    ISCTooltip:SetPoint("TOPLEFT", enemyButtons[i], "TOPRIGHT", 1, 0)
                    ISCTooltip:AddLine("npcID: " .. "|cffffffff" .. enemyButtons[i].npcId)
                    ISCTooltip:Show()
                end
            end)

            enemyButtons[i]:HookScript("OnLeave", function()
                ISCTooltip:Hide()
            end)
        else
            enemyButtons[i]:ClearAllPoints()
            enemyButtons[i]:SetParent(enemyListFrame.scrollFrame.content)
            enemyButtons[i]:SetFrameLevel(enemyListFrame.scrollFrame.content:GetFrameLevel() + 1)
            enemyButtons[i]:Show()
        end

        local b = enemyButtons[i]
        b.enemy = enemy
        b.npcId = data[enemy]["npcId"]

        b:SetText(enemy)

        if last then
            b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 1)
        else
            b:SetPoint("TOPLEFT", 1, -1)
        end
        b:SetPoint("RIGHT", -1, 0)
        last = b

        b:SetScript("OnClick", function(self, button)
            if IsControlKeyDown() then
                currentEnemyHighlight:Hide()
                currentEnemyHighlight:ClearAllPoints()
                data[enemy] = nil
                LoadEnemies(data, enemyListFrame.scrollFrame:GetVerticalScroll())
                LoadAuras()
                LoadCasts()
            else
                currentEnemyHighlight:Show()
                currentEnemyHighlight:SetAllPoints(b)
                currentEnemyHighlight:SetParent(b)
                currentEnemyHighlight:SetFrameLevel(b:GetFrameLevel() + 1)
                LoadAuras(data[enemy]["auras"])
                LoadCasts(data[enemy]["casts"])

                if data[enemy]["encounterId"] then
                    Export("eName: " .. data[enemy]["encounterName"], "eId: " .. data[enemy]["encounterId"] .. "\n", NpcsToString(data[enemy]["npcs"]), AurasToString(data[enemy]["auras"]), CastsToString(data[enemy]["casts"]))
                elseif data[enemy]["npcId"] then
                    Export("npcName: " .. data[enemy]["npcName"], "npcID: " .. data[enemy]["npcId"] .. "\n", AurasToString(data[enemy]["auras"]), CastsToString(data[enemy]["casts"]))
                else -- UNKNOWN / MOBS
                    Export(enemy .. "\n", AurasToString(data[enemy]["auras"]), CastsToString(data[enemy]["casts"]))
                end
            end
        end)
    end

    enemyListFrame.scrollFrame:SetContentHeight(20, #sortedEnemies, -1)
    enemyListFrame.scrollFrame:VerticalScroll(scroll or 0)
end

-------------------------------------------------
-- debuff list
-------------------------------------------------
local debuffListFrame = CreateFrame("Frame", nil, collectorFrame)
debuffListFrame:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(debuffListFrame)
debuffListFrame:SetPoint("TOPLEFT", enemyListFrame, "TOPRIGHT", 5, 0)
debuffListFrame:SetPoint("BOTTOMRIGHT", enemyListFrame, "BOTTOMRIGHT", 205, 0)

ISC:CreateScrollFrame(debuffListFrame)
local currentDebuffHighlight = CreateFrame("Frame", nil, collectorFrame)
currentDebuffHighlight:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(currentDebuffHighlight, {0, 0, 0, 0}, {0.2, 1, 0.2})

local sortedDebuffs = {}
local debuffButtons = {}
LoadAuras = function(auras, scroll)
    wipe(sortedDebuffs)
    debuffListFrame.scrollFrame:Reset()
    currentDebuffHighlight:Hide()
    currentDebuffHighlight:ClearAllPoints()
    ISCTooltip:Hide()

    if not auras then return end

    for id in pairs(auras) do
        tinsert(sortedDebuffs, id)
    end
    table.sort(sortedDebuffs, function(a, b)
        if ISC_Spell[a] and not ISC_Spell[b] then
            return true
        end
        if not ISC_Spell[a] and ISC_Spell[b] then
            return false
        end
        if ISC_Spell[a]["auraType"] ~= ISC_Spell[b]["auraType"] then
            return ISC_Spell[a]["auraType"] == "buff"
        end
        -- if ISC_Spell[a]["auraDispelType"] ~= ISC_Spell[b]["auraDispelType"] then
        --     if ISC_Spell[a]["auraDispelType"] and ISC_Spell[b]["auraDispelType"] then
        --         return ISC_Spell[a]["auraDispelType"] < ISC_Spell[b]["auraDispelType"]
        --     end
        -- end
        return a < b
    end)

    local last
    for i, id in ipairs(sortedDebuffs) do
        if not debuffButtons[i] then
            debuffButtons[i] = CreateListButton(debuffListFrame.scrollFrame.content)

            -- tooltip
            debuffButtons[i]:HookScript("OnEnter", function()
                ISCTooltip:SetOwner(collectorFrame, "ANCHOR_NONE")
                ISCTooltip:SetPoint("TOPLEFT", debuffButtons[i], "TOPRIGHT", 1, 0)
                ISCTooltip:SetHyperlink("spell:" .. debuffButtons[i].id)
                ISCTooltip:SetExtraTip(debuffButtons[i].auraDesc)
                ISCTooltip:Show()
            end)

            debuffButtons[i]:HookScript("OnLeave", function()
                ISCTooltip:Hide()
            end)
        else
            debuffButtons[i]:ClearAllPoints()
            debuffButtons[i]:SetParent(debuffListFrame.scrollFrame.content)
            debuffButtons[i]:SetFrameLevel(debuffListFrame.scrollFrame.content:GetFrameLevel() + 1)
            debuffButtons[i]:Show()
        end

        if ISC_Spell[id] and ISC_Spell[id]["icon"] and ISC_Spell[id]["name"] then
            local b = debuffButtons[i]
            b.id = id
            b.auraDesc = ISC_Spell[id]["auraDesc"]

            if ISC_Spell[id]["auraType"] == "debuff" and ISC_Spell[id]["auraDispelType"] and DebuffTypeColor[ISC_Spell[id]["auraDispelType"]] then
                -- b:GetFontString():SetTextColor(unpack(DebuffTypeColor[ISC_Spell[id]["auraType"]]))
                b:SetText("|T" .. ISC_Spell[id]["icon"] .. ":16:16:0:0:16:16|t " .. id .. (ISC_Spell[id]["auraStackable"] and "+ " or " ") ..
                    "|TInterface\\AddOns\\!InstanceSpellCollector\\Media\\" .. ISC_Spell[id]["auraDispelType"] .. ":0|t" .. ISC_Spell[id]["name"])
            else
                -- b:GetFontString():SetTextColor(1, 1, 1)
                b:SetText("|T" .. ISC_Spell[id]["icon"] .. ":16:16:0:0:16:16|t " .. id .. (ISC_Spell[id]["auraStackable"] and "+ " or " ") .. ISC_Spell[id]["name"])
            end

            if ISC_Spell[id]["auraType"] == "buff" then
                b:GetFontString():SetTextColor(0.7, 1, 0.7)
            else
                b:GetFontString():SetTextColor(1, 1, 1)
            end

            if last then
                b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 1)
            else
                b:SetPoint("TOPLEFT", 1, -1)
            end
            b:SetPoint("RIGHT", -1, 0)
            last = b

            b:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    currentDebuffHighlight:Hide()
                    currentDebuffHighlight:ClearAllPoints()
                    if IsControlKeyDown() then
                        auras[id] = nil
                        LoadAuras(auras, debuffListFrame.scrollFrame:GetVerticalScroll())
                    else
                        currentDebuffHighlight:Show()
                        currentDebuffHighlight:SetAllPoints(b)
                        currentDebuffHighlight:SetParent(b)
                        currentDebuffHighlight:SetFrameLevel(b:GetFrameLevel() + 1)

                        local str = id .. ", -- " .. ISC_Spell[id]["name"]

                        local info = ""

                        if ISC_Spell[id]["auraType"] then
                            info = info .. "\ntype: " .. ISC_Spell[id]["auraType"]
                        end

                        if ISC_Spell[id]["auraDispelType"] and ISC_Spell[id]["auraDispelType"] ~= "" then
                            info = info .. "\ndispelType: " .. ISC_Spell[id]["auraDispelType"]
                        end

                        if ISC_Spell[id]["auraDuration"] then
                            info = info .. "\nduration: " .. ISC_Spell[id]["auraDuration"]
                        end

                        if ISC_Spell[id]["auraStackable"] then
                            info = info .. "\nstackable: true"
                        end

                        if info ~= "" then
                            str = str .. "\n" .. info
                        end

                        if type(ISC_Spell[id]["sources"]) == "table" then
                            local source = "\n\nsource:"
                            for id, name in pairs(ISC_Spell[id]["sources"]) do
                                source = source .. "\n" .. tostring(id) .. " " .. tostring(name)
                            end
                            if source ~= "\n\nsource:" then
                                str = str .. source
                            end
                        end

                        if ISC_Spell[id]["desc"] and ISC_Spell[id]["desc"] ~= "" then
                            str = str .. "\n\ndescription:\n" .. ISC_Spell[id]["desc"]
                        end

                        if ISC_Spell[id]["auraDesc"] and ISC_Spell[id]["auraDesc"] ~= "" then
                            str = str .. "\n\naura description:\n" .. ISC_Spell[id]["auraDesc"]
                        end

                        Export(str)
                    end
                end
            end)
        end
    end

    debuffListFrame.scrollFrame:SetContentHeight(20, #sortedDebuffs, -1)
    debuffListFrame.scrollFrame:VerticalScroll(scroll or 0)
end

-------------------------------------------------
-- cast list
-------------------------------------------------
local castListFrame = CreateFrame("Frame", nil, collectorFrame)
castListFrame:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(castListFrame)
castListFrame:SetPoint("TOPLEFT", debuffListFrame, "TOPRIGHT", 5, 0)
castListFrame:SetPoint("BOTTOMRIGHT", debuffListFrame, "BOTTOMRIGHT", 205, 0)

ISC:CreateScrollFrame(castListFrame)
local currentCastHighlight = CreateFrame("Frame", nil, collectorFrame)
currentCastHighlight:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(currentCastHighlight, {0, 0, 0, 0}, {0.2, 1, 0.2})

local sortedCasts = {}
local castButtons = {}
local castOrder = {
    ["cast"] = 1,
    ["channel"] = 2,
    ["instant"] = 3,
}
LoadCasts = function(casts, scroll)
    wipe(sortedCasts)
    castListFrame.scrollFrame:Reset()
    currentCastHighlight:Hide()
    currentCastHighlight:ClearAllPoints()
    ISCTooltip:Hide()

    if not casts then return end

    for id in pairs(casts) do
        tinsert(sortedCasts, id)
    end
    table.sort(sortedCasts, function(a, b)
        if ISC_Spell[a] and not ISC_Spell[b] then
            return true
        end
        if not ISC_Spell[a] and ISC_Spell[b] then
            return false
        end
        if ISC_Spell[a]["castType"] ~= ISC_Spell[b]["castType"] then
            if ISC_Spell[a]["castType"] and ISC_Spell[a]["castType"] then
                return castOrder[ISC_Spell[a]["castType"]] < castOrder[ISC_Spell[b]["castType"]]
            end
        end
        return a < b
    end)

    local last
    for i, id in ipairs(sortedCasts) do
        if not castButtons[i] then
            castButtons[i] = CreateListButton(castListFrame.scrollFrame.content)

            -- tooltip
            castButtons[i]:HookScript("OnEnter", function()
                ISCTooltip:SetOwner(collectorFrame, "ANCHOR_NONE")
                ISCTooltip:SetPoint("TOPLEFT", castButtons[i], "TOPRIGHT", 1, 0)
                ISCTooltip:SetHyperlink("spell:" .. castButtons[i].id)
                ISCTooltip:Show()
            end)

            castButtons[i]:HookScript("OnLeave", function()
                ISCTooltip:Hide()
            end)
        else
            castButtons[i]:ClearAllPoints()
            castButtons[i]:SetParent(castListFrame.scrollFrame.content)
            castButtons[i]:SetFrameLevel(castListFrame.scrollFrame.content:GetFrameLevel() + 1)
            castButtons[i]:Show()
        end

        if ISC_Spell[id] and ISC_Spell[id]["icon"] and ISC_Spell[id]["name"] then
            local b = castButtons[i]
            b.id = id

            b:SetText("|T" .. ISC_Spell[id]["icon"] .. ":16:16:0:0:16:16|t " .. id .. " " .. ISC_Spell[id]["name"])

            if ISC_Spell[id]["castType"] == "channel" then
                b:GetFontString():SetTextColor(1, 1, 0.5)
            elseif ISC_Spell[id]["castType"] == "instant" then
                b:GetFontString():SetTextColor(0.75, 0.75, 0.75)
            else
                b:GetFontString():SetTextColor(1, 1, 1)
            end

            if last then
                b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 1)
            else
                b:SetPoint("TOPLEFT", 1, -1)
            end
            b:SetPoint("RIGHT", -1, 0)
            last = b

            b:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    currentCastHighlight:Hide()
                    currentCastHighlight:ClearAllPoints()
                    if IsControlKeyDown() then
                        casts[id] = nil
                        LoadCasts(casts, castListFrame.scrollFrame:GetVerticalScroll())
                    else
                        currentCastHighlight:Show()
                        currentCastHighlight:SetAllPoints(b)
                        currentCastHighlight:SetParent(b)
                        currentCastHighlight:SetFrameLevel(b:GetFrameLevel() + 1)

                        local str = id .. ", -- " .. ISC_Spell[id]["name"]

                        str = str .. "\n\n" .. "castType: " .. ISC_Spell[id]["castType"]

                        if ISC_Spell[id]["castTime"] then
                            str = str .. "\n" .. "castTime: " .. (ISC_Spell[id]["castTime"] / 1000)
                        end

                        if type(ISC_Spell[id]["sources"]) == "table" then
                            local source = "\n\nsource:"
                            for id, name in pairs(ISC_Spell[id]["sources"]) do
                                source = source .. "\n" .. tostring(id) .. " " .. tostring(name)
                            end
                            if source ~= "\n\nsource:" then
                                str = str .. source
                            end
                        end

                        if ISC_Spell[id]["desc"] and ISC_Spell[id]["desc"] ~= "" then
                            str = str .. "\n\n" .. "description:\n" .. ISC_Spell[id]["desc"]
                        end

                        Export(str)
                    end
                end
            end)
        end
    end

    castListFrame.scrollFrame:SetContentHeight(20, #sortedCasts, -1)
    castListFrame.scrollFrame:VerticalScroll(scroll or 0)
end

-------------------------------------------------
-- export
-------------------------------------------------
local exportFrame = CreateFrame("Frame", nil, collectorFrame)
exportFrame:SetFrameLevel(collectorFrame:GetFrameLevel() + 1)
ISC:StylizeFrame(exportFrame)
exportFrame:SetPoint("TOPLEFT", castListFrame, "TOPRIGHT", 10, 0)
exportFrame:SetPoint("BOTTOMRIGHT", castListFrame, "BOTTOMRIGHT", 270, 0)
exportFrame:Hide()

local exportFrameEditBox = ISC:CreateScrollEditBox(exportFrame)
exportFrameEditBox:SetPoint("TOPLEFT", 5, -5)
exportFrameEditBox:SetPoint("BOTTOMRIGHT", -5, 5)
exportFrameEditBox.eb:SetSpacing(2)

exportFrame:SetScript("OnHide", function()
    exportFrame:Hide()
end)

local exportFrameCloseBtn = ISC:CreateButton(exportFrame, "X", "red", {20, 20})
exportFrameCloseBtn:SetPoint("BOTTOMRIGHT", exportFrame, "TOPRIGHT", 0, -1)
exportFrameCloseBtn:SetScript("OnClick", function()
    exportFrame:Hide()
end)

NpcsToString = function(data)
    local result = "-- npcs\n"

    if data then
        local sorted = {}
        for id in pairs(data) do
            tinsert(sorted, id)
        end
        table.sort(sorted)

        for _, id in ipairs(sorted) do
            result = result .. id .. "-- " .. data[id] .. "\n"
        end
    end

    return result
end

AurasToString = function(data)
    local result = ""

    if data then
        local sorted = {}
        for id in pairs(data) do
            tinsert(sorted, id)
        end
        table.sort(sorted)

        local buffs = {}
        local debuffs = {}

        for _, id in ipairs(sorted) do
            if ISC_Spell[id] then
                if ISC_Spell[id]["auraType"] == "buff" then
                    tinsert(buffs, id .. ", -- " .. ISC_Spell[id]["name"])
                else
                    tinsert(debuffs, id .. ", -- " .. ISC_Spell[id]["name"])
                end
            else
                tinsert(debuffs, id .. ", -- " .. (GetTheSpellInfo(id) or "INVALID"))
            end
        end

        if #buffs ~= 0 then
            result = result .. "-- buffs\n"
            for _, buff in pairs(buffs) do
                result = result .. buff .. "\n"
            end
        end

        if #debuffs ~= 0 then
            if result ~= "" then result = result .. "\n" end
            result = result .. "-- debuffs\n"
            for _, debuff in pairs(debuffs) do
                result = result .. debuff .. "\n"
            end
        end
    end

    return result
end

CastsToString = function(data)
    local result = ""

    if data then
        local sorted = {}
        for id in pairs(data) do
            tinsert(sorted, id)
        end
        table.sort(sorted)

        local casts = {}
        local channels = {}
        local instants = {}

        for _, id in ipairs(sorted) do
            if ISC_Spell[id] then
                if ISC_Spell[id]["castType"] == "instant" then
                    tinsert(instants, id .. ", -- " .. ISC_Spell[id]["name"])
                elseif ISC_Spell[id]["castType"] == "channel" then
                    tinsert(channels, id .. ", -- " .. ISC_Spell[id]["name"])
                else
                    tinsert(casts, id .. ", -- " .. ISC_Spell[id]["name"])
                end
            else
                tinsert(casts, id .. ", -- " .. (GetTheSpellInfo(id) or "INVALID"))
            end
        end

        if #casts ~= 0 then
            result = result .. "-- casts\n"
            for _, cast in pairs(casts) do
                result = result .. cast .. "\n"
            end
        end

        if #channels ~= 0 then
            if result ~= "" then result = result .. "\n" end
            result = result .. "-- channels\n"
            for _, channel in pairs(channels) do
                result = result .. channel .. "\n"
            end
        end

        if #instants ~= 0 then
            if result ~= "" then result = result .. "\n" end
            result = result .. "-- instants\n"
            for _, instant in pairs(instants) do
                result = result .. instant .. "\n"
            end
        end
    end

    return result
end

Export = function(...)
    local n = select("#", ...)
    if n == 0 then
        exportFrame:Hide()
        return
    end

    exportFrame:Show()

    local result = ""

    for i = 1, n do
        local data = select(i, ...)
        if data ~= "" then
            result = result .. data .. "\n"
        end
    end

    exportFrameEditBox:SetText(result)

    C_Timer.After(0.1, function()
        exportFrameEditBox.scrollFrame:SetVerticalScroll(0)
    end)
end

-------------------------------------------------
-- tips
-------------------------------------------------
local instanceTip = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
instanceTip:SetPoint("TOPLEFT", instanceListFrame, "BOTTOMLEFT", 0, -7)
instanceTip:SetText("[instanceID instanceName]")
instanceTip:SetTextColor(0.77, 0.77, 0.77)

local enemyTip = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
enemyTip:SetPoint("TOPLEFT", enemyListFrame, "BOTTOMLEFT", 0, -7)
enemyTip:SetText("[encounterID enemyName]")
enemyTip:SetTextColor(0.77, 0.77, 0.77)

local auraTip = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
auraTip:SetPoint("TOPLEFT", debuffListFrame, "BOTTOMLEFT", 0, -7)
auraTip:SetText("Auras: [spellID spellName]")
auraTip:SetTextColor(0.77, 0.77, 0.77)

local castTip = collectorFrame:CreateFontString(nil, "OVERLAY", "ISC_FONT_NORMAL")
castTip:SetPoint("TOPLEFT", castListFrame, "BOTTOMLEFT", 0, -7)
castTip:SetText("Casts: [spellID spellName]")
castTip:SetTextColor(0.77, 0.77, 0.77)

-------------------------------------------------
-- dialog
-------------------------------------------------
local dialogTip = "Enable |cFFFF3030ISC|r for current instance?"

local dialog = CreateFrame("Frame", "InstanceSpellCollectorDialog", UIParent)
dialog:SetFrameLevel(UIParent:GetFrameLevel() + 1)
P:Size(dialog, 320, 120)
dialog:SetPoint("BOTTOM", UIParent, "CENTER")
dialog:SetFrameStrata("FULLSCREEN_DIALOG")
dialog:EnableMouse(true)
dialog:SetClampedToScreen(true)
dialog:SetClampRectInsets(0, 0, 0, 0)
dialog:Hide()

dialog:SetScript("OnShow", function()
    P:PixelPerfectPoint(dialog)
end)

local dialogText = dialog:CreateFontString(nil, "OVERLAY", "ISC_FONT_TITLE")
dialogText:SetPoint("TOP", 0, -10)
dialogText:SetPoint("LEFT", 10, 0)
dialogText:SetPoint("RIGHT", -10, 0)
dialogText:SetSpacing(5)
dialogText:SetText(dialogTip)

local yesBtn = ISC:CreateButton(dialog, "Yes", "green", {100, 20})
P:Point(yesBtn, "BOTTOMLEFT", 5, 5)
yesBtn:SetScript("OnClick", function()
    AddCurrentInstance()
    dialog:Hide()
end)

local noBtn = ISC:CreateButton(dialog, "No", "red", {100, 20})
P:Point(noBtn, "BOTTOMLEFT", yesBtn, "BOTTOMRIGHT", 5, 0)
noBtn:SetScript("OnClick", function()
    dialog:Hide()
end)

local neverBtn = ISC:CreateButton(dialog, "Never", "red", {100, 20})
P:Point(neverBtn, "BOTTOMLEFT", noBtn, "BOTTOMRIGHT", 5, 0)
neverBtn:SetScript("OnClick", function()
    ISC_Ignore[currentInstanceID] = currentInstanceName
    dialog:Hide()
end)

function dialog:UpdatePixelPerfect()
    dialog:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = P:Scale(1)})
    dialog:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    dialog:SetBackdropBorderColor(0, 0, 0, 1)

    dialog:SetSize(P:Scale(100) * 3 + P:Scale(5) * 4, 120)
    yesBtn:UpdatePixelPerfect()
    noBtn:UpdatePixelPerfect()
    neverBtn:UpdatePixelPerfect()
end

local function GetNpcIdFromGUID(guid)
    if not guid then return nil end
    return tonumber(strsub(guid, 8, 12), 16)
end

AddCurrentInstance = function()
    ISC_Data[currentInstanceID] = {
        ["name"] = currentInstanceName,
        ["enabled"] = true,
        ["data"] = {},
    }
    ISC_Ignore[currentInstanceID] = nil
    LoadInstances()
    collectorFrame:PLAYER_ENTERING_WORLD()
end

local function SaveData(index, sourceGUID, sourceName, spellId)
    local t = ISC_Data[currentInstanceID]["data"]
    local npcId = GetNpcIdFromGUID(sourceGUID)

    -- save enemy-spell ---------------------------------------------------------------------------
    local enemy = currentEncounterID .. sourceName
    if not t[enemy] then
        -- local _, _, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", sourceGUID)
        t[enemy] = {
            ["npcId"] = npcId,
            ["npcName"] = sourceName,
            ["auras"] = {},
            ["casts"] = {},
        }
    end
    t[enemy][index][spellId] = true
    -----------------------------------------------------------------------------------------------

    if currentEncounterID and currentEncounterName then
        -- save encounter-spell
        local currentEncounter = "|cff27ffff" .. currentEncounterID .. currentEncounterName .. "|r"
        if not t[currentEncounter] then
            t[currentEncounter] = {
                ["encounterName"] = currentEncounterName,
                ["encounterId"] = tonumber(currentEncounterID),
                ["npcs"] = {},
                ["auras"] = {},
                ["casts"] = {},
            }
        end

        if npcId then
            t[currentEncounter]["npcs"][npcId] = sourceName
        end

        if type(t[currentEncounter][index][spellId]) ~= "table" then t[currentEncounter][index][spellId] = {} end
        t[currentEncounter][index][spellId][npcId or 0] = sourceName
    else
        -- save mobs-spell
        local mobs = "|cff27ffff* MOBS|r"
        if not t[mobs] then
            t[mobs] = {
                ["auras"] = {},
                ["casts"] = {},
            }
        end

        if type(t[mobs][index][spellId]) ~= "table" then t[mobs][index][spellId] = {} end
        t[mobs][index][spellId][npcId or 0] = sourceName
    end
end

local function UpdateAura(source, spellId, auraDuration, isDebuff, auraDispelType, count, sourceGUID, sourceName)

    if not ISC_Spell[spellId] then
        ISC_Spell[spellId] = {
            ["sources"] = {},
            ["encounters"] = {},
        }
    end

    ISC_Spell[spellId]["build"] = ISC.build

    local name, icon = GetTheSpellInfo(spellId)
    ISC_Spell[spellId]["name"] = name or ISC_Spell[spellId]["name"] or "INVALID"
    ISC_Spell[spellId]["icon"] = icon or ISC_Spell[spellId]["icon"] or "Interface\\Icons\\INV_Misc_QuestionMark"
    if name and ISC_Spell[spellId]["desc"] == nil then
        ISC_Spell[spellId]["desc"] = GetTheSpellDescription(spellId)
    end

    if auraDispelType then
        ISC_Spell[spellId]["auraDispelType"] = auraDispelType
    end
    ISC_Spell[spellId]["auraType"] = isDebuff and "debuff" or "buff"

    if auraDuration then
        ISC_Spell[spellId]["auraDuration"] = auraDuration
    end

    if count and count > 1 then
        ISC_Spell[spellId]["auraStackable"] = true
    end

    if source or sourceGUID then
        local guid = sourceGUID or UnitGUID(source)
        local name = sourceName or UnitName(source)
        local id = GetNpcIdFromGUID(guid)
        if id then
            ISC_Spell[spellId]["sources"][id] = name
        end
    end

    if currentEncounterID and currentEncounterName then
        ISC_Spell[spellId]["encounters"][tonumber(currentEncounterID)] = currentEncounterName
    end
end

local function UpdateCast(source, spellId, castTime, castType, sourceGUID, sourceName)
    -- print("UpdateCast", source, spellId, castTime, castType)

    if not ISC_Spell[spellId] then
        ISC_Spell[spellId] = {
            ["sources"] = {},
            ["encounters"] = {},
        }
    end

    ISC_Spell[spellId]["build"] = ISC.build

    local name, icon = GetTheSpellInfo(spellId)
    ISC_Spell[spellId]["name"] = name or ISC_Spell[spellId]["name"] or "INVALID"
    ISC_Spell[spellId]["icon"] = icon or ISC_Spell[spellId]["icon"] or "Interface\\Icons\\INV_Misc_QuestionMark"
    if name and ISC_Spell[spellId]["desc"] == nil then
        ISC_Spell[spellId]["desc"] = GetTheSpellDescription(spellId)
    end

    if not (castTime or castType) then
        if not (ISC_Spell[spellId]["castType"] or ISC_Spell[spellId]["castTime"]) then
            ISC_Spell[spellId]["castType"] = "instant"
        end
    else
        ISC_Spell[spellId]["castType"] = castType
        ISC_Spell[spellId]["castTime"] = castTime
    end

    if source or sourceGUID then
        local guid = sourceGUID or UnitGUID(source)
        local name = sourceName or UnitName(source)
        local id = GetNpcIdFromGUID(guid)
        if id then
            ISC_Spell[spellId]["sources"][id] = name
        end
    end

    if currentEncounterID and currentEncounterName then
        ISC_Spell[spellId]["encounters"][tonumber(currentEncounterID)] = currentEncounterName
    end
end

-------------------------------------------------
-- event
-------------------------------------------------
collectorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

RegisterEvents = function()
    collectorFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    collectorFrame:RegisterEvent("UNIT_AURA")
    collectorFrame:RegisterEvent("UNIT_COMBAT")
end

UnregisterEvents = function()
    collectorFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    collectorFrame:UnregisterEvent("UNIT_AURA")
    collectorFrame:UnregisterEvent("UNIT_COMBAT")
end

function collectorFrame:PLAYER_ENTERING_WORLD()
    if IsInInstance() then
        local localizedName, instanceType = GetInstanceInfo()
        if not localizedName or localizedName == "" then
            currentInstanceName, currentInstanceID = nil, nil
            instanceIDText:SetText("Instance: |cffff5500UNKNOWN")
            instanceNameText:SetText("")
            statusText:SetText("")
            UnregisterEvents()
            return
        end

        local instanceName = ISC.instanceNames[localizedName] or localizedName
        local instanceID = instanceName
        instanceIDText:SetText("Instance: |cffff5500" .. instanceName)
        instanceNameText:SetText(localizedName ~= instanceName and "Local: |cffff5500" .. localizedName or "")
        currentInstanceName, currentInstanceID = instanceName, instanceID

        if ISC_Data[instanceID] and ISC_Data[instanceID]["enabled"] then
            statusText:SetText("|cff55ff55TRACKING")
            print("|cff77ff00[ISC] START TRACKING!")
            RegisterEvents()
        else
            if not ISC_Data[instanceID] and not ISC_Ignore[instanceID] and (instanceType == "raid" or instanceType == "party") then
                dialogText:SetText(dialogTip .. "\n|cFFFFD100" .. instanceName ..
                    (localizedName ~= instanceName and "\n" .. localizedName or ""))
                dialog:Show()
            end

            statusText:SetText("")
            UnregisterEvents()
        end
    else
        currentInstanceName, currentInstanceID = nil, nil
        instanceNameText:SetText("")
        instanceIDText:SetText("Instance:")
        statusText:SetText("")
        UnregisterEvents()
    end
end

local handledUnits = {}

function collectorFrame:ENCOUNTER_START(encounterID, encounterName)
    print("|cff0077ff[ISC] ENCOUNTER_START|r", encounterID, encounterName)
    wipe(handledUnits)
    currentEncounterID = encounterID .. " "
    currentEncounterName = encounterName
end

function collectorFrame:ENCOUNTER_END(encounterID, encounterName)
    print("|cff0077ff[ISC] ENCOUNTER_END|r", encounterID, encounterName)
    wipe(handledUnits)
    currentEncounterID = "* "
    currentEncounterName = nil
end

local dbmCallbacksRegistered
local dbmTracker = CreateFrame("Frame")

local function OnDBMEncounterEvent(event, mod)
    if type(mod) ~= "table" then return end

    local encounterID = tonumber(mod.encounterId)
    local combatInfo = mod.combatInfo or {}
    local localization = mod.localization and mod.localization.general or {}
    local encounterName = combatInfo.name or localization.name or mod.id or "Unknown"

    if event == "DBM_Pull" then
        if encounterID then
            collectorFrame:ENCOUNTER_START(encounterID, encounterName)
        else
            collectorFrame:ENCOUNTER_END(0, encounterName)
        end
    else
        collectorFrame:ENCOUNTER_END(encounterID or 0, encounterName)
    end
end

local function RegisterDBMEncounterCallbacks()
    if dbmCallbacksRegistered then return end
    if type(DBM) ~= "table" or type(DBM.RegisterCallback) ~= "function" then return end

    DBM:RegisterCallback("DBM_Pull", OnDBMEncounterEvent)
    DBM:RegisterCallback("DBM_Kill", OnDBMEncounterEvent)
    DBM:RegisterCallback("DBM_Wipe", OnDBMEncounterEvent)
    dbmCallbacksRegistered = true
    dbmTracker:UnregisterEvent("ADDON_LOADED")
end

dbmTracker:RegisterEvent("ADDON_LOADED")
dbmTracker:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon == "DBM-Core" then RegisterDBMEncounterCallbacks() end
end)
RegisterDBMEncounterCallbacks()

local AURA_BLACKLIST = {
    [2479] = true, -- Honorless Target
    [6788] = true, -- Weakened Soul
    [8326] = true, -- Ghost
    [25771] = true, -- Forbearance
    [41425] = true, -- Hypothermia
    [45181] = true, -- Cheating Death
    [48743] = true, -- Death Pact
    [50986] = true, -- Sulfuron Slammer
    [53755] = true, -- Flask of the Frost Wyrm
    [53758] = true, -- Flask of Stoneblood
    [53760] = true, -- Flask of Endless Rage
    [57723] = true, -- Exhaustion
    [57724] = true, -- Sated
    [57819] = true, -- Argent Champion
    [57820] = true, -- Ebon Champion
    [72968] = true, -- Precious's Ribbon
}

local function IsValidTarget(target)
    return UnitPlayerOrPetInRaid(target) or UnitPlayerOrPetInParty(target) or UnitIsPlayer(target)
end

local function IsValidSource(source)
    return not (UnitPlayerOrPetInRaid(source) or UnitPlayerOrPetInParty(source) or UnitIsPlayer(source)) -- or UnitPlayerControlled(source))
end

--! encounter npcs
function collectorFrame:UNIT_COMBAT(unit)
    if not (currentEncounterID and currentEncounterName) then return end

    local guid = UnitGUID(unit)
    if guid and not handledUnits[guid] then
        handledUnits[guid] = true
        if IsValidSource(unit) then
            local npcId = GetNpcIdFromGUID(guid)
            if npcId then
                local t = ISC_Data[currentInstanceID]["data"]
                local currentEncounter = "|cff27ffff" .. currentEncounterID .. currentEncounterName .. "|r"

                if not t[currentEncounter] then
                    t[currentEncounter] = {
                        ["encounterName"] = currentEncounterName,
                        ["encounterId"] = tonumber(currentEncounterID),
                        ["npcs"] = {},
                        ["auras"] = {},
                        ["casts"] = {},
                    }
                end
                t[currentEncounter]["npcs"][npcId] = UnitName(unit)
            end
        end
    end
end

--! CASTS AND AURAS (COMBAT_LOG_EVENT_UNFILTERED)
function collectorFrame:COMBAT_LOG_EVENT_UNFILTERED(...)
    local timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, auraType, amount = ...

    if not (currentInstanceName and currentInstanceID and spellId) then return end
    if not CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_HOSTILE_UNITS) then return end

    if event == "SPELL_AURA_APPLIED" then
        if AURA_BLACKLIST[spellId] then return end
        SaveData("auras", sourceGUID, sourceName or "UNKNOWN", spellId)
        UpdateAura(nil, spellId, nil, auraType == "DEBUFF", nil, nil, sourceGUID, sourceName)
    elseif event == "SPELL_CAST_START" then
        local _, _, castTime = GetTheSpellInfo(spellId)
        SaveData("casts", sourceGUID, sourceName or "UNKNOWN", spellId)
        UpdateCast(nil, spellId, castTime and castTime > 0 and castTime or nil, "cast", sourceGUID, sourceName)
    elseif event == "SPELL_CAST_SUCCESS" then
        SaveData("casts", sourceGUID, sourceName or "UNKNOWN", spellId)
        UpdateCast(nil, spellId, nil, nil, sourceGUID, sourceName)
    end
end

--! AURAS (UNIT_AURA)
local function IsFriendUnit(unit)
    return UnitIsPlayer(unit) or UnitPlayerOrPetInRaid(unit) or UnitPlayerOrPetInParty(unit)
end

---@param target string always friend unit
---@return boolean? isValid
---@return string? sourceGUID
---@return string sourceName
local function GetAuraInfo(spellId, isHarmful, source, target)
    if AURA_BLACKLIST[spellId] then return end

    if not source then
        return true, nil, "UNKNOWN"
    end

    if source == target then
        if IsFriendUnit(source) then
            -- self applied debuffs
            return isHarmful, nil, "SELF"
        else
            -- enemy to enemy buffs/debuffs
            return true, UnitGUID(source), UnitName(source) or "UNKNOWN"
        end
    else
        if IsFriendUnit(source) then
            -- friend to friend debuffs
            return isHarmful, nil, "PLAYER"
        else
            -- enemy to friend buffs/debuffs
            return true, UnitGUID(source), UnitName(source) or "UNKNOWN"
        end
    end
end

local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff

function collectorFrame:UNIT_AURA(unit)
    if not (currentInstanceName and currentInstanceID) then return end
    if not IsValidTarget(unit) then return end

    for i = 1, 40 do
        local name, _, icon, count, dispelType, duration, expirationTime, source, _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end

        local isValid, sourceGUID, sourceName = GetAuraInfo(spellId, true, source, unit)
        if isValid then
            SaveData("auras", sourceGUID, sourceName, spellId)
            UpdateAura(source, spellId, duration, true, dispelType, count)
        end
    end

    for i = 1, 40 do
        local name, _, icon, count, dispelType, duration, expirationTime, source, _, _, spellId = UnitBuff(unit, i)
        if not name then
            break
        end

        local isValid, sourceGUID, sourceName = GetAuraInfo(spellId, false, source, unit)
        if isValid then
            SaveData("auras", sourceGUID, sourceName, spellId)
            UpdateAura(source, spellId, duration, false, dispelType, count)
        end
    end
end

collectorFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)
