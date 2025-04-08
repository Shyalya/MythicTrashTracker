-- MythicTrashTracker.lua
print("MythicTrashTracker loaded!")
DEBUG = true

function DebugPrint(msg)
    if DEBUG then
        print("|cFFFFA500[Debug]: " .. tostring(msg))
    end
end

local CHECK_BUFFS_ENABLED = true

--------------------------------------------------------------------------------
-- Globale Variablen
--------------------------------------------------------------------------------

local RequiredBuffGroups = {
    { "Mythic Aura of Preservation", name = "Mythic Aura of Preservation" }, -- Gruppe 1
    { "Mythic Aura of Shielding", name = "Mythic Aura of Shielding" },       -- Gruppe 2
    { "Mythic Aura of Berserking", name = "Mythic Aura of Berserking" },     -- Gruppe 3
    { "Mythic Aura of Resistance", name = "Mythic Aura of Resistance" },     -- Gruppe 4
    { "Mythic Aura of the Hammer", name = "Mythic Aura of the Hammer" }      -- Gruppe 5
}
local OPTIONS = {
    trackBuffs = true, -- Buff-Tracking aktivieren
    soundEnabled = true, -- Progress-Sound aktivieren/deaktivieren
    selectedSound = "Sound\\Interface\\LevelUp.wav", -- Standard-Sound von WoW
    progressBarWidth = 200, -- Standardbreite des Fortschrittsbalkens
    progressBarHeight = 20,
    language = "en" -- Standardmäßig Englisch
}

local progressBar, missingBuffText
local MyAddon = MyAddon or {}
MyAddon.cumulativeKills = 0
MyAddon.totalRequiredKills = 0
MyAddon.activeBossList = {}
MyAddon.currentBossIndex = 1
local isInInstance = false -- Status: Spieler in Instanz

-- Globale Optionen erweitern
if not OPTIONS.buffGroups then
    OPTIONS.buffGroups = {}
    for i, group in ipairs(RequiredBuffGroups) do
        OPTIONS.buffGroups[i] = {}
        for _, buffID in ipairs(group) do
            OPTIONS.buffGroups[i][buffID] = true -- Standardmäßig alle Buffs aktiv
        end
    end
    DebugPrint("OPTIONS.buffGroups erfolgreich initialisiert.")
end

