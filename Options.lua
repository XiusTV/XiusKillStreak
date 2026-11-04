--[[
    Options use the shared settings canvas on modern World of Warcraft
    and World of Warcraft Forever. The vertical settings checkbox
    initializer differs between these clients and must not be used.
]]

XiusKillStreak = XiusKillStreak or {}

local pcall = pcall
local CreateFrame = CreateFrame

local function PlayCheckSound(checked)
    if not PlaySound or not SOUNDKIT then
        return
    end
    if checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    elseif (not checked) and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF then
        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function SetCheckText(check, text)
    local label = check.Text or check.text
    if not label and check.GetName and check:GetName() then
        label = _G[check:GetName() .. "Text"]
    end
    if not label or not label.SetText then
        if not check.label then
            check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            check.label:SetPoint("LEFT", check, "RIGHT", 4, 1)
        end
        label = check.label
    end
    label:SetText(text)
    if check.SetHitRectInsets then
        local width = (label.GetStringWidth and label:GetStringWidth()) or 160
        if width < 140 then
            width = 140
        end
        pcall(check.SetHitRectInsets, check, 0, -(width + 8), 0, 0)
    end
end

local function MakeCheck(parent, name, text, tooltip)
    local check
    local ok, frame = pcall(CreateFrame, "CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    if ok and frame then
        check = frame
    else
        check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    end
    SetCheckText(check, text)
    check.tooltipText = tooltip
    check:SetScript("OnEnter", function(self)
        if not self.tooltipText or not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 0.82, 0)
        GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return check
end

function XiusKillStreak:SetEnabled(value)
    if self.syncing then
        return
    end
    XiusKillStreakDB.enabled = value and true or false
    if not XiusKillStreakDB.enabled then
        self:StopSound()
        self:ResetStreak()
        if self.FinishBanner and not XiusKillStreakDB.unlocked then
            self:FinishBanner()
        end
    end
    self:UpdateCounter()
    self:SyncOptions()
end

function XiusKillStreak:SetSoundEnabled(value)
    if self.syncing then
        return
    end
    XiusKillStreakDB.sound = value and true or false
    if not XiusKillStreakDB.sound then
        self:StopSound()
    end
    self:SyncOptions()
end

function XiusKillStreak:SetUnlocked(value)
    if self.syncing then
        return
    end
    XiusKillStreakDB.unlocked = value and true or false
    self:UpdateLock()
    self:SyncOptions()
end

function XiusKillStreak:SyncOptions()
    if not XiusKillStreakDB then
        return
    end
    self.syncing = true
    if self.enableCheck then
        self.enableCheck:SetChecked(XiusKillStreakDB.enabled)
    end
    if self.soundCheck then
        self.soundCheck:SetChecked(XiusKillStreakDB.sound)
    end
    if self.unlockCheck then
        self.unlockCheck:SetChecked(XiusKillStreakDB.unlocked)
    end
    self.syncing = false
end

function XiusKillStreak:RememberCategory(category)
    self.optionsCategory = category
    if category and category.GetID then
        local ok, id = pcall(category.GetID, category)
        if ok and id ~= nil then
            self.optionsCategoryID = id
            return
        end
    end
    if type(category) == "table" and category.ID ~= nil then
        self.optionsCategoryID = category.ID
    end
end

function XiusKillStreak:BuildOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    local panel = CreateFrame("Frame", "XiusKillStreakOptionsPanel")
    panel.name = "Xius Kill Streak"
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Xius Kill Streak")

    local about = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    about:SetWidth(540)
    about:SetJustifyH("LEFT")
    about:SetJustifyV("TOP")
    about:SetText("Mobs and enemy players both count. One kill is one streak point.\n\n2 Double Kill, 22s\n3 Triple Kill, 18s\n5 Multi Kill, 15s\n8 Mega Kill, 12s\n12 Ultra Kill, 10s\n16 Monster Kill, 8s\n20 Godlike, 6s\n25 Holy Shit, 5s\n30 Finish Him, 4s\n40 Toasty, 3s\n\nThe first kill has 25 seconds. Each line is the time allowed for the next kill.\n\n/xks opens this page. /xks test plays Toasty. /xks test 1-10 plays that tier. /xks reset clears the streak. /xks unlock and /xks lock toggle frame movement.")

    local enable = MakeCheck(panel, "XiusKillStreakOptionsEnable", "Enable kill streaks", "Count killing blows on mobs and enemy players. Turning this off clears the current streak and hides the banner.")
    enable:SetPoint("TOPLEFT", about, "BOTTOMLEFT", -2, -16)
    enable:SetScript("OnClick", function(self)
        PlayCheckSound(self:GetChecked())
        XiusKillStreak:SetEnabled(self:GetChecked())
    end)
    self.enableCheck = enable

    local sound = MakeCheck(panel, "XiusKillStreakOptionsSound", "Play streak sounds", "Play the announcer voice with each new tier. The test button still plays a sound when this is off.")
    sound:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -8)
    sound:SetScript("OnClick", function(self)
        PlayCheckSound(self:GetChecked())
        XiusKillStreak:SetSoundEnabled(self:GetChecked())
    end)
    self.soundCheck = sound

    local unlock = MakeCheck(panel, "XiusKillStreakOptionsUnlock", "Unlock banner and counter", "Drag the banner and the streak counter. Drag the counter corner to resize it.")
    unlock:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -8)
    unlock:SetScript("OnClick", function(self)
        PlayCheckSound(self:GetChecked())
        XiusKillStreak:SetUnlocked(self:GetChecked())
    end)
    self.unlockCheck = unlock

    local test = CreateFrame("Button", "XiusKillStreakOptionsTest", panel, "UIPanelButtonTemplate")
    test:SetSize(160, 24)
    test:SetPoint("TOPLEFT", unlock, "BOTTOMLEFT", 4, -16)
    test:SetText("Test Toasty Banner")
    test:SetScript("OnClick", function()
        XiusKillStreak:Test(10)
    end)

    local resetPos = CreateFrame("Button", "XiusKillStreakOptionsResetPos", panel, "UIPanelButtonTemplate")
    resetPos:SetSize(140, 24)
    resetPos:SetPoint("LEFT", test, "RIGHT", 10, 0)
    resetPos:SetText("Reset Positions")
    resetPos:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        XiusKillStreak:ResetPositions()
        XiusKillStreak:Print("Banner and counter positions reset to default.")
    end)

    panel.OnRefresh = function()
        XiusKillStreak:SyncOptions()
    end
    panel.refresh = panel.OnRefresh
    panel:SetScript("OnShow", function()
        XiusKillStreak:SyncOptions()
    end)

    self.optionsPanel = panel
    self:SyncOptions()
    return panel
