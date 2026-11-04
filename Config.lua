--[[
    XiusKillStreak tier list
    Modern World of Warcraft (Interface 120105, 120107)
    World of Warcraft Forever (Interface 16001)

    Tiers run from the easiest chain to the hardest.
    Each kill must land before that tier's countdown reaches zero.
    The next tier uses a shorter countdown.

    streakCount  Kills required to trigger this tier.
    countdown    Seconds allowed between kills.
    title        Text shown on the streak banner.
    sound        File played with the banner. Full path from the game folder.
]]

XiusKillStreak = XiusKillStreak or {}

XiusKillStreak.TITLE_FONT = "Interface\\AddOns\\XiusKillStreak\\Font\\cfnightofthedamned\\CFNightOfTheDamned-Regular.ttf"
XiusKillStreak.SUB_FONT = "Interface\\AddOns\\XiusKillStreak\\Font\\bloodcrow\\bloodcrow.ttf"
XiusKillStreak.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
XiusKillStreak.BASE_COUNTDOWN = 25

XiusKillStreak_Config = {
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