DebugPrint("OPTIONS.buffGroups initialisiert: " .. tostring(#OPTIONS.buffGroups))

--------------------------------------------------------------------------------
-- Minimap-Button erstellen und initialisieren
--------------------------------------------------------------------------------
function InitializeMinimapButton()
    -- Code für Minimap-Button, der ClampToMinimap verwendet
end

function ClampToMinimap(self)
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
-- Globale Funktionen
--------------------------------------------------------------------------------

function PlayProgressSound()
    if OPTIONS.soundEnabled and OPTIONS.selectedSound then
        PlaySoundFile(OPTIONS.selectedSound, "Master")
        DebugPrint("Progress-Sound abgespielt: " .. OPTIONS.selectedSound)
    else
        DebugPrint("Progress-Sound ist deaktiviert oder kein Sound ausgewählt.")
    end
end
local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")
addonLoadedFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MythicTrashTracker" then
        DebugPrint("Addon MythicTrashTracker vollständig geladen.")

        -- Überprüfen, ob der Spieler in einer Instanz ist und die Daten geladen werden können
        if not CheckInstanceAndLoadData() then
            DebugPrint("AddOn wird nicht geladen, da der Spieler nicht in einer Instanz ist.")
            return
        end

        -- Initialisiere die Instanzdaten
        InitializeInstanceProgress()
    end
end)

function CheckInstanceAndLoadData()
    local instanceName, instanceType = GetInstanceInfo()
    DebugPrint("CheckInstanceAndLoadData aufgerufen. Instanzname: " .. tostring(instanceName) .. ", Instanztyp: " .. tostring(instanceType))

    -- Überprüfen, ob der Spieler in einer Instanz ist
    if instanceType ~= "party" and instanceType ~= "raid" then
        DebugPrint("Spieler ist nicht in einer Instanz. AddOn wird nicht geladen.")
        return false -- Spieler ist nicht in einer Instanz
    end

    -- Spieler ist in einer Instanz
    DebugPrint("Spieler ist in einer Instanz. Lade entsprechende Daten.")

    if instanceType == "party" then
        if not InstanceDungeonsData then
            DebugPrint("Lade Dungeon-Daten...")
            -- Hier die Datei `InstanceDungeonsData.lua` laden
            LoadAddOn("InstanceDungeonsData") -- Beispiel: AddOn-Daten laden
        end
    elseif instanceType == "raid" then
        if not InstanceRaidsData then
            DebugPrint("Lade Raid-Daten...")
            -- Hier die Datei `InstanceRaidsData.lua` laden
            LoadAddOn("InstanceRaidsData") -- Beispiel: AddOn-Daten laden
        end
    end

    return true -- Spieler ist in einer Instanz und Daten wurden geladen
end

local instanceChangeFrame = CreateFrame("Frame")
instanceChangeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceChangeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceChangeFrame:SetScript("OnEvent", function(self, event, ...)
    DebugPrint("Event ausgelöst: " .. event)
    if CheckInstanceAndLoadData() then
        InitializeInstanceProgress()
    else
        ResetProgressBars()
    end
end)

--------------------------------------------------------------------------------
-- Optionen-Fenster erstellen
--------------------------------------------------------------------------------

-- Verfügbare WoW-Standard-Sounds
local AVAILABLE_SOUNDS = {
    { name = "Level Up", path = "Sound\\Interface\\LevelUp.wav" },
    { name = "Raid Warning", path = "Sound\\Interface\\RaidWarning.wav" },
    { name = "PVP Flag Taken", path = "Sound\\Interface\\PVPFlagTaken.wav" },
    { name = "Auction Window Open", path = "Sound\\Interface\\AuctionWindowOpen.wav" },
    { name = "Quest Added", path = "Sound\\Interface\\QuestAdded.wav" }
}

-- Funktion zum Öffnen des Optionen-Fensters
function OpenOptionsWindow()
    if MythicTrackerOptionsFrame then
        MythicTrackerOptionsFrame:Show()
    else
        CreateOptionsFrame()
        MythicTrackerOptionsFrame:Show()
    end
end

-- Funktion zum Aktualisieren der Fortschrittsbalken-Breite
function UpdateProgressBarWidth()
    if progressBar then
        progressBar:SetWidth(OPTIONS.progressBarWidth)
        print("|cFFFFA500[MythicTrashTracker]: Fortschrittsbalken-Breite aktualisiert: " .. OPTIONS.progressBarWidth .. "px.")
    end
end

-- Funktion zum Erstellen des Optionen-Fensters
function CreateOptionsFrame()
    if not OPTIONS.buffGroups then
        DebugPrint("Fehler: OPTIONS.buffGroups ist nil. Initialisiere erneut.")
        OPTIONS.buffGroups = {}
        for i, group in ipairs(RequiredBuffGroups) do
            OPTIONS.buffGroups[i] = {}
            for _, buffID in ipairs(group) do
                OPTIONS.buffGroups[i][buffID] = true -- Standardmäßig alle Buffs aktiv
            end
        end
    end

    if MythicTrackerOptionsFrame then
        return -- Frame bereits erstellt
    end

    local optionsFrame = CreateFrame("Frame", "MythicTrackerOptionsFrame", UIParent)
    optionsFrame:SetSize(500, 600) -- Breite und Höhe erhöht
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER")
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    optionsFrame:SetBackdropColor(0, 0, 0, 1)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    optionsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Schließen-Button hinzufügen
    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)

    -- Optionen-Menü Überschrift
    local dropdownTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    dropdownTitle:SetPoint("TOP", optionsFrame, "TOP", 0, -20)
    dropdownTitle:SetText(OPTIONS.language == "de" and "Optionen-Menü" or "Options Menu")

    -- Copyright-Hinweis
    local copyrightText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyrightText:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 10)
    copyrightText:SetText("|cFF00FF00MythicTrashTracker Beta Version 0.1 © 2025 by Shyalya")

    -- Buff Tracker Überschrift
    buffTrackerTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    buffTrackerTitle:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -60)
    buffTrackerTitle:SetText(OPTIONS.language == "de" and "Buff Tracker Optionen" or "Buff Tracker Options")

    -- Sprachauswahl Dropdown
    local languageDropdown = CreateFrame("Frame", "LanguageDropdown", optionsFrame, "UIDropDownMenuTemplate")
    languageDropdown:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -20, -60) -- Weiter nach rechts verschoben
    UIDropDownMenu_SetWidth(languageDropdown, 140) -- Breite um 10 Pixel reduziert
    UIDropDownMenu_SetText(languageDropdown, OPTIONS.language == "de" and "Sprache: Deutsch" or "Language: English")
    UIDropDownMenu_Initialize(languageDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "English"
        info.checked = OPTIONS.language == "en"
        info.func = function()
            OPTIONS.language = "en"
            UpdateLanguageTexts()
        end
        UIDropDownMenu_AddButton(info, level)

        info.text = "Deutsch"
        info.checked = OPTIONS.language == "de"
        info.func = function()
            OPTIONS.language = "de"
            UpdateLanguageTexts()
        end
        UIDropDownMenu_AddButton(info, level)
    end)


    -- Button zum Aktivieren/Deaktivieren aller Buff-Gruppen
    local toggleAllBuffsButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    toggleAllBuffsButton:SetSize(200, 25)
    toggleAllBuffsButton:SetPoint("TOPLEFT", buffTrackerTitle, "BOTTOMLEFT", 0, -120) -- Unter den Buff-Gruppen
    toggleAllBuffsButton:SetText(OPTIONS.language == "de" and "Alle Buffs an/aus" or "Toggle All Buffs")
    toggleAllBuffsButton:SetScript("OnClick", function()
        local allEnabled = true
        for i = 1, #RequiredBuffGroups do
            if not OPTIONS.buffGroups[i] then
                allEnabled = false
                break
            end
        end

        for i = 1, #RequiredBuffGroups do
            OPTIONS.buffGroups[i] = not allEnabled
        end

        UpdateBuffGroupButtons()
        --print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Alle Buff-Gruppen " or "All Buff Groups ") .. (allEnabled and (OPTIONS.language == "de" and "deaktiviert." or "disabled.") or (OPTIONS.language == "de" and "aktiviert." or "enabled.")))
    end)

