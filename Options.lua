--[[
    Registers Kill Streak with the settings window from XiusCore using top sub-tabs:
    General and Audio & Announcements.
    This file does not build a window. XiusCore owns the chrome.
]]

local addonName, ns = ...

local XiusCore = _G.XiusCore or _G.XiusCoreSettingsLib
if not XiusCore and C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "XiusCore")
    XiusCore = ok and loaded and true or false
end
if not XiusCore and IsAddOnLoaded then
    local ok, loaded = pcall(IsAddOnLoaded, "XiusCore")
    XiusCore = ok and loaded and true or false
end
if not XiusCore then
    return
end

local type = type
local tonumber = tonumber
local tostring = tostring
local math_floor = math.floor
local string_format = string.format

local SUB_TABS = {
    { id = "general", text = "General" },
    { id = "audio", text = "Audio & Announcements" },
}

local SOUND_CHANNEL_ITEMS = {
    { value = "Master", text = "Master" },
    { value = "SFX", text = "SFX (Sound Effects)" },
    { value = "Dialog", text = "Dialog" },
    { value = "Ambience", text = "Ambience" },
    { value = "Music", text = "Music" },
}

local ANNOUNCE_CHANNEL_ITEMS = {
    { value = "SELF", text = "Local Chat (Self Only)" },
    { value = "EMOTE", text = "Custom Emote (/e)" },
    { value = "SAY", text = "Say (/s)" },
    { value = "YELL", text = "Yell (/y)" },
    { value = "PARTY", text = "Party (/p)" },
    { value = "RAID", text = "Raid / Instance (/ra, /i)" },
}

local EMOTE_ITEMS = {
    { value = "ROAR", text = "Roar (/roar)" },
    { value = "CHEER", text = "Cheer (/cheer)" },
    { value = "VICTORY", text = "Victory (/victory)" },
    { value = "FLEX", text = "Flex (/flex)" },
    { value = "CHARGE", text = "Charge (/charge)" },
    { value = "LAUGH", text = "Laugh (/laugh)" },
}

local PREVIEW_TIER_ITEMS = {}
do
    local tiers = ns.tiers or {}
    for i = 1, #tiers do
        local tier = tiers[i]
        PREVIEW_TIER_ITEMS[i] = {
            value = i,
            text = string_format("%d. %s (%d kills)", i, tier.title or "Tier", tier.streakCount or i),
        }
    end
end

local function DB()
    if type(XiusKillStreakDB) ~= "table" then
        if ns.InitDB then
            ns:InitDB()
        else
            XiusKillStreakDB = {}
        end
    end
    return XiusKillStreakDB
end

local function Flag(key, defaultOn)
    local value = DB()[key]
    if value == nil then
        return defaultOn and true or false
    end
    return value and true or false
end

local function SettingsLib()
    return _G.XiusCoreSettingsLib
end

local function RefreshPage()
    local Lib = SettingsLib()
    if Lib and Lib.RefreshPage then
        Lib:RefreshPage()
    end
end

function ns:SetEnabled(value)
    if self.syncing then
        return
    end
    DB().enabled = value and true or false
    if not DB().enabled then
        if self.StopSound then
            self:StopSound()
        end
        if self.ResetStreak then
            self:ResetStreak()
        end
        if self.FinishBanner and not DB().unlocked then
            self:FinishBanner()
        end
    end
    if self.UpdateCounter then
        self:UpdateCounter()
    end
end

function ns:SetSoundEnabled(value)
    if self.syncing then
        return
    end
    DB().sound = value and true or false
    if not DB().sound and self.StopSound then
        self:StopSound()
    end
end

function ns:SetUnlocked(value)
    if self.syncing then
        return
    end
    local nextState = value and true or false
    if DB().unlocked == nextState then
        return
    end
    DB().unlocked = nextState
    if self.UpdateLock then
        self:UpdateLock()
    end
end

local function ApplyDefaults()
    local db = DB()
    local defaults = ns.DEFAULTS or {}
    db.enabled = true
    db.unlocked = false
    db.trackPvE = true
    db.trackPvP = true
    db.ignoreGray = false
    db.resetTimer = defaults.resetTimer or 25
    db.bannerScale = 1
    db.fontScale = 1
    db.previewTier = #(ns.tiers or {})
    if db.previewTier < 1 then
        db.previewTier = 10
    end
    db.sound = true
    db.soundChannel = "Master"
    db.soundVolume = 100
    db.chatAnnounce = false
    db.announceChannel = "SELF"
    db.emoteAnnounce = false
    db.emoteToken = "ROAR"
    if type(db.tiers) ~= "table" then
        db.tiers = {}
    end
    for i = 1, #(ns.tiers or {}) do
        db.tiers[i] = true
    end
    if ns.ApplySettings then
        ns:ApplySettings()
    else
        ns:SetEnabled(true)
        ns:SetSoundEnabled(true)
        ns:SetUnlocked(false)
    end
    RefreshPage()
end

ns.ResetDefaults = ApplyDefaults

