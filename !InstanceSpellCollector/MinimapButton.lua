local _, ISC = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local launcher = LDB:NewDataObject("InstanceSpellCollector", {
    type = "launcher",
    text = "Instance Spell Collector",
    icon = "Interface\\Icons\\INV_Sigil_UlduarAll",
    OnClick = function(_, button)
        if button == "LeftButton" then
            InstanceSpellCollectorFrame:Show()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:ClearLines()
        tooltip:AddDoubleLine("Instance Spell Collector", ISC.version or "", 1, 0.82, 0, 1, 0.82, 0)
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffeda55fLeft-Click|r to show the collector.", 0.2, 1, 0.2)
    end,
})

ISC:RegisterCallback("AddonLoaded", "MinimapButton_AddonLoaded", function()
    if type(ISC_Config.minimap) ~= "table" then
        ISC_Config.minimap = {hide = false}
    end
    LDBIcon:Register("InstanceSpellCollector", launcher, ISC_Config.minimap)
end)
