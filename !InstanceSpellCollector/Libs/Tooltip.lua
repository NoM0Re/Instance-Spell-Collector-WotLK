local _, addon = ...
local P = addon.pixelPerfectFuncs

local accentColor = {0.6, 0.1, 0.1, 1}

-----------------------------------------
-- Tooltip
-----------------------------------------
local function CreateTooltip(name)
    local tooltip = CreateFrame("GameTooltip", name, UIParent, "ISCTooltipTemplate")
    tooltip:SetFrameLevel(UIParent:GetFrameLevel() + 1)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")

    local extraTip = CreateFrame("GameTooltip", name.."ExtraTip", tooltip, "ISCExtraTooltipTemplate")
    extraTip:SetFrameLevel(tooltip:GetFrameLevel() + 1)

    tooltip:SetScript("OnTooltipCleared", function()
        -- reset border color
        tooltip:SetBackdropBorderColor(unpack(accentColor))
    end)

    tooltip:SetScript("OnHide", function()
        -- SetX with invalid data may or may not clear the tooltip's contents.
        tooltip:ClearLines()
        extraTip:Hide()
    end)

    extraTip:SetScript("OnHide", function()
        extraTip:ClearLines()
    end)

    function tooltip:SetExtraTip(tip)
        if not tip then return end
        extraTip:SetOwner(tooltip:GetOwner(), "ANCHOR_NONE")
        extraTip:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -1)
        extraTip:AddLine(tip)
        extraTip:Show()
    end

    function tooltip:UpdatePixelPerfect()
        tooltip:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = P:Scale(1)})
        tooltip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        tooltip:SetBackdropBorderColor(unpack(accentColor))

        extraTip:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = P:Scale(1)})
        extraTip:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        extraTip:SetBackdropBorderColor(unpack(accentColor))
    end
end

CreateTooltip("ISCTooltip")
