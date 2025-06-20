-- MythicTrashTracker.lua
print("MythicTrashTracker loaded!")
DEBUG = false

function DebugPrint(msg)
    if DEBUG then
        print("|cFFFFA500[Debug]: " .. tostring(msg))
    end
end

-- 1. SavedVariables initialisieren (NICHT local!)
MythicTrashTrackerDB = MythicTrashTrackerDB or {}

-- 2. Standard-Optionen
local OPTIONS = {
    trackBuffs = true,
    soundEnabled = true,
    selectedSound = "Sound\\Interface\\LevelUp.wav",
    progressBarWidth = 200,
    progressBarHeight = 20,
    language = "en",
    buffGroups = nil -- wird beim Laden/Initialisieren gesetzt
}

-- 3. Buff-Gruppen Definition
local RequiredBuffGroups = {
    { "Mythic Aura of Preservation", name = "Mythic Aura of Preservation" },
    { "Mythic Aura of Shielding", name = "Mythic Aura of Shielding" },
    { "Mythic Aura of Berserking", name = "Mythic Aura of Berserking" },
    { "Mythic Aura of Resistance", name = "Mythic Aura of Resistance" },
    { "Mythic Aura of the Hammer", name = "Mythic Aura of the Hammer" }
}

-- 4. Optionen und BuffGroups beim Addon-Laden übernehmen
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon == "MythicTrashTracker" then
        -- Optionen übernehmen
        if MythicTrashTrackerDB.options then
            for k, v in pairs(MythicTrashTrackerDB.options) do
                OPTIONS[k] = v
            end
        end
        -- BuffGroups laden (einfache true/false-Liste)
        if MythicTrashTrackerDB.buffGroups then
            OPTIONS.buffGroups = {}
            for i = 1, #RequiredBuffGroups do
                OPTIONS.buffGroups[i] = MythicTrashTrackerDB.buffGroups[i] or false
            end
        end
        -- Falls nach dem Laden keine BuffGroups vorhanden sind, Standard initialisieren
        if not OPTIONS.buffGroups or #OPTIONS.buffGroups == 0 then
            OPTIONS.buffGroups = {}
            for i = 1, #RequiredBuffGroups do
                OPTIONS.buffGroups[i] = true
            end
            DebugPrint("BuffGroups auf Standardwerte gesetzt.")
        end
    end
end)

-- 6. Manueller Speicher-Button (kannst du überall im Code aufrufen)
function SaveMythicTrashTrackerOptions()
    MythicTrashTrackerDB.options = {}
    for k, v in pairs(OPTIONS) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            MythicTrashTrackerDB.options[k] = v
        end
    end
    -- BuffGroups als vollständige Liste speichern
    MythicTrashTrackerDB.buffGroups = {}
    for i = 1, #RequiredBuffGroups do
        MythicTrashTrackerDB.buffGroups[i] = OPTIONS.buffGroups[i] or false
    end
    print("|cFF00FF00[MythicTrashTracker]: Optionen wurden gespeichert!")
end
-- Liste der Gegner, die ignoriert werden sollen
local IgnoredEnemies = {
    "Rabbit",
    "Squirrel",
    "Frog",
    "Chicken",
    "Rat",
    "Deer",
    "Sheep",
    "Cat",
    "Dog",
    "Snake"
}

local progressBar, missingBuffText
local MyAddon = MyAddon or {}
MyAddon.cumulativeKills = 0
MyAddon.totalRequiredKills = 0
MyAddon.activeBossList = {}
MyAddon.currentBossIndex = 1
local isInInstance = false -- Status: Spieler in Instanz

-- Globale Optionen erweitern
--if not OPTIONS.buffGroups then
--    OPTIONS.buffGroups = {}
--    for i, group in ipairs(RequiredBuffGroups) do
--        OPTIONS.buffGroups[i] = {}
--        for _, buffID in ipairs(group) do
--            OPTIONS.buffGroups[i][buffID] = true -- Standardmäßig alle Buffs aktiv
 --       end
--    end
--    DebugPrint("OPTIONS.buffGroups erfolgreich initialisiert.")
--end