local function UnlockFrames()
    ns:SetUnlocked(true)
    if ns.Print then
        ns:Print("Banner and counter unlocked. Drag to move.")
    end
    RefreshPage()
end

local function TestPreview()
    if ns.Test then
        local tier = tonumber(DB().previewTier) or 10
        ns:Test(tier)
    end
end

local function ClearStreak()
    if ns.ResetStreak then
        ns:ResetStreak()
    end
    if ns.Print then
        ns:Print("Streak cleared.")
    end
end

local function ResetPosition()
    if ns.ResetPositions then
        ns:ResetPositions()
    end
    if ns.Print then
        ns:Print("Banner and counter positions reset to default.")
    end
    RefreshPage()
end

local function BuildGeneralTab(_, api)
    api:AddSection("General")
    api:AddNote("Tracks consecutive killing blows on mobs and enemy players with Unreal-style banners and announcer calls.")
    api:AddCheckbox("Enable kill streaks", function()
        return Flag("enabled", true)
    end, function(value)
        ns:SetEnabled(value)
    end, "Count killing blows on mobs and enemy players. Turning this off clears the current streak.")

    api:AddSection("PvP & PvE Mode Filters")
    api:AddCheckbox("Track PvE kills (mobs and NPCs)", function()
        return Flag("trackPvE", true)
    end, function(value)
        DB().trackPvE = value and true or false
    end, "Count killing blows on hostile creatures and NPCs.")
    api:AddCheckbox("Track PvP kills (enemy players)", function()
        return Flag("trackPvP", true)
    end, function(value)
        DB().trackPvP = value and true or false
    end, "Count killing blows and honorable kills on enemy players.")
    api:AddCheckbox("Ignore gray (trivial) mobs", function()
        return Flag("ignoreGray", false)
    end, function(value)
        DB().ignoreGray = value and true or false
    end, "Skip low-level gray mobs that award no experience. Green or higher mobs and enemy players still count.")

    api:AddSection("Streak Timer")
    api:AddSlider("Streak reset timer (seconds)", 5, 60, 1, function()
        return tonumber(DB().resetTimer) or 25
    end, function(value)
        local sec = math_floor((tonumber(value) or 25) + 0.5)
        if sec < 5 then
            sec = 5
        elseif sec > 60 then
            sec = 60
        end
        DB().resetTimer = sec
        if ns.UpdateCounter then
            ns:UpdateCounter()
        end
    end, "Base window after your first kill before the streak expires. Higher tiers tighten proportionally from this value.")

    api:AddSection("Banner Scale & Position")
    api:AddSlider("Banner scale (%)", 50, 200, 5, function()
        local scale = ns.GetBannerScale and ns:GetBannerScale() or tonumber(DB().bannerScale) or 1
        return math_floor((scale * 100) + 0.5)
    end, function(value)
        local scale = (tonumber(value) or 100) / 100
        if scale < 0.5 then
            scale = 0.5
        elseif scale > 2.0 then
            scale = 2.0
        end
        DB().bannerScale = scale
        DB().fontScale = scale
        if ns.ApplyBannerScale then
            ns:ApplyBannerScale()
        end
    end, "Scales the kill streak banner text and frame from 50% to 200% without shifting its screen position.")
    api:AddSlider("Banner horizontal offset (X)", -600, 600, 5, function()
        if ns.GetBannerOffset then
            local x = ns:GetBannerOffset()
            return x
        end
        return 0
    end, function(value)
        if ns.SetBannerOffset then
            ns:SetBannerOffset(math_floor((tonumber(value) or 0) + 0.5), nil)
        end
    end, "Horizontal screen offset for the banner. Dragging while unlocked updates this automatically.")
    api:AddSlider("Banner vertical offset (Y)", -400, 400, 5, function()
        if ns.GetBannerOffset then
            local _, y = ns:GetBannerOffset()
            return y
        end
        return 160
    end, function(value)
        if ns.SetBannerOffset then
            ns:SetBannerOffset(nil, math_floor((tonumber(value) or 160) + 0.5))
        end
    end, "Vertical screen offset for the banner. Dragging while unlocked updates this automatically.")
    api:AddCheckbox("Unlock banner and counter", function()
        return Flag("unlocked", false)
    end, function(value)
        ns:SetUnlocked(value)
        local Lib = SettingsLib()
        if not value and Lib and Lib.NoteFramesLocked then
            Lib:NoteFramesLocked()
        end
    end, "Shows a placement preview so you can drag the banner or streak counter, and drag the counter corner to resize.")

    api:AddSection("Test Preview & Actions")
    api:AddDropdown("Preview tier", PREVIEW_TIER_ITEMS, function()
        return tonumber(DB().previewTier) or 10
    end, function(value)
        DB().previewTier = tonumber(value) or 10
    end, "Choose which streak tier plays when you click Test Preview.")
    api:AddButtonGroup({
        height = 24,
        spacing = 8,
        buttons = {
            {
                text = "Test Preview",
                width = 112,
                onClick = TestPreview,
            },
            {
                text = "Clear Streak",
                width = 104,
                onClick = ClearStreak,
            },
            {
                text = "Reset Position",
                width = 118,
                onClick = ResetPosition,
            },
            {
                text = "Defaults",
                width = 96,
                onClick = ApplyDefaults,
            },
        },
    })
