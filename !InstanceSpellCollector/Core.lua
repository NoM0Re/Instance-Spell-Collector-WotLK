local addonName, ISC = ...
local P = ISC.pixelPerfectFuncs

local version, build = GetBuildInfo()
ISC.build = version .. "." .. build

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)
function eventFrame:ADDON_LOADED(arg1)
    if arg1 == addonName then
        eventFrame:UnregisterEvent("ADDON_LOADED")

        ISC.version = GetAddOnMetadata(addonName, "version")

        if type(ISC_Config) ~= "table" then ISC_Config = {} end

        -- scale
        if type(ISC_Config.scale) ~= "number" then
            local pScale = P:GetPixelPerfectScale()
            local scale
            if pScale >= 0.7 then
                scale = 1
            elseif pScale >= 0.5 then
                scale = 1.4
            else
                scale = 2
            end
            ISC_Config.scale = scale
        end
        P:SetRelativeScale(ISC_Config.scale)
        ISC:Fire("UpdateScale")

        -- data table
        if type(ISC_Data) ~= "table" then
            ISC_Data = {
                -- [englishInstanceName] = {
                --     ["name"] = (string),
                --     ["enabled"] = (boolean),
                --     ["data"] = {
                --         [encounterDisplayName] = {
                --             ["encounterId"] = (number),
                --             ["encounterName"] = (string),
                --             ["npcs"] = {
                --                 [npcId] = npcName,
                --             },
                --             ["auras"] = {
                --                 [id] = (number) sourceNpcId / (string) "UNKNOWN" / true,
                --             },
                --             ["casts"] = {
                --                 [id] = (number) sourceNpcId / (string) "UNKNOWN" / true,
                --             },
                --         },
                --         [npcDisplayName] = {
                --             ["npcId"] = (number),
                --             ["npcName"] = (string),
                --             ["auras"] = {
                --                 [id] = true,
                --             },
                --             ["casts"] = {
                --                 [id] = true,
                --             },
                --         },
                --     }
                -- }
            }
        end

        -- store all spell data
        if type(ISC_Spell) ~= "table" then
            ISC_Spell = {
                -- [id] = {
                --     ["name"] = (string),
                --     ["icon"] = (string),
                --     ["desc"] = (string),
                --     ["sources"] = {
                --         [npcId] = npcName,
                --     },
                --     ["encounters"] = {
                --         [encounterId] = encounterName,
                --     },
                --     -- aura
                --     ["auraDesc"] = (string),
                --     ["auraDuration"] = (number),
                --     ["auraType"] = "buff" / "debuff",
                --     ["auraDispelType"] = "Curse" / "Disease" / "Magic" / "Poison",
                --     ["auraStackable"] = true / nil,
                --     -- cast
                --     ["castType"] = "cast" / "channel" / "instant",
                --     ["castTime"] = (number),
                -- }
            }
        end

        -- aura descriptions
        -- if type(ISC_AuraDesc) ~= "table" then
        --     ISC_AuraDesc = {
        --         -- [auraId] = "auraDescription"
        --     }
        -- end

        -- npc id
        -- if type(ISC_NpcId) ~= "table" then
        --     ISC_NpcId = {
        --         -- [instanceId] = {
        --         --     [name] = id
        --         -- }
        --     }
        -- end

        -- revise ---------------------------------------------------
        -- for id in pairs(ISC_Data["instances"]) do
        --     if not ISC_NpcId[id] then ISC_NpcId[id] = {} end
        -- end

        if ISC_AuraDesc and ISC_NpcId then
            local data_temp = {}
            local spell_temp = {}

            for _, index in pairs({"debuffs", "casts"}) do
                for instanceId, instanceTbl in pairs(ISC_Data[index]) do
                    if not data_temp[instanceId] then
                        data_temp[instanceId] = {
                            ["name"] = ISC_Data["instances"][instanceId]["name"],
                            ["enabled"] = ISC_Data["instances"][instanceId]["enabled"],
                            ["data"] = {},
                        }
                    end

                    local t = data_temp[instanceId]["data"]

                    for source, tbl in pairs(instanceTbl) do
                        if strfind(source, "^|cff") and not strfind(source, "|r$") then
                            source = source .. "|r"
                        end

                        if not t[source] then
                            t[source] = {
                                ["auras"] = {},
                                ["casts"] = {}
                            }
                        end

                        -- move spells
                        for spellId, spellName in pairs(tbl) do
                            t[source][index == "debuffs" and "auras" or "casts"][spellId] = true

                            spell_temp[spellId] = {
                                ["sources"] = {},
                                ["encounters"] = {},
                                ["build"] = ISC.build,
                            }
                            if index == "debuffs" then
                                spell_temp[spellId]["auraType"] = "debuff"
                                spell_temp[spellId]["auraDesc"] = ISC_AuraDesc[spellId]
                            end
                        end

                        if strfind(source, "^|cff27ffff%d+ ") then
                            -- add encounter info
                            t[source]["npcs"] = {}
                            local id, name = strmatch(source, "^|cff27ffff(%d+) (.+)|r")
                            t[source]["encounterId"] = tonumber(id)
                            t[source]["encounterName"] = name
                        else
                            -- move npcId
                            local name = string.gsub(source, "^* ", "")
                            name = string.gsub(name, "^%d+ ", "")
                            if ISC_NpcId[instanceId] and ISC_NpcId[instanceId][name] then
                                t[source]["npcId"] = tonumber(ISC_NpcId[instanceId][name])
                                t[source]["npcName"] = name
                            end
                        end
                    end
                end
            end

            ISC_Data = data_temp
            ISC_Spell = spell_temp
            ISC_AuraDesc = nil
            ISC_NpcId = nil

            -- process spells
            local spellDescriptionTooltip = CreateFrame("GameTooltip", "ISCMigrationSpellDescriptionTooltip", UIParent, "GameTooltipTemplate")
            spellDescriptionTooltip:SetFrameLevel(UIParent:GetFrameLevel() + 1)
            spellDescriptionTooltip:SetOwner(UIParent, "ANCHOR_NONE")

            for spellId, t in pairs(spell_temp) do
                local name, _, icon, _, _, _, castTime = GetSpellInfo(spellId)
                t["name"] = name or "INVALID"
                t["icon"] = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                t["castTime"] = castTime or 0

                t["desc"] = ""
                if name then
                    spellDescriptionTooltip:ClearLines()
                    spellDescriptionTooltip:SetHyperlink("spell:" .. spellId)
                    for i = 1, spellDescriptionTooltip:GetNumRegions() do
                        local region = select(i, spellDescriptionTooltip:GetRegions())
                        if region:GetObjectType() == "FontString" and select(3, region:GetTextColor()) == 0 then
                            t["desc"] = region:GetText() or ""
                            break
                        end
                    end
                end

                if t["castTime"] == 0 then
                    t["castType"] = "instant"
                    t["castTime"] = nil
                else
                    t["castType"] = "cast"
                end
            end
        end

        -------------------------------------------------------------

        -- ignore (don't ask again)
        if type(ISC_Ignore) ~= "table" then
            ISC_Ignore = {
                -- [englishInstanceName] = "englishInstanceName",
            }
        end

        local function MergeData(target, source)
            for key, value in pairs(source) do
                if type(value) == "table" and type(target[key]) == "table" then
                    MergeData(target[key], value)
                elseif target[key] == nil then
                    target[key] = value
                end
            end
        end

        local normalizedData = {}
        for instanceKey, instance in pairs(ISC_Data) do
            if type(instance) == "table" then
                local storedName = type(instance.name) == "string" and instance.name or tostring(instanceKey)
                local englishName = ISC.instanceNames[storedName] or storedName
                instance.name = englishName

                if normalizedData[englishName] then
                    normalizedData[englishName].enabled = normalizedData[englishName].enabled or instance.enabled
                    MergeData(normalizedData[englishName].data, instance.data or {})
                else
                    normalizedData[englishName] = instance
                    normalizedData[englishName].data = normalizedData[englishName].data or {}
                end
            end
        end
        ISC_Data = normalizedData

        local normalizedIgnore = {}
        for instanceKey, instanceName in pairs(ISC_Ignore) do
            local storedName = type(instanceName) == "string" and instanceName or tostring(instanceKey)
            local englishName = ISC.instanceNames[storedName] or storedName
            normalizedIgnore[englishName] = englishName
        end
        ISC_Ignore = normalizedIgnore

        ISC:Fire("AddonLoaded")
    end
end

ISC:RegisterCallback("UpdateScale", "Collector_UpdateScale", function()
    P:SetRelativeScale(ISC_Config.scale)
    P:SetEffectiveScale(InstanceSpellCollectorFrame)
    P:SetEffectiveScale(InstanceSpellCollectorDialog)
    InstanceSpellCollectorDialog:UpdatePixelPerfect()
    P:SetEffectiveScale(ISCTooltip)
    ISCTooltip:UpdatePixelPerfect()
end)

-------------------------------------------------
-- slash command
-------------------------------------------------
SLASH_ISC1 = "/isc"
function SlashCmdList.ISC(msg, editbox)
    -- local command, rest = msg:match("^(%S*)%s*(.-)$")
    InstanceSpellCollectorFrame:Show()
end