--DebugPrint("OPTIONS.buffGroups initialisiert: " .. tostring(#OPTIONS.buffGroups))

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
        UpdateBuffGroupButtons() -- <-- HIER!
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
     if OPTIONS.buffGroups == nil then
        OPTIONS.buffGroups = {}
        for i = 1, #RequiredBuffGroups do
            OPTIONS.buffGroups[i] = true
        end
        DebugPrint("BuffGroups auf Standardwerte gesetzt (OptionsFrame).")
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
    copyrightText:SetText("|cFF00FF00MythicTrashTracker Beta Version 0.2 © 2025 by Shyalya")

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

        UpdateBuffGroupButtons() -- <-- Auch hier!
    end)

-- Checkboxen für Buff-Gruppen in einem Raster
local buffGroupButtons = {}
local numColumns = 2
local columnWidth = 250
local rowHeight = 30

for i, group in ipairs(RequiredBuffGroups) do
    local column = (i - 1) % numColumns
    local row = math.floor((i - 1) / numColumns)

    local button = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", buffTrackerTitle, "BOTTOMLEFT", column * columnWidth, -10 - row * rowHeight)
    button:SetChecked(OPTIONS.buffGroups[i])
    local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    buttonText:SetPoint("LEFT", button, "RIGHT", 5, 0)
    buttonText:SetText(group.name)
    button:SetScript("OnClick", function(self)
        OPTIONS.buffGroups[i] = self:GetChecked()
        UpdateBuffGroupButtons()
    end)
    table.insert(buffGroupButtons, button)
end

function UpdateBuffGroupButtons()
    for i, button in ipairs(buffGroupButtons) do
        button:SetChecked(OPTIONS.buffGroups[i])
    end
end

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

    optionsFrame:Hide() -- Standardmäßig versteckt

    -- Speicher-Button
    local saveButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(120, 25)
    saveButton:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -20, 20)
    saveButton:SetText(OPTIONS.language == "de" and "Optionen speichern" or "Save Options")
    saveButton:SetScript("OnClick", function()
        SaveMythicTrashTrackerOptions()
    end)
    UpdateBuffGroupButtons()
end -- <--- Das ist das EINZIGE end für CreateOptionsFrame!
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

    local foundBossList = nil

    if instanceType == "party" and InstanceDungeonsData then
        for key, bossList in pairs(InstanceDungeonsData) do
            if string.find(instanceName, key, 1, true) then
                foundBossList = bossList
                break
            end
        end
    elseif instanceType == "raid" and InstanceRaidsData then
        for key, bossList in pairs(InstanceRaidsData) do
            if string.find(instanceName, key, 1, true) then
                foundBossList = bossList
                break
            end
        end
    end

    if not foundBossList then
        DebugPrint("Keine Instanzdaten für die Instanz gefunden: " .. tostring(instanceName))
        MyAddon.activeBossList = {}
        return
    end

    -- Instanzdaten laden
    MyAddon.activeBossList = foundBossList

    -- Fortschrittsdaten laden (NACH dem Setzen der Bossliste!)
    LoadProgressData()

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
            if not groupFound then
                allGroupsPresent = false
                DebugPrint("Keine Buffs aus der Gruppe gefunden: " .. (buffGroup.name or "Unbenannt"))
            end
        end
    end -- <--- Das ist das EINZIGE end für die for-Schleife!

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
    -- Manuelles Auslesen der Parameter
    local timestamp, subEvent, _, _, _, _, _, destGUID, destName = ...
    ProcessKill(timestamp, subEvent, destGUID, destName)
end)

-- 1. Fortschrittsdaten beim Addon-Laden wiederherstellen
function LoadProgressData()
    MyAddon.bossKills = {}
    if MythicTrashTrackerDB.progress and MythicTrashTrackerDB.progress.bossKills then
        -- Für jeden Boss den gespeicherten Wert übernehmen, sonst 0
        for i = 1, #MyAddon.activeBossList do
            MyAddon.bossKills[i] = MythicTrashTrackerDB.progress.bossKills[i] or 0
        end
        MyAddon.currentBossIndex = MythicTrashTrackerDB.progress.currentBossIndex or 1
        DebugPrint("Fortschrittsdaten geladen: Boss-Kills=" .. table.concat(MyAddon.bossKills, ", ") .. ", BossIndex=" .. MyAddon.currentBossIndex)
    else
        -- Initialisiere alle auf 0
        for i = 1, #MyAddon.activeBossList do
            MyAddon.bossKills[i] = 0
        end
        MyAddon.currentBossIndex = 1
    end
end

