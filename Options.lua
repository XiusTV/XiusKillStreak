--[[
    Registers Kill Streak with the settings window from XiusCore.
    This file does not build a window. XiusCore owns the chrome.
    The page title is already "Kill Streak", so this page does not
    repeat that name as a section header.
]]

local _, ns = ...

local XiusCore = _G.XiusCore or _G.XiusUI or _G.XiusCoreSettingsLib
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

local SUBTITLE = "Tracks consecutive killing blows on mobs and enemy players with Unreal-style banners and sounds."

local TIP_ENABLE = "Count killing blows on mobs and enemy players. Turning off clears the current streak."
local TIP_SOUND = "Play the announcer voice on each tier. Test Banner always plays sound."
local TIP_UNLOCK = "Drag the banner or streak counter to move; drag the counter corner to resize."

local TIER_SUMMARY = "First kill starts a 25s window; each tier below sets the timer to reach the next kill (/xks test | /xks unlock):"
local TIER_LINES = table.concat({
    "2: Double Kill (22s)  •  3: Triple Kill (18s)  •  5: Multi Kill (15s)",
    "8: Mega Kill (12s)  •  12: Ultra Kill (10s)  •  16: Monster Kill (8s)",
    "20: Godlike (6s)  •  25: Holy Shit (5s)  •  30: Finish Him (4s)  •  40: Toasty (3s)",
}, "\n")
local TIER_BLOCK = TIER_SUMMARY .. "\n" .. TIER_LINES

local function LineCount(text)
    local lines = 0
    local start = 1
    local len = string.len(text)
    if len < 1 then
        return 1
    end
    while start <= len do
        local stop = string.find(text, "\n", start, true)
        local chunkEnd = stop or (len + 1)
        local chunk = chunkEnd - start
        if chunk < 1 then
            chunk = 1
        end
        lines = lines + math.ceil(chunk / 88)
        if not stop then
            break
        end
        start = stop + 1
        if start > len then
            break
        end
    end
    if lines < 1 then
        lines = 1
    end
    return lines
end

local function NoteFont(row)
    local regions = { row:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region.GetText and region.GetStringHeight then
            return region
        end
    end
end

local function FitNote(row, text)
    if not row then
        return
    end
    local font = NoteFont(row)
    local function Apply()
        local height = 8 + (LineCount(text) * 15)
        if font and font.GetStringHeight then
            local measured = font:GetStringHeight()
            if type(measured) == "number" and measured > 1 and (measured + 8) > height then
                height = measured + 8
            end
        end
        if height < 22 then
            height = 22
        end
        row.rowHeight = height
        row:SetHeight(height)
    end
    row.Reflow = Apply
    Apply()
end

local function DB()
    if type(XiusKillStreakDB) ~= "table" then
        XiusKillStreakDB = {}
    end
    return XiusKillStreakDB
end

local function Flag(key)
    return DB()[key] and true or false
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
    DB().unlocked = value and true or false
    if self.UpdateLock then
        self:UpdateLock()
    end
end

local function ApplyDefaults()
    ns:SetEnabled(true)
    ns:SetSoundEnabled(true)
    ns:SetUnlocked(false)
    RefreshPage()
end

local function UnlockFrames()
    ns:SetUnlocked(true)
    if ns.Print then
        ns:Print("Banner and counter unlocked. Drag to move.")
    end
    RefreshPage()
end

local function TestBanner()
    if ns.Test then
        ns:Test(10)
    end
end

local function ResetPosition()
    if ns.ResetPositions then
        ns:ResetPositions()
    end
    if ns.Print then
        ns:Print("Banner and counter positions reset to default.")
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
        getDB = function()
            return XiusKillStreakDB
        end,
        defaults = {
            enabled = true,
            sound = true,
            unlocked = false,
        },
        onResetDefaults = ApplyDefaults,
        onUnlock = function(unlocked)
            ns:SetUnlocked(unlocked and true or false)
            RefreshPage()
        end,
        onUnlockFrames = UnlockFrames,
        buildContent = function(_, api)
            FitNote(api:AddNote(SUBTITLE), SUBTITLE)
            api:AddSection("General")
            api:AddCheckbox("Enable kill streaks", function()
                return Flag("enabled")
            end, function(value)
                ns:SetEnabled(value)
            end, TIP_ENABLE)
            api:AddCheckbox("Play streak sounds", function()
                return Flag("sound")
            end, function(value)
                ns:SetSoundEnabled(value)
            end, TIP_SOUND)
            api:AddCheckbox("Unlock banner and counter", function()
                return Flag("unlocked")
            end, function(value)
                ns:SetUnlocked(value)
                local Lib = SettingsLib()
                if not value and Lib and Lib.NoteFramesLocked then
                    Lib:NoteFramesLocked()
                end
            end, TIP_UNLOCK)
            api:AddButtonGroup({
                height = 32,
                spacing = 8,
                buttons = {
                    {
                        text = "Test Banner",
                        width = 128,
                        height = 32,
                        onClick = TestBanner,
                    },
                    {
                        text = "Reset Position",
                        width = 140,
                        height = 32,
                        onClick = ResetPosition,
                    },
                    {
                        text = "Defaults",
                        width = 110,
                        height = 32,
                        onClick = ApplyDefaults,
                    },
                },
            })
            api:AddSection("Streak Tiers & Timers")
            FitNote(api:AddNote(TIER_BLOCK), TIER_BLOCK)
        end,
    })
    self.optionsReady = true
end

function ns:OpenOptions()
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
        Lib:OpenModule("KillStreak")
        return
    end
    self:Print("Xius Core is required. Enable XiusCore, then type /xks again.")
end
