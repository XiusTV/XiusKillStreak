--[[
    XiusKillStreak tier list
    Modern World of Warcraft (Interface 120105, 120107)
    World of Warcraft Forever (Interface 16001)

    Tiers run from the easiest chain to the hardest.
    Each kill must land before that tier's countdown reaches zero.
    The next tier uses a shorter countdown.
]]

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.TITLE_FONT = "Interface\\AddOns\\XiusKillStreak\\Font\\cfnightofthedamned\\CFNightOfTheDamned-Regular.ttf"
ns.SUB_FONT = "Interface\\AddOns\\XiusKillStreak\\Font\\bloodcrow\\bloodcrow.ttf"
ns.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
ns.BASE_COUNTDOWN = 25

local pcall = pcall
local type = type
local issecretvalue = issecretvalue
local canaccessvalue = canaccessvalue

local function IsTrue(value)
    return value == true
end

function ns.IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if not ok then
            return true
        end
        local compared, plain = pcall(IsTrue, secret)
        if not compared or plain then
            return true
        end
    end
    if canaccessvalue then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok then
            return true
        end
        local compared, plain = pcall(IsTrue, accessible)
        if not compared or not plain then
            return true
        end
    end
    local compared = pcall(IsTrue, value)
    return not compared
end

function ns.PlainNumber(value)
    if ns.IsSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

function ns.Now()
    if not GetTime then
        return nil
    end
    local ok, now = pcall(GetTime)
    if not ok then
        return nil
    end
    return ns.PlainNumber(now)
end

function ns.InLockdown()
    if not InCombatLockdown then
        return false
    end
    local ok, locked = pcall(InCombatLockdown)
    if not ok or ns.IsSecret(locked) then
        return true
    end
    return locked == true
end

ns.tiers = {
    {
        streakCount = 2,
        countdown = 22,
        title = "Double Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\double-kill.ogg",
    },
    {
        streakCount = 3,
        countdown = 18,
        title = "Triple Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\triple-kill.ogg",
    },
    {
        streakCount = 5,
        countdown = 15,
        title = "Multi Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\multi-kill.ogg",
    },
    {
        streakCount = 8,
        countdown = 12,
        title = "Mega Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\mega-kill.ogg",
    },
    {
        streakCount = 12,
        countdown = 10,
        title = "Ultra Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\ultra-kill.ogg",
    },
    {
        streakCount = 16,
        countdown = 8,
        title = "Monster Kill",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\monster-kill.ogg",
    },
    {
        streakCount = 20,
        countdown = 6,
        title = "Godlike",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\godlike.ogg",
    },
    {
        streakCount = 25,
        countdown = 5,
        title = "Holy Shit",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\holy-shit.ogg",
    },
    {
        streakCount = 30,
        countdown = 4,
        title = "Finish Him",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\finish-him.ogg",
    },
    {
        streakCount = 40,
        countdown = 3,
        title = "Toasty",
        sound = "Interface\\AddOns\\XiusKillStreak\\Sounds\\toasty.ogg",
    },
}

_G.XiusKillStreak = ns
_G.XiusKillStreak_Config = ns.tiers