function SaveProgressData()
    -- Kopiere die Tabelle, nicht Referenz!
    local bossKillsCopy = {}
    for i = 1, #MyAddon.activeBossList do
        bossKillsCopy[i] = MyAddon.bossKills[i] or 0
    end
    MythicTrashTrackerDB.progress = {
        bossKills = bossKillsCopy,
        currentBossIndex = MyAddon.currentBossIndex,
    }
    DebugPrint("Fortschrittsdaten gespeichert.")
end

-- Kills für den jeweiligen Boss erhöhen
function ProcessKill(timestamp, subEvent, destGUID, destName)
    if subEvent ~= "PARTY_KILL" then
        DebugPrint("Ignoriere SubEvent: " .. tostring(subEvent))
        return
    end

    if IgnoredEnemies and destName then
        for _, ignoredName in ipairs(IgnoredEnemies) do
            if destName == ignoredName then
                DebugPrint("Ignoriere Gegner: " .. destName)
                return
            end
        end
    end

    -- Jeden Balken hochzählen!
    for i = 1, #MyAddon.activeBossList do
        MyAddon.bossKills[i] = (MyAddon.bossKills[i] or 0) + 1
        DebugPrint("Mob getötet. Boss " .. i .. " Kills: " .. MyAddon.bossKills[i])
    end

    SaveProgressData()
    UpdateProgress()
end

-- Fortschrittsbalken aktualisieren
function UpdateProgress()
    for i, bar in ipairs(progressBarGroup) do
        local boss = MyAddon.activeBossList[i]
        if boss then
            local kills = MyAddon.bossKills and MyAddon.bossKills[i] or 0
            local requiredKills = boss.requiredKills or 100
            local fraction = kills / requiredKills

            bar:SetMinMaxValues(0, requiredKills)
            bar:SetValue(kills)
            bar:SetStatusBarColor(1 - fraction, fraction, 0)

            local progressText = string.format("%d/%d - %s", kills, requiredKills, boss.bossName)
            bar.text:SetText(progressText)
            DebugPrint("Aktualisiere Fortschrittsbalken " .. i .. ": " .. progressText)
        else
            DebugPrint("Kein Boss für Fortschrittsbalken " .. i)
        end
    end
end

-- Fortschritt zurücksetzen
function ResetProgressBars()
    DebugPrint("Fortschrittsbalken und Daten werden zurückgesetzt.")

    for i, bar in ipairs(progressBarGroup) do
        bar:Hide()
        bar:ClearAllPoints()
        bar:SetParent(nil)
    end
    progressBarGroup = {}

    MyAddon.bossKills = {}
    MyAddon.activeBossList = {}
    MyAddon.currentBossIndex = 1

    if missingBuffText then
        missingBuffText:SetText("")
        DebugPrint("Buff-Warnung zurückgesetzt.")
    end

    MythicTrashTrackerDB.progress = nil
    DebugPrint("Fortschrittsdaten gelöscht.")
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

-- Entferne diese Zeilen:
-- CreateBossProgressBars()
-- UpdateProgress()
-- InitializeInstanceProgress()

-- Die Initialisierung läuft jetzt nur noch über die Events:
-- PLAYER_ENTERING_WORLD und ZONE_CHANGED_NEW_AREA
-- (siehe deine Event-Handler oben)

local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    MythicTrashTrackerDB.options = {}
    for k, v in pairs(OPTIONS) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            MythicTrashTrackerDB.options[k] = v
        end
    end
    -- BuffGroups als vollständige Liste speichern
    MythicTrashTrackerDB.buffGroups = {}
    for i = 1, #RequiredBuffGroups do
        MythicTrashTrackerDB.buffGroups[i] = OPTIONS.buffGroups[i] or false
    end
end)
function SaveMythicTrashTrackerOptions()
    MythicTrashTrackerDB.options = {}
    for k, v in pairs(OPTIONS) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            MythicTrashTrackerDB.options[k] = v
        end
    end
    -- BuffGroups als vollständige Liste speichern
    MythicTrashTrackerDB.buffGroups = {}
    for i = 1, #RequiredBuffGroups do
        MythicTrashTrackerDB.buffGroups[i] = OPTIONS.buffGroups[i] or false
    end
    print("|cFF00FF00[MythicTrashTracker]: Optionen wurden gespeichert!")
end

-- Verzögerte Ausführung (Delay in Sekunden)
function DelayedExecution(delay, func)
    local f = CreateFrame("Frame")
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
        end
    end)
end