end

local function BuildAudioTab(_, api)
    api:AddSection("Sound Effects")
    api:AddCheckbox("Play streak announcer sounds", function()
        return Flag("sound", true)
    end, function(value)
        ns:SetSoundEnabled(value)
    end, "Play the announcer voice clip on each enabled tier. Test Preview always plays sound.")
    api:AddDropdown("Sound channel", SOUND_CHANNEL_ITEMS, function()
        return DB().soundChannel or "Master"
    end, function(value)
        DB().soundChannel = value or "Master"
    end, "Audio channel used by PlaySoundFile for streak announcer calls.")
    api:AddSlider("Sound effects volume (%)", 0, 100, 5, function()
        local vol = tonumber(DB().soundVolume)
        if vol == nil then
            return 100
        end
        return vol
    end, function(value)
        if ns.SetSoundVolume then
            ns:SetSoundVolume(value)
        else
            DB().soundVolume = tonumber(value) or 100
        end
    end, "Adjusts announcer volume for streak calls only (0% mutes). Does not change the game's Master/SFX volume.")

    api:AddSection("Chat & Emote Announcements")
    api:AddCheckbox("Announce streak tiers in chat", function()
        return Flag("chatAnnounce", false)
    end, function(value)
        DB().chatAnnounce = value and true or false
    end, "Post a callout message when you reach an enabled kill streak tier.")
    api:AddDropdown("Chat announcement channel", ANNOUNCE_CHANNEL_ITEMS, function()
        return DB().announceChannel or "SELF"
    end, function(value)
        DB().announceChannel = value or "SELF"
    end, "Destination channel for chat announcements. Falls back to local chat if not in a group or restricted.")
    api:AddCheckbox("Perform voice emote on streak tier", function()
        return Flag("emoteAnnounce", false)
    end, function(value)
        DB().emoteAnnounce = value and true or false
    end, "Trigger a character emote when you reach an enabled kill streak tier.")
    api:AddDropdown("Voice emote", EMOTE_ITEMS, function()
        return DB().emoteToken or "ROAR"
    end, function(value)
        DB().emoteToken = value or "ROAR"
    end, "Emote performed when voice emote announcements are enabled.")

    api:AddSection("Individual Streak Tiers")
    api:AddNote("Toggle individual kill streak tiers on or off. Disabled tiers stay silent while the streak counter and timer continue advancing.")
    local tiers = ns.tiers or {}
    for i = 1, #tiers do
        local tier = tiers[i]
        local tierIndex = i
        local label = string_format("%d Kills — %s (%ds base timer)", tier.streakCount or i, tier.title or ("Tier " .. tostring(i)), tier.countdown or 25)
        local tip = string_format("Enable banner, announcer sound, and chat/emote callouts for %s.", tier.title or ("Tier " .. tostring(i)))
        api:AddCheckbox(label, function()
            if ns.IsTierEnabled then
                return ns:IsTierEnabled(tierIndex)
            end
            return true
        end, function(value)
            if ns.SetTierEnabled then
                ns:SetTierEnabled(tierIndex, value)
            end
        end, tip)
    end
end

function ns:SetupOptions()
    if self.optionsReady then
        return
    end
    if self.InitDB then
        self:InitDB()
    end
    local Lib = SettingsLib()
    if not Lib or not Lib.RegisterModule then
        return
    end
    Lib:RegisterModule({
        id = "KillStreak",
        title = "Kill Streak",
        menuTitle = "Kill Streak",
        group = "Utilities & System",
        order = 60,
        hidePageTitle = true,
        activeSubTab = "general",
        subTabs = SUB_TABS,
        getDB = function()
            return DB()
        end,
        defaults = ns.DEFAULTS,
        onResetDefaults = ApplyDefaults,
        onUnlock = function(unlocked)
            ns:SetUnlocked(unlocked and true or false)
            RefreshPage()
        end,
        onUnlockFrames = UnlockFrames,
        buildContent = function(host, api, spec, tabId)
            local subTab = tabId or (spec and spec.activeSubTab) or "general"
            if subTab == "audio" then
                BuildAudioTab(host, api)
            else
                BuildGeneralTab(host, api)
            end
        end,
    })
    self.optionsReady = true
end

function ns:OpenOptions(subTab)
    if not self.loaded then
        self:Print("Still loading. Try /xks again in a moment.")
        return
    end
    if ns.InLockdown() then
        self:Print("Cannot open the Settings window in combat. Use /xks unlock, /xks lock, /xks sound, or /xks reset.")
        return
    end
    if not self.optionsReady then
        self:SetupOptions()
    end
    local Lib = SettingsLib()
    if Lib and Lib.OpenModule then
        Lib:OpenModule("KillStreak", subTab)
        return
    end
    self:Print("Xius Core is required. Enable XiusCore, then type /xks again.")
end