end

function XiusKillStreak:SetupCanvasOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return false
    end

    local ok, result = pcall(function()
        local panel = XiusKillStreak:BuildOptionsPanel()
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Xius Kill Streak")
        if not category then
            return false
        end
        Settings.RegisterAddOnCategory(category)
        XiusKillStreak:RememberCategory(category)
        return true
    end)
    if not ok then
        return false
    end
    return result and true or false
end

function XiusKillStreak:SetupLegacyOptions()
    if not InterfaceOptions_AddCategory then
        return false
    end
    local ok, result = pcall(function()
        local panel = XiusKillStreak:BuildOptionsPanel()
        InterfaceOptions_AddCategory(panel)
        return true
    end)
    if not ok then
        return false
    end
    return result and true or false
end

function XiusKillStreak:SetupOptions()
    if self:SetupCanvasOptions() then
        return
    end
    if self:SetupLegacyOptions() then
        return
    end
    self:Print("Options could not be added to the menu. Type /xks test to preview Toasty.")
end

function XiusKillStreak:OpenOptions()
    if not self.loaded then
        self:Print("Still loading. Try /xks again in a moment.")
        return
    end

    if InCombatLockdown then
        local okLock, inLockdown = pcall(InCombatLockdown)
        if okLock and inLockdown == true then
            self:Print("Cannot open the Settings window in combat. Use /xks unlock, /xks lock, /xks sound, or /xks reset.")
            return
        end
    end

    if Settings and Settings.OpenToCategory and self.optionsCategoryID ~= nil then
        local ok = pcall(Settings.OpenToCategory, self.optionsCategoryID)
        if ok then
            return
        end
    end

    if self.optionsCategory and Settings and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, self.optionsCategory)
        if ok then
            return
        end
    end

    if self.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
        local ok = pcall(InterfaceOptionsFrame_OpenToCategory, self.optionsPanel)
        if ok then
            pcall(InterfaceOptionsFrame_OpenToCategory, self.optionsPanel)
            return
        end
    end

    if self.optionsPanel and Settings and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, self.optionsPanel.name)
        if ok then
            return
        end
    end

    self:Print("Type /xks test to play Toasty, or /xks test 1 through 10 for another tier.")
end
