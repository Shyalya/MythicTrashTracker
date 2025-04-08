--------------------------------------------------------------------------------
-- MinimapButton.lua
-- Minimap-Button mit Dropdown-Menü, Progress-Sound und Buff-Tracker.
--------------------------------------------------------------------------------

-- Globale Variablen für Progress-Sound und Buff-Tracker
local OPTIONS = {
    soundEnabled = true, -- Progress-Sound aktiviert/deaktiviert
    trackBuffs = true    -- Buff-Tracking aktiviert/deaktiviert
}

-- Funktion zum Berechnen der neuen Position entlang der Minimap
local function ClampToMinimap(self)
    local xpos, ypos = self:GetCenter()
    local mX, mY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()

    xpos = (xpos - mX) / scale
    ypos = (ypos - mY) / scale

    local angle = math.atan2(ypos, xpos)
    local radius = (Minimap:GetWidth() / 2) + 10 -- Abstand außerhalb der Minimap (10px)

    xpos = math.cos(angle) * radius
    ypos = math.sin(angle) * radius

    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", xpos * scale, ypos * scale)
end

--------------------------------------------------------------------------------
-- Progress-Sound abspielen
--------------------------------------------------------------------------------
local function PlayProgressSound()
    if OPTIONS.soundEnabled then
        PlaySoundFile("Interface\\AddOns\\MythicTrashTracker\\Sounds\\progress.ogg", "Master")
    end
end

--------------------------------------------------------------------------------
-- Dropdown-Menü erstellen
--------------------------------------------------------------------------------
function CreateDropdownMenu()
    local menuFrame = CreateFrame("Frame", "MythicTrashTrackerMenu", UIParent, "UIDropDownMenuTemplate")

    local menuItems = {
        {
            text = "Sound on/off",
            isNotRadio = true,
            checked = function() return OPTIONS.soundEnabled end,
            func = function()
                OPTIONS.soundEnabled = not OPTIONS.soundEnabled
                print("|cFFFFA500[MythicTrashTracker]: Progress-Sound " .. (OPTIONS.soundEnabled and "aktiviert" or "deaktiviert") .. ".")
            end
        },
        {
            text = "Buff-Tracking on/off",
            isNotRadio = true,
            checked = function() return OPTIONS.trackBuffs end,
            func = function()
                OPTIONS.trackBuffs = not OPTIONS.trackBuffs
                print("|cFFFFA500[MythicTrashTracker]: Buff-Tracking " .. (OPTIONS.trackBuffs and "aktiviert" or "deaktiviert") .. ".")
            end
        },
        {
            text = "Options",
            func = function()
                if OpenOptionsWindow then
                    OpenOptionsWindow() -- Ruft die Funktion zum Öffnen des Optionsmenüs auf
                else
                    print("|cFFFF0000[MythicTrashTracker]: OpenOptionsWindow ist nicht definiert.")
                end
            end
        },
        {
            text = "Close",
            func = function()
                CloseDropDownMenus()
            end
        }
    }

    EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU")
end

--------------------------------------------------------------------------------
-- Minimap-Button erstellen und initialisieren
--------------------------------------------------------------------------------
function InitializeMinimapButton()
    print("InitializeMinimapButton wird ausgeführt...")

    local minimapButton = CreateFrame("Button", "MythicTrashTrackerMinimapButton", UIParent)
    minimapButton:SetSize(24, 24)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", 0, -80)

    minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_Skull_01")
    minimapButton.icon:SetSize(24, 24)
    minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER")

    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ClampToMinimap(self)
    end)

    minimapButton:RegisterForClicks("AnyUp")
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            CreateDropdownMenu()
        elseif button == "LeftButton" then
            PlayProgressSound()
            print("|cFF00FF00[MythicTrashTracker]: Linksklick erkannt.")
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("MythicTrashTracker", 1, 1, 1)
        GameTooltip:AddLine("Linksklick halten: Verschieben entlang der Minimap", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Linksklick: Progress-Sound abspielen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Rechtsklick: Menü anzeigen", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

InitializeMinimapButton()