-- Buff-Tracking Checkbox
local buffsCheckbox = CreateFrame("CheckButton", "BuffsCheckbox", optionsFrame, "UICheckButtonTemplate")
buffsCheckbox:SetPoint("LEFT", toggleAllBuffsButton, "RIGHT", 20, 0) -- Rechts neben dem Toggle All Buffs Button
buffsCheckbox:SetChecked(OPTIONS.trackBuffs)
local buffsCheckboxText = buffsCheckbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
buffsCheckboxText:SetPoint("LEFT", buffsCheckbox, "RIGHT", 5, 0)
buffsCheckboxText:SetText(OPTIONS.language == "de" and "Buff-Tracking aktivieren" or "Enable Buff Tracking")
buffsCheckbox:SetScript("OnClick", function(self)
    OPTIONS.trackBuffs = self:GetChecked()
    if OPTIONS.trackBuffs then
        EnableBuffChecker()
    else
        DisableBuffChecker()
    end
    print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Buff-Tracking " or "Buff Tracking ") .. (OPTIONS.trackBuffs and (OPTIONS.language == "de" and "aktiviert." or "enabled.") or (OPTIONS.language == "de" and "deaktiviert." or "disabled.")))

    -- Buff-Warnung zurücksetzen, wenn Buff-Tracking deaktiviert wird
    if not OPTIONS.trackBuffs and missingBuffText then
        missingBuffText:SetText("")
    end
end)

    -- Progress-Sound Checkbox
    local soundCheckbox = CreateFrame("CheckButton", "SoundCheckbox", optionsFrame, "UICheckButtonTemplate")
    soundCheckbox:SetPoint("TOPLEFT", toggleAllBuffsButton, "BOTTOMLEFT", 0, -20)
    soundCheckbox:SetChecked(OPTIONS.soundEnabled)
    local soundCheckboxText = soundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soundCheckboxText:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundCheckboxText:SetText(OPTIONS.language == "de" and "Progress-Sound aktivieren" or "Enable Progress Sound")
    soundCheckbox:SetScript("OnClick", function(self)
        OPTIONS.soundEnabled = self:GetChecked()
        print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Progress-Sound " or "Progress Sound ") .. (OPTIONS.soundEnabled and (OPTIONS.language == "de" and "aktiviert." or "enabled.") or (OPTIONS.language == "de" and "deaktiviert." or "disabled.")))
    end)

    -- Sound-Auswahl Dropdown
    local soundDropdown = CreateFrame("Frame", "SoundDropdown", optionsFrame, "UIDropDownMenuTemplate")
    soundDropdown:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 0, -20)
    UIDropDownMenu_SetWidth(soundDropdown, 200)
    UIDropDownMenu_SetText(soundDropdown, OPTIONS.language == "de" and "Sound auswählen" or "Select Sound")
    UIDropDownMenu_Initialize(soundDropdown, function(self, level)
        for _, sound in ipairs(AVAILABLE_SOUNDS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = sound.name
            info.func = function()
                OPTIONS.selectedSound = sound.path
                UIDropDownMenu_SetText(soundDropdown, sound.name)
                PlaySoundFile(sound.path, "Master")
                print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Ausgewählter Sound: " or "Selected Sound: ") .. sound.name)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Fortschrittsbalken-Breite Überschrift
    progressBarWidthTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    progressBarWidthTitle:SetPoint("TOPLEFT", soundDropdown, "BOTTOMLEFT", 0, -30) -- Mehr Platz nach unten
    progressBarWidthTitle:SetText(OPTIONS.language == "de" and "Balkenbreite" or "Bar Width")

    -- Schieberegler für Fortschrittsbalken-Breite
    local progressBarWidthSlider = CreateFrame("Slider", "ProgressBarWidthSlider", optionsFrame, "OptionsSliderTemplate")
    progressBarWidthSlider:SetPoint("TOPLEFT", progressBarWidthTitle, "BOTTOMLEFT", 0, -15)
    progressBarWidthSlider:SetMinMaxValues(100, 400)
    progressBarWidthSlider:SetValue(OPTIONS.progressBarWidth)
    progressBarWidthSlider:SetValueStep(10)
    progressBarWidthSlider:SetScript("OnValueChanged", function(self, value)
        OPTIONS.progressBarWidth = value
        UpdateProgressBarGroupSize()
    end)
    _G[progressBarWidthSlider:GetName() .. "Low"]:SetText("100")
    _G[progressBarWidthSlider:GetName() .. "High"]:SetText("400")
    _G[progressBarWidthSlider:GetName() .. "Text"]:SetText(OPTIONS.language == "de" and "Breite" or "Width")

    -- Fortschrittsbalken-Höhe Überschrift
    local progressBarHeightTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    progressBarHeightTitle:SetPoint("TOPLEFT", progressBarWidthSlider, "BOTTOMLEFT", 0, -40) -- Mehr Platz nach unten
    progressBarHeightTitle:SetText(OPTIONS.language == "de" and "Balkenhöhe" or "Bar Height")

    -- Schieberegler für Fortschrittsbalken-Höhe
    local progressBarHeightSlider = CreateFrame("Slider", "ProgressBarHeightSlider", optionsFrame, "OptionsSliderTemplate")
    progressBarHeightSlider:SetPoint("TOPLEFT", progressBarHeightTitle, "BOTTOMLEFT", 0, -15) -- Abstand zur Überschrift
    progressBarHeightSlider:SetMinMaxValues(10, 50)
    progressBarHeightSlider:SetValue(OPTIONS.progressBarHeight)
    progressBarHeightSlider:SetValueStep(1)
    progressBarHeightSlider:SetScript("OnValueChanged", function(self, value)
        OPTIONS.progressBarHeight = value
        UpdateProgressBarGroupSize()
    end)
    _G[progressBarHeightSlider:GetName() .. "Low"]:SetText("10")
    _G[progressBarHeightSlider:GetName() .. "High"]:SetText("50")
    _G[progressBarHeightSlider:GetName() .. "Text"]:SetText(OPTIONS.language == "de" and "Höhe" or "Height")



    -- Checkboxen für Buff-Gruppen in einem Raster
    local buffGroupButtons = {}
    local numColumns = 2 -- Anzahl der Spalten
    local columnWidth = 250 -- Breite der Spalten
    local rowHeight = 30 -- Höhe der Reihen

    for i, group in ipairs(RequiredBuffGroups) do
        local column = (i - 1) % numColumns -- Spaltenindex (0-basiert)
        local row = math.floor((i - 1) / numColumns) -- Reihenindex (0-basiert)

        local button = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", buffTrackerTitle, "BOTTOMLEFT", column * columnWidth, -10 - row * rowHeight)
        button:SetChecked(OPTIONS.buffGroups[i])
        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        buttonText:SetPoint("LEFT", button, "RIGHT", 5, 0)
        buttonText:SetText(group.name) -- Buff-Gruppenname anzeigen
        button:SetScript("OnClick", function(self)
            OPTIONS.buffGroups[i] = self:GetChecked()
            print("|cFFFFA500[MythicTrashTracker]: " .. group.name .. (self:GetChecked() and " aktiviert." or " deaktiviert."))
        end)
        table.insert(buffGroupButtons, button)
    end

    -- Funktion zum Aktualisieren der Buttons
    function UpdateBuffGroupButtons()
        for i, button in ipairs(buffGroupButtons) do
            button:SetChecked(OPTIONS.buffGroups[i])
        end
    end



    optionsFrame:Hide() -- Standardmäßig versteckt
end

--------------------------------------------------------------------------------
-- Minimap-Button erstellen und initialisieren
--------------------------------------------------------------------------------
function InitializeMinimapButton()
    local minimapButton = CreateFrame("Button", "MythicTrashTrackerMinimapButton", UIParent)
    minimapButton:SetSize(24, 24)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", 0, -80) -- Korrekt: Minimap ist das Ankerobjekt, nicht der Button selbst

    minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_Skull_01")
    minimapButton.icon:SetSize(24, 24)
    minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER") -- Die Textur wird relativ zum Button zentriert

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
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("MythicTrashTracker", 1, 1, 1)
        GameTooltip:AddLine(OPTIONS.language == "de" and "Linksklick halten: Verschieben entlang der Minimap" or "Hold Left Click: Drag along the Minimap", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(OPTIONS.language == "de" and "Rechtsklick: Menü anzeigen" or "Right Click: Show menu", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

InitializeMinimapButton()
--------------------------------------------------------------------------------
-- Dropdown-Menü erstellen
--------------------------------------------------------------------------------
function CreateDropdownMenu()
    local menuFrame = CreateFrame("Frame", "MythicTrashTrackerMenu", UIParent, "UIDropDownMenuTemplate")

    local menuItems = {
        {
            text = OPTIONS.language == "de" and "Alle Buffs an/aus" or "Toggle All Buffs",
            func = function()
                local allEnabled = true
                for i = 1, #RequiredBuffGroups do
                    if not OPTIONS.buffGroups[i] then
                        allEnabled = false
                        break
                    end
                end

                for i = 1, #RequiredBuffGroups do
                    OPTIONS.buffGroups[i] = not allEnabled
                end

                UpdateBuffGroupButtons()
                print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Alle Buff-Gruppen " or "All Buff Groups ") .. (allEnabled and (OPTIONS.language == "de" and "deaktiviert." or "disabled.") or (OPTIONS.language == "de" and "aktiviert." or "enabled.")))
            end
        },
        {
            text = OPTIONS.language == "de" and "Sound an/aus" or "Sound on/off",
            isNotRadio = true,
            checked = function() return OPTIONS.soundEnabled end,
            func = function()
                OPTIONS.soundEnabled = not OPTIONS.soundEnabled
                UpdateSoundUI()
            end
        },
        {
            text = OPTIONS.language == "de" and "Buff-Tracking an/aus" or "Buff-Tracking on/off",
            isNotRadio = true,
            checked = function() return OPTIONS.trackBuffs end,
            func = function()
                OPTIONS.trackBuffs = not OPTIONS.trackBuffs
                if OPTIONS.trackBuffs then
                    EnableBuffChecker()
                else
                    DisableBuffChecker()
                end
                UpdateBuffTrackingUI()
            end
        },
        {
            text = OPTIONS.language == "de" and "Optionen" or "Options",
            func = function()
                if OpenOptionsWindow then
                    OpenOptionsWindow()
                else
                    print("|cFFFF0000[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "OpenOptionsWindow ist nicht definiert." or "OpenOptionsWindow is not defined."))
                end
            end
        },
        {
            text = OPTIONS.language == "de" and "Schließen" or "Close",
            func = function()
                CloseDropDownMenus()
            end
        }
    }

    EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU")
end

--------------------------------------------------------------------------------
-- 1. Fortschrittsbalken erstellen
--------------------------------------------------------------------------------

local progressBarGroup = {} -- Gruppe für alle Fortschrittsbalken
local progressBarContainer -- Container-Frame für die Gruppe

-- Fortschrittsbalken-Gruppe erstellen
function CreateProgressBarGroup()
    if not progressBarContainer then
        progressBarContainer = CreateFrame("Frame", "MythicTrashTrackerProgressBarContainer", UIParent)
        progressBarContainer:SetSize(200, 20) -- Standardgröße
        progressBarContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        progressBarContainer:SetMovable(true)
        progressBarContainer:EnableMouse(true)
        progressBarContainer:RegisterForDrag("LeftButton")
        progressBarContainer:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() then
                self:StartMoving()
            end
        end)
        progressBarContainer:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)

        -- Hintergrund für die Gruppe
        local bg = progressBarContainer:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(progressBarContainer)
        bg:SetTexture(0, 0, 0, 0.5) -- Hintergrundfarbe
        progressBarContainer.bg = bg

        -- Buff-Warnungstext oberhalb des Containers
        missingBuffText = progressBarContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        missingBuffText:SetPoint("BOTTOM", progressBarContainer, "TOP", 0, 10)
        missingBuffText:SetText("")
        missingBuffText:SetTextColor(1, 0, 0, 1) -- Rot
        missingBuffText:Show() -- Sicherstellen, dass der Text sichtbar ist
        DebugPrint("MissingBuffText an progressBarContainer gebunden.")
    end

    progressBarContainer:Show() -- Sicherstellen, dass der Container sichtbar ist
end

-- Fortschrittsbalken für jeden Boss erstellen
function CreateBossProgressBars()
    DebugPrint("CreateBossProgressBars aufgerufen.")

    if not MyAddon.activeBossList or #MyAddon.activeBossList == 0 then
        DebugPrint("Keine aktiven Bosse gefunden.")
        return
    end

    -- Lösche vorhandene Balken, um doppelte Einträge zu vermeiden
    for _, bar in ipairs(progressBarGroup) do
        bar:Hide()
        bar:ClearAllPoints()
        bar:SetParent(nil)
    end
    progressBarGroup = {}

    for i, boss in ipairs(MyAddon.activeBossList) do
        DebugPrint("Boss " .. i .. ": " .. boss.bossName .. ", Required Kills: " .. boss.requiredKills)
        local bar = CreateFrame("StatusBar", "MythicTrashTrackerProgressBar" .. i, progressBarContainer)
        bar:SetWidth(OPTIONS.progressBarWidth)
        bar:SetHeight(OPTIONS.progressBarHeight)
        bar:SetPoint("TOP", progressBarContainer, "TOP", 0, -(i - 1) * (OPTIONS.progressBarHeight + 5))
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0, boss.requiredKills or 100)
        bar:SetValue(0)
        bar:SetStatusBarColor(1, 0, 0)

        -- Text für den Fortschrittsbalken
        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        bar.text:SetText(string.format("0/%d - %s", boss.requiredKills or 0, boss.bossName))

        progressBarGroup[i] = bar
    end

    -- Container-Größe anpassen
    UpdateProgressBarGroupSize()
end

function UpdateProgressBarGroupSize()
    if progressBarContainer then
        -- Größe des Containers anpassen
        progressBarContainer:SetWidth(OPTIONS.progressBarWidth)
        progressBarContainer:SetHeight(#progressBarGroup * (OPTIONS.progressBarHeight + 5))

        -- Größe der einzelnen Balken anpassen
        for i, bar in ipairs(progressBarGroup) do
            bar:SetWidth(OPTIONS.progressBarWidth)
            bar:SetHeight(OPTIONS.progressBarHeight)
            bar:ClearAllPoints()
            bar:SetPoint("TOP", progressBarContainer, "TOP", 0, -(i - 1) * (OPTIONS.progressBarHeight + 5))
        end

        DebugPrint("Fortschrittsbalken-Gruppe aktualisiert: Breite = " .. OPTIONS.progressBarWidth .. ", Höhe = " .. OPTIONS.progressBarHeight)
    end
end

--------------------------------------------------------------------------------
-- 2. Instanz-Daten initialisieren
--------------------------------------------------------------------------------
function InitializeInstanceProgress()
    local instanceName, instanceType = GetInstanceInfo()
    DebugPrint("InitializeInstanceProgress aufgerufen. Instanzname: " .. tostring(instanceName) .. ", Instanztyp: " .. tostring(instanceType))

    -- Überprüfen, ob der Spieler in einer Instanz ist
    if instanceType ~= "party" and instanceType ~= "raid" then
        DebugPrint("Nicht in einer Instanz. Fortschrittsbalken ausgeblendet.")
        if progressBarContainer then
            progressBarContainer:Hide()
        end
        MyAddon.activeBossList = {}
        isInInstance = false
        return
    end

    isInInstance = true

    -- Überprüfen, ob `InstanceDungeonsData` geladen ist
    if not InstanceDungeonsData then
        DebugPrint("Fehler: InstanceDungeonsData ist nil.")
        MyAddon.activeBossList = {}
        return
    end

    -- Überprüfen, ob die aktuelle Instanz in den Daten vorhanden ist
    if not InstanceDungeonsData[instanceName] then
        DebugPrint("Keine Dungeon-Daten für die Instanz gefunden: " .. tostring(instanceName))
        MyAddon.activeBossList = {}
        return
    end

    -- Instanzdaten laden
    MyAddon.activeBossList = InstanceDungeonsData[instanceName] or {}
    DebugPrint("Bossliste für die Instanz geladen: " .. tostring(instanceName))
    for i, boss in ipairs(MyAddon.activeBossList) do
        DebugPrint("Boss " .. i .. ": " .. boss.bossName .. ", Required Kills: " .. boss.requiredKills)
    end

    -- Fortschrittsbalken erstellen und aktualisieren
    CreateBossProgressBars()
    UpdateProgress()

    -- Sicherstellen, dass der Container sichtbar ist
    if progressBarContainer then
        progressBarContainer:Show()
    end
end

--------------------------------------------------------------------------------
-- 3. Buff-Prüfungsfunktion
--------------------------------------------------------------------------------
function CheckBuffs()
    if not CHECK_BUFFS_ENABLED or not isInInstance then
        DebugPrint("Buff-Prüfung ist deaktiviert oder nicht in einer Instanz.")
        if missingBuffText then
            missingBuffText:SetText("") -- Buff-Warnung zurücksetzen
        end
        return
    end

    local allGroupsPresent = true

    for i, buffGroup in ipairs(RequiredBuffGroups) do
        if OPTIONS.buffGroups[i] then -- Nur aktivierte Gruppen prüfen
            local groupFound = false
            DebugPrint("Prüfe Buff-Gruppe: " .. (buffGroup.name or "Unbenannt"))
            for _, buffName in ipairs(buffGroup) do
                if OPTIONS.buffGroups[i][buffName] then -- Nur aktivierte Buffs prüfen
                    DebugPrint("Prüfe Buff-Name: " .. buffName)
                    for j = 1, 40 do
                        local name = UnitBuff("player", j)
                        if name then
                            DebugPrint("Gefundener Buff: " .. name)
                        end
                        if name == buffName then
                            DebugPrint("Buff gefunden: " .. buffName)
                            groupFound = true
                            break
                        end
                    end
                    if groupFound then break end
                end
            end

            if not groupFound then
                allGroupsPresent = false
                DebugPrint("Keine Buffs aus der Gruppe gefunden: " .. (buffGroup.name or "Unbenannt"))
            end
        end
    end

    if not allGroupsPresent then
        local warningText = OPTIONS.language == "de" and "Du hast deine MythicBuffs vergessen!" or "You forgot your MythicBuffs!"
        DebugPrint("Setze missingBuffText: " .. warningText)
        if missingBuffText then
            missingBuffText:SetText(warningText)
        end

        if OPTIONS.soundEnabled then
            PlaySoundFile("Sound\\Interface\\RaidWarning.wav", "Master")
        end
    else
        DebugPrint("Alle Buffs vorhanden.")
        if missingBuffText then
            missingBuffText:SetText("") -- Buff-Warnung zurücksetzen
        end
    end
end

--------------------------------------------------------------------------------
-- 4. Regelmäßige Buff-Überprüfung
--------------------------------------------------------------------------------
local buffCheckerFrame = CreateFrame("Frame")

function EnableBuffChecker()
    buffCheckerFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer > 15 then -- Alle 15 Sekunden prüfen
            DebugPrint("Buff-Prüfung wird ausgeführt.")
            CheckBuffs()
            self.timer = 0
        end
    end)
    DebugPrint("Buff-Checker aktiviert.")
end

function DisableBuffChecker()
    buffCheckerFrame:SetScript("OnUpdate", nil)
    DebugPrint("Buff-Checker deaktiviert.")
end

-- Initialisierung basierend auf der Option
if OPTIONS.trackBuffs then
    EnableBuffChecker()
else
    DisableBuffChecker()
end

--------------------------------------------------------------------------------
-- 5. Combat Log Event für Kills
--------------------------------------------------------------------------------
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatFrame:SetScript("OnEvent", function(self, event, ...)
    DebugPrint("COMBAT_LOG_EVENT_UNFILTERED ausgelöst.") -- Debug-Ausgabe
    ProcessKill(...)
end)
--------------------------------------------------------------------------------
-- 6. Fortschrittsbalken-Funktionen
--------------------------------------------------------------------------------

function ProcessKill(timestamp, subEvent, ...)
    -- Überprüfe, ob das Event ein UNIT_DIED ist
    if subEvent ~= "UNIT_DIED" then
        DebugPrint("Ignoriere SubEvent: " .. tostring(subEvent))
        return
    end

    -- Erhöhe die Kill-Zählung
    MyAddon.cumulativeKills = MyAddon.cumulativeKills + 1
    DebugPrint("Mob getötet. Gesamtanzahl Kills: " .. MyAddon.cumulativeKills)

    -- Fortschrittsbalken aktualisieren
    UpdateProgress()
end

function UpdateProgress()
    for i, bar in ipairs(progressBarGroup) do
        local boss = MyAddon.activeBossList[i]
        if boss then
            local kills = MyAddon.cumulativeKills
            local requiredKills = boss.requiredKills or 100
            local fraction = kills / requiredKills

            -- Fortschrittsbalken aktualisieren
            bar:SetValue(kills)
            bar:SetStatusBarColor(1 - fraction, fraction, 0) -- Rot zu Grün

            -- Text korrekt formatieren
            local progressText = string.format("%d/%d - %s", kills, requiredKills, boss.bossName)
            bar.text:SetText(progressText)

            -- Debugging: Fortschrittsbalken-Status ausgeben
            DebugPrint("Aktualisiere Fortschrittsbalken " .. i .. ": " .. progressText)
        else
            DebugPrint("Kein Boss für Fortschrittsbalken " .. i)
        end
    end
end

function ResetProgressForNextBoss()
    if MyAddon.currentBossIndex < #MyAddon.activeBossList then
        MyAddon.currentBossIndex = MyAddon.currentBossIndex + 1
        local currentBoss = MyAddon.activeBossList[MyAddon.currentBossIndex]
        if not currentBoss then
            DebugPrint("Fehler: currentBoss ist nil.")
            return
        end
        MyAddon.totalRequiredKills = currentBoss.requiredKills or 0
        DebugPrint("Wechsel zu Boss '" .. tostring(currentBoss.bossName) .. "'. Ziel: " .. MyAddon.totalRequiredKills .. " Kills.")
        UpdateProgress()
    else
        DebugPrint("Alle Bosse abgeschlossen.")
        progressBar.text:SetText("Abgeschlossen!")
        progressBar:SetStatusBarColor(0, 1, 0) -- Grün für abgeschlossen
        PlayProgressSound()
    end
end

function ResetProgressBars()
    DebugPrint("Fortschrittsbalken und Daten werden zurückgesetzt.")
    
    -- Fortschrittsbalken entfernen
    for i, bar in ipairs(progressBarGroup) do
        DebugPrint("Entferne Fortschrittsbalken: " .. i)
        bar:Hide()
        bar:ClearAllPoints()
        bar:SetParent(nil) -- Entfernt den Balken vollständig aus dem UI-Parent
    end
    progressBarGroup = {} -- Leere die Liste der Balken

    -- Fortschrittsdaten zurücksetzen
    for _, boss in ipairs(MyAddon.activeBossList) do
        boss.kills = 0
    end
    MyAddon.activeBossList = {}
    MyAddon.currentBossIndex = 1
    MyAddon.cumulativeKills = 0
    MyAddon.totalRequiredKills = 0

    -- Buff-Warnung zurücksetzen
    if missingBuffText then
        missingBuffText:SetText("")
        DebugPrint("Buff-Warnung zurückgesetzt.")
    end

    DebugPrint("Fortschrittsbalken und Daten erfolgreich zurückgesetzt.")
end

--------------------------------------------------------------------------------
-- 7. AddOn Initialisierung
--------------------------------------------------------------------------------
CreateProgressBarGroup()

local instanceFrame = CreateFrame("Frame")
instanceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceFrame:SetScript("OnEvent", function(self, event, ...)
    DebugPrint("PLAYER_ENTERING_WORLD ausgelöst.")
    InitializeInstanceProgress()
end)

local instanceLeaveFrame = CreateFrame("Frame")
instanceLeaveFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceLeaveFrame:SetScript("OnEvent", function(self, event, ...)
    DelayedExecution(1, function() -- 1 Sekunde Verzögerung
        local instanceName, instanceType = GetInstanceInfo()
        if instanceType ~= "party" and instanceType ~= "raid" then
            DebugPrint("Instanz verlassen. Fortschrittsbalken werden zurückgesetzt.")
            ResetProgressBars()
        end
    end)
end)

CreateBossProgressBars()
UpdateProgress()
InitializeInstanceProgress()

local instanceFrame = CreateFrame("Frame")
instanceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceFrame:SetScript("OnEvent", function(self, event, ...)
    InitializeInstanceProgress()
end)

instanceLeaveFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
instanceLeaveFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEAVING_WORLD" then
        DebugPrint("Spieler verlässt die Welt. Fortschrittsbalken werden zurückgesetzt.")
        ResetProgressBars()
    end
end)

-- Lade die Dungeon-Daten

if not MyAddon.activeBossList or #MyAddon.activeBossList == 0 then
    DebugPrint("MyAddon.activeBossList ist leer oder ungültig.")
else
    DebugPrint("MyAddon.activeBossList erfolgreich initialisiert.")
    for index, boss in ipairs(MyAddon.activeBossList) do
        DebugPrint("Boss " .. index .. ": " .. tostring(boss.bossName) .. " (Required Kills: " .. tostring(boss.requiredKills) .. ")")
    end
end

function UpdateLanguageTexts()
    if MythicTrackerOptionsFrame then
        -- Buff Tracker Titel aktualisieren
        if buffTrackerTitle then
            buffTrackerTitle:SetText(OPTIONS.language == "de" and "Buff Tracker Optionen" or "Buff Tracker Options")
        end

        -- Fortschrittsbalken-Breite Titel aktualisieren
        if progressBarWidthTitle then
            progressBarWidthTitle:SetText(OPTIONS.language == "de" and "Balkenbreite" or "Bar Width")
        end

        -- Fortschrittsbalken-Höhe Titel aktualisieren
        if progressBarHeightTitle then
            progressBarHeightTitle:SetText(OPTIONS.language == "de" and "Balkenhöhe" or "Bar Height")
        end

        -- Buff-Tracking Checkbox aktualisieren
        if buffsCheckboxText then
            buffsCheckboxText:SetText(OPTIONS.language == "de" and "Buff-Tracking aktivieren" or "Enable Buff Tracking")
        end

        -- Sound Checkbox aktualisieren
        if soundCheckboxText then
            soundCheckboxText:SetText(OPTIONS.language == "de" and "Progress-Sound aktivieren" or "Enable Progress Sound")
        end

        -- Sound Dropdown aktualisieren
        if soundDropdown then
            UIDropDownMenu_SetText(soundDropdown, OPTIONS.language == "de" and "Sound auswählen" or "Select Sound")
        end

        -- Toggle All Buffs Button aktualisieren
        if toggleAllBuffsButton then
            toggleAllBuffsButton:SetText(OPTIONS.language == "de" and "Alle Buffs an/aus" or "Toggle All Buffs")
        end

        -- Dropdown-Menü Titel aktualisieren
        if dropdownTitle then
            dropdownTitle:SetText(OPTIONS.language == "de" and "Optionen-Menü" or "Options Menu")
        end

        -- **Sprachauswahl Dropdown aktualisieren**
        if languageDropdown then
            UIDropDownMenu_SetText(languageDropdown, OPTIONS.language == "de" and "Sprache: Deutsch" or "Language: English")
        end
    end
end

function UpdateBuffTrackingUI()
    -- Buff-Tracking Checkbox aktualisieren
    if BuffsCheckbox then
        BuffsCheckbox:SetChecked(OPTIONS.trackBuffs)
    end

    -- Dropdown-Menü aktualisieren
    if languageDropdown then
        UIDropDownMenu_Initialize(languageDropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = OPTIONS.language == "de" and "Buff-Tracking an/aus" or "Buff-Tracking on/off"
            info.checked = OPTIONS.trackBuffs
            info.func = function()
                OPTIONS.trackBuffs = not OPTIONS.trackBuffs
                UpdateBuffTrackingUI()
                print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Buff-Tracking " or "Buff Tracking ") .. (OPTIONS.trackBuffs and (OPTIONS.language == "de" and "aktiviert." or "enabled") or (OPTIONS.language == "de" and "deaktiviert." or "disabled")))
            end
            UIDropDownMenu_AddButton(info, level)
        end)
    end
end

function UpdateSoundUI()
    -- Sound Checkbox aktualisieren
    if SoundCheckbox then
        SoundCheckbox:SetChecked(OPTIONS.soundEnabled)
    end

    -- Dropdown-Menü aktualisieren
    if languageDropdown then
        UIDropDownMenu_Initialize(languageDropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = OPTIONS.language == "de" and "Sound an/aus" or "Sound on/off"
            info.checked = OPTIONS.soundEnabled
            info.func = function()
                OPTIONS.soundEnabled = not OPTIONS.soundEnabled
                UpdateSoundUI()
                print("|cFFFFA500[MythicTrashTracker]: " .. (OPTIONS.language == "de" and "Progress-Sound " or "Progress Sound ") .. (OPTIONS.soundEnabled and "aktiviert." or "enabled") or (OPTIONS.language == "de" and "deaktiviert." or "disabled"))
            end
            UIDropDownMenu_AddButton(info, level)
        end)
    end
end

if not MythicTrackerOptionsFrame then
    CreateOptionsFrame()
end
UpdateLanguageTexts()

local function DelayedExecution(delay, func)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, func)
    else
        -- Fallback, falls C_Timer nicht verfügbar ist
        local frame = CreateFrame("Frame")
        frame.startTime = GetTime()
        frame:SetScript("OnUpdate", function(self, elapsed)
            if GetTime() - self.startTime >= delay then
                self:SetScript("OnUpdate", nil)
                func()
            end
        end)
    end
end

