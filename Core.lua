--[[
    Kill streak tracking, sounds, and slash commands.

    One death counts once. Experience chat is the main signal when the
    text can be read. A killing-blow float, "You have slain", party-kill,
    honor chat, and the current target dying cover kills that give no
    experience or hide unit names in combat.

    Modern World of Warcraft and World of Warcraft Forever both forbid
    addon combat-log access, and enemy names are hidden in combat.
    This file never registers a combat-log event and never branches on
    a secret value.
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

ns.streak = 0
ns.firedTier = 0
ns.lastKillAt = nil
ns.loaded = false
ns.recentKills = {}
ns.targetAliveAt = nil
ns.targetName = nil
ns.targetGUID = nil
ns.targetIsPlayer = nil
ns.targetIsTrivial = nil
ns.inPvPInstance = false
ns.inCombat = false
ns.lastCombatAt = 0
ns.lastQuestTurnin = 0
ns.soundHandle = nil

local pcall = pcall
local type = type
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local print = print
local math_floor = math.floor
local math_max = math.max
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local string_upper = string.upper
local table_remove = table.remove

local CORRELATE_WINDOW = 0.35
local GUID_WINDOW = 5.0
local MAX_RECENT_KILLS = 64
local SOUND_CHANNEL_ORDER = {
    Master = { "Master", "Dialog", "SFX" },
    SFX = { "SFX", "Master", "Dialog" },
    Dialog = { "Dialog", "Master", "SFX" },
    Ambience = { "Ambience", "Master", "SFX" },
    Music = { "Music", "Master", "SFX" },
}
local SOUND_VOLUME_CVARS = {
    Master = "Sound_MasterVolume",
    SFX = "Sound_SFXVolume",
    Dialog = "Sound_DialogVolume",
    Ambience = "Sound_AmbienceVolume",
    Music = "Sound_MusicVolume",
}
local VALID_ANNOUNCE_CHANNELS = {
    SELF = true,
    EMOTE = true,
    SAY = true,
    YELL = true,
    PARTY = true,
    RAID = true,
}
local VALID_EMOTE_TOKENS = {
    ROAR = true,
    CHEER = true,
    VICTORY = true,
    FLEX = true,
    CHARGE = true,
    LAUGH = true,
}
local SOURCE_KEYS = { "XP", "GENERIC", "KB", "HONOR", "SLAIN", "PARTYKILL", "TARGET" }
local recordPool = {}

local RESTRICTED_EVENTS = {
    COMBAT_LOG_EVENT = true,
    COMBAT_LOG_EVENT_UNFILTERED = true,
    COMBAT_LOG_EVENT_INTERNAL_UNFILTERED = true,
}

local eventFrame = CreateFrame("Frame")
eventFrame:SetSize(1, 1)
eventFrame:EnableMouse(false)
eventFrame.accum = 0
eventFrame.tickerActive = false

local StartTicker

local function IsSecret(value)
    return ns.IsSecret(value)
end

local function Now()
    return ns.Now()
end

local function PlainStamp(value)
    return ns.PlainNumber(value)
end

local function ClearSources(sources)
    for i = 1, #SOURCE_KEYS do
        sources[SOURCE_KEYS[i]] = nil
    end
end

local function AcquireRecord()
    local rec = recordPool[#recordPool]
    if rec then
        recordPool[#recordPool] = nil
        return rec
    end
    return { sources = {} }
end

local RECORD_POOL_CAP = 64

local function ReleaseRecord(rec)
    if type(rec) ~= "table" then
        return
    end
    rec.at = nil
    rec.name = nil
    rec.guid = nil
    if type(rec.sources) ~= "table" then
        rec.sources = {}
    else
        ClearSources(rec.sources)
    end
    if #recordPool >= RECORD_POOL_CAP then
        return
    end
    recordPool[#recordPool + 1] = rec
end

local function WipeRecords(list)
    for i = #list, 1, -1 do
        ReleaseRecord(list[i])
        list[i] = nil
    end
end

local function TrackingEnabled()
    return XiusKillStreakDB and XiusKillStreakDB.enabled and true or false
end

local function PublicString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function PlainCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then
        return nil
    end
    return value
end

local function PlainBool(func, ...)
    local value = PlainCall(func, ...)
    if type(value) ~= "boolean" then
        return nil
    end
    return value
end

local function PlainString(func, ...)
    return PublicString(PlainCall(func, ...))
end

local function Trim(text)
    if not text then
        return ""
    end
    text = string_gsub(text, "^%s+", "")
    text = string_gsub(text, "%s+$", "")
    return text
end

local function ShortName(name)
    name = PublicString(name)
    if not name then
        return nil
    end
    local short = string_match(name, "^%s*([^%-]-)%s*$")
    if short and short ~= "" then
        return short
    end
    return nil
end

local function SafeText(value)
    local text = PublicString(value)
    if not text then
        return nil
    end
    local ok = pcall(string_len, text)
    if not ok then
        return nil
    end
    return text
end

local function PatternFromFormat(fmt, anchorEnd)
    fmt = SafeText(fmt)
    if not fmt then
        return nil
    end
    fmt = string_gsub(fmt, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    fmt = string_gsub(fmt, "%%%%s", "(.-)", 1)
    fmt = string_gsub(fmt, "%%%%s", ".+")
    fmt = string_gsub(fmt, "%%%%d", "%%d+")
    if anchorEnd then
        return "^" .. fmt .. "$"
    end
    return "^" .. fmt
end

local function MatchPattern(text, pattern)
    text = SafeText(text)
    pattern = PublicString(pattern)
    if not text or not pattern then
        return nil
    end
    local ok, name = pcall(string_match, text, pattern)
    if not ok then
        return nil
    end
    return ShortName(name)
end

local xpPatterns
local honorPatterns
local slainPattern
local unnamedXPPrefix

local function EnsurePatterns()
    if xpPatterns then
        return
    end
    xpPatterns = {}
    local rawXP = {
        _G.COMBATLOG_XPGAIN_FIRSTPERSON,
        _G.COMBATLOG_XPGAIN_FIRSTPERSON_GROUP,
        _G.COMBATLOG_XPGAIN_FIRSTPERSON_RAID,
        _G.COMBATLOG_XPGAIN_EXHAUSTION1,
        _G.COMBATLOG_XPGAIN_EXHAUSTION1_GROUP,
        _G.COMBATLOG_XPGAIN_EXHAUSTION1_RAID,
        _G.COMBATLOG_XPGAIN_EXHAUSTION2,
        _G.COMBATLOG_XPGAIN_EXHAUSTION2_GROUP,
        _G.COMBATLOG_XPGAIN_EXHAUSTION2_RAID,
        _G.COMBATLOG_XPGAIN_EXHAUSTION4,
        _G.COMBATLOG_XPGAIN_EXHAUSTION5,
    }
    for i = 1, #rawXP do
        local pat = PatternFromFormat(rawXP[i], false)
        if pat then
            xpPatterns[#xpPatterns + 1] = pat
        end
    end

    honorPatterns = {}
    local rawHonor = {
        _G.COMBATLOG_HONORGAIN,
        _G.COMBATLOG_HONORGAIN_NO_RANK,
        _G.COMBATLOG_HONORGAIN_EXHAUSTION1,
    }
    for i = 1, #rawHonor do
        local pat = PatternFromFormat(rawHonor[i], false)
        if pat then
            honorPatterns[#honorPatterns + 1] = pat
        end
    end

    local slain = SafeText(_G.SELFKILLOTHER) or "You have slain %s!"
    slainPattern = PatternFromFormat(slain, true) or "^You have slain (.+)!$"

    local unnamed = SafeText(_G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED)
    if unnamed then
        local prefix = string_match(unnamed, "^(.-)%%")
        prefix = prefix and Trim(prefix) or nil
        if prefix and prefix ~= "" then
            unnamedXPPrefix = prefix
        end
    end
end

function ns:Print(text)
    print("Xius Kill Streak: " .. tostring(text))
end

local function AdoptCoreDB()
    if type(XiusUIDB) ~= "table" then
        return
    end
    local profile = XiusUIDB.killstreak
    if type(profile) ~= "table" then
        profile = {}
        XiusUIDB.killstreak = profile
    end
    local saved = XiusKillStreakDB
    if type(saved) ~= "table" then
        XiusKillStreakDB = profile
        return
    end
    if saved == profile then
        return
    end
    XiusUIDB.killstreak = saved
    XiusKillStreakDB = saved
end

local function SanitizeDB(db)
    local defaults = ns.DEFAULTS or {}
    if db.enabled == nil then
        db.enabled = defaults.enabled ~= false
    end
    if db.unlocked == nil then
        db.unlocked = false
    end
    if db.trackPvE == nil then
        db.trackPvE = true
    end
    if db.trackPvP == nil then
        db.trackPvP = true
    end
    if db.ignoreGray == nil then
        db.ignoreGray = false
    end
    local timer = ns.PlainNumber(db.resetTimer)
    if not timer then
        timer = defaults.resetTimer or 25
    end
    if timer < 5 then
        timer = 5
    elseif timer > 60 then
        timer = 60
    end
    db.resetTimer = math_floor(timer + 0.5)

    local scale = ns.PlainNumber(db.bannerScale) or ns.PlainNumber(db.fontScale) or 1
    if scale < 0.5 then
        scale = 0.5
    elseif scale > 2.0 then
        scale = 2.0
    end
    db.bannerScale = scale
    db.fontScale = scale

    local preview = ns.PlainNumber(db.previewTier)
    if not preview or preview < 1 or preview > #ns.tiers then
        preview = #ns.tiers
    end
    db.previewTier = math_floor(preview + 0.5)

    if db.sound == nil then
        db.sound = true
    end
    if not SOUND_CHANNEL_ORDER[db.soundChannel] then
        db.soundChannel = "Master"
    end
    local vol = ns.PlainNumber(db.soundVolume)
    if not vol then
        vol = 100
    end
    if vol < 0 then
        vol = 0
    elseif vol > 100 then
        vol = 100
    end
    db.soundVolume = math_floor(vol + 0.5)

    if db.chatAnnounce == nil then
        db.chatAnnounce = false
    end
    if not VALID_ANNOUNCE_CHANNELS[db.announceChannel] then
        db.announceChannel = "SELF"
    end
    if db.emoteAnnounce == nil then
        db.emoteAnnounce = false
    end
    if not VALID_EMOTE_TOKENS[db.emoteToken] then
        db.emoteToken = "ROAR"
    end

    if type(db.tiers) ~= "table" then
        db.tiers = {}
    end
    for i = 1, #ns.tiers do
        if db.tiers[i] == nil then
            db.tiers[i] = true
        else
            db.tiers[i] = db.tiers[i] and true or false
        end
    end
end

function ns:InitDB()
    AdoptCoreDB()
    if type(XiusKillStreakDB) ~= "table" then
        XiusKillStreakDB = {}
        if type(XiusUIDB) == "table" then
            XiusUIDB.killstreak = XiusKillStreakDB
        end
    end
    self.db = XiusKillStreakDB
    SanitizeDB(self.db)
end

function ns:SyncProfileDB()
    if type(XiusUIDB) == "table" and type(XiusUIDB.killstreak) == "table" then
        if self.db ~= XiusUIDB.killstreak then
            self.db = XiusUIDB.killstreak
        end
        if XiusKillStreakDB ~= XiusUIDB.killstreak then
            XiusKillStreakDB = XiusUIDB.killstreak
        end
    end
    if type(XiusKillStreakDB) ~= "table" then
        XiusKillStreakDB = {}
    end
    self.db = XiusKillStreakDB
    SanitizeDB(self.db)
end

function ns:ApplySettings()
    self:SyncProfileDB()
    if not self.db.enabled then
        self:StopSound()
        self:ResetStreak()
        if self.FinishBanner and not self.db.unlocked then
            self:FinishBanner()
        end
    end
    if self.ApplyBannerScale then
        self:ApplyBannerScale()
    end
    if self.ApplyBannerPosition then
        self:ApplyBannerPosition()
    end
    if self.ApplyCounterPosition then
        self:ApplyCounterPosition()
    end
    if self.UpdateLock then
        self:UpdateLock()
    end
    if self.UpdateCounter then
        self:UpdateCounter()
    end
end

function ns:IsTierEnabled(index)
    local db = XiusKillStreakDB
    if not db or type(db.tiers) ~= "table" then
        return true
    end
    return db.tiers[index] ~= false
end

function ns:SetTierEnabled(index, value)
    if type(XiusKillStreakDB) ~= "table" then
        self:InitDB()
    end
    if type(XiusKillStreakDB.tiers) ~= "table" then
        XiusKillStreakDB.tiers = {}
    end
    XiusKillStreakDB.tiers[index] = value and true or false
end

function ns:SetSoundVolume(percent, applyCVar)
    if type(XiusKillStreakDB) ~= "table" then
        self:InitDB()
    end
    local vol = ns.PlainNumber(percent) or 100
    if vol < 0 then
        vol = 0
    elseif vol > 100 then
        vol = 100
    end
    vol = math_floor(vol + 0.5)
    XiusKillStreakDB.soundVolume = vol
    -- Never write Sound_*Volume CVars: the slider is addon-local gain only.
end

function ns:UpdateInstanceState()
    self.inPvPInstance = false
    if type(IsInInstance) == "function" then
        local ok, inInstance, instanceType = pcall(IsInInstance)
        if ok and not IsSecret(inInstance) and not IsSecret(instanceType) and inInstance == true then
            if instanceType == "pvp" or instanceType == "arena" then
                self.inPvPInstance = true
            end
        end
    end
end

function ns:CurrentWindow()
    local db = XiusKillStreakDB
    local base = ns.PlainNumber(db and db.resetTimer) or self.BASE_COUNTDOWN or 25
    if base < 5 then
        base = 5
    elseif base > 60 then
        base = 60
    end
    local config = ns.tiers
    local index = self.firedTier
    if index and index > 0 and config[index] and config[index].countdown then
        if base == 25 then
            return config[index].countdown
        end
        return math_max(2, math_floor((config[index].countdown * (base / 25)) + 0.5))
    end
    return base
end

function ns:ResetStreak()
    self.streak = 0
    self.firedTier = 0
    self.lastKillAt = nil
    WipeRecords(self.recentKills)
    self.targetAliveAt = nil
    self.targetName = nil
    self.targetGUID = nil
    self.targetIsPlayer = nil
    self.targetIsTrivial = nil
    if self.UpdateCounter then
        self:UpdateCounter()
    end
end

function ns:StopSound()
    if self.soundHandle and type(self.soundHandle) == "number" and StopSound then
        pcall(StopSound, self.soundHandle, 0)
    end
    self.soundHandle = nil
end

function ns:NameIsSelf(name)
    name = ShortName(name)
    if not name then
        return false
    end
    local mine = self.playerName or ShortName(PlainString(UnitName, "player"))
    if mine then
        self.playerName = mine
    end
    return mine ~= nil and name == mine
end

function ns:GuidIsSelf(guid)
    guid = PublicString(guid)
    if not guid then
        return false
    end
    local myGuid = self.playerGUID or PlainString(UnitGUID, "player")
    if myGuid then
        self.playerGUID = myGuid
    end
    return myGuid ~= nil and guid == myGuid
end

function ns:IsCombatActive(now)
    now = PlainStamp(now)
    if not now then
        return self.inCombat and true or false
    end
    if self.inCombat then
        return true
    end
    if PlainBool(UnitAffectingCombat, "player") == true or PlainBool(UnitAffectingCombat, "pet") == true then
        self.inCombat = true
        self.lastCombatAt = now
        return true
    end
    local last = PlainStamp(self.lastCombatAt)
    if last and (now - last) <= 2.5 then
        return true
    end
    return false
end

function ns:PruneRecent(now)
    now = PlainStamp(now)
    if not now then
        return
    end
    local recent = self.recentKills
    for i = #recent, 1, -1 do
        local rec = recent[i]
        local at = type(rec) == "table" and PlainStamp(rec.at) or nil
        if not at or (now - at) > GUID_WINDOW then
            ReleaseRecord(rec)
            table_remove(recent, i)
        end
    end
end

local function IsKillPvP(self, guid, source, isPlayerHint)
    if source == "HONOR" then
        return true
    end
    if source == "XP" then
        return false
    end
    if guid then
        if string_find(guid, "^Player%-") then
            return true
        end
        if string_find(guid, "^Creature%-") or string_find(guid, "^Pet%-") or string_find(guid, "^Vehicle%-") then
            return false
        end
    end
    if isPlayerHint ~= nil then
        return isPlayerHint == true
    end
    if self.inPvPInstance then
        return true
    end
    return false
end

function ns:CreditKill(name, guid, source, happened, isPlayerHint, isTrivialHint)
    local db = XiusKillStreakDB
    if not db or not db.enabled then
        return
    end
    if PlainBool(UnitIsDeadOrGhost, "player") == true then
        return
    end

    local now = Now()
    if not now then
        return
    end
    if PlainStamp(happened) == nil or happened > now or (now - happened) > 3 then
        happened = now
    end
    local previousKill = PlainStamp(self.lastKillAt)
    if previousKill and happened < previousKill then
        happened = now
    end

    if source == true or source == "XP" then
        source = "XP"
    elseif type(source) ~= "string" or source == "" then
        source = "GENERIC"
    end

    name = ShortName(name)
    guid = PublicString(guid)
    if (name and self:NameIsSelf(name)) or (guid and self:GuidIsSelf(guid)) then
        return
    end

    local isPvP = IsKillPvP(self, guid, source, isPlayerHint)
    if isPvP then
        if db.trackPvP == false then
            return
        end
    else
        if db.trackPvE == false then
            return
        end
        if db.ignoreGray and source ~= "XP" then
            if isTrivialHint == true or (isTrivialHint == nil and PlainBool(UnitIsTrivial, "target") == true) then
                return
            end
        end
    end

    self:PruneRecent(now)

    local recent = self.recentKills

    -- 1. Exact GUID match: a specific unit GUID can only die once within GUID_WINDOW.
    if guid then
        for i = 1, #recent do
            local rec = recent[i]
            local seenAt = PlainStamp(rec.at)
            if rec.guid == guid and seenAt and (now - seenAt) < GUID_WINDOW then
                if name and not rec.name then
                    rec.name = name
                end
                if rec.sources then
                    rec.sources[source] = true
                end
                return
            end
        end
    end

    -- 2. Cross-source correlation: merge different signals (KB, SLAIN, XP, HONOR, PARTYKILL, TARGET)
    -- that fire within CORRELATE_WINDOW for the same death, while allowing multiple simultaneous
    -- signals from the SAME source (e.g. 5 XP gains or 5 KB floats in AoE) to count as 5 kills.
    if source ~= "GENERIC" then
        for i = 1, #recent do
            local rec = recent[i]
            local seenAt = PlainStamp(rec.at)
            if seenAt and (now - seenAt) <= CORRELATE_WINDOW and rec.sources and not rec.sources[source] then
                local nameMatch = (not rec.name) or (not name) or (rec.name == name)
                local guidMatch = (not rec.guid) or (not guid) or (rec.guid == guid)
                if nameMatch and guidMatch then
                    if name and not rec.name then
                        rec.name = name
                    end
                    if guid and not rec.guid then
                        rec.guid = guid
                    end
                    rec.sources[source] = true
                    return
                end
            end
        end
    end

    while #recent >= MAX_RECENT_KILLS do
        ReleaseRecord(table_remove(recent, 1))
    end

    local rec = AcquireRecord()
    rec.at = now
    rec.name = name
    rec.guid = guid
    rec.sources[source] = true
    recent[#recent + 1] = rec

    local window = self:CurrentWindow()
    if self.streak > 0 and previousKill and (happened - previousKill) <= window then
        self.streak = self.streak + 1
    else
        self.streak = 1
        self.firedTier = 0
    end
    self.lastKillAt = happened
    self:AnnounceIfNeeded()
    if self.UpdateCounter then
        self:UpdateCounter()
    end
    if StartTicker then
        StartTicker()
    end
end

local function TryPlaySoundFile(self, file, channel)
    local ok, first, second = pcall(PlaySoundFile, file, channel)
    if not ok then
        return false
    end
    -- Secret or boolean-only success still means audio started; do not fall through to another channel.
    if IsSecret(first) or IsSecret(second) then
        return true
    end
    if first == true then
        if type(second) == "number" and second > 0 then
            self.soundHandle = second
        end
        return true
    end
    if type(first) == "number" and first > 0 then
        self.soundHandle = first
        return true
    end
    -- Void success: the file already played. Do not retry other channels or slash paths.
    if first == nil and second == nil then
        return true
    end
    return false
end

function ns:PlaySound(path, force, forwardPath)
    if not path or path == "" or not PlaySoundFile then
        return
    end
    local db = XiusKillStreakDB
    if not force then
        if not (db and db.sound) then
            return
        end
        local volume = ns.PlainNumber(db.soundVolume)
        if volume ~= nil and volume <= 0 then
            return
        end
    end

    self:StopSound()

    local channels = SOUND_CHANNEL_ORDER[db and db.soundChannel or "Master"] or SOUND_CHANNEL_ORDER.Master
    for j = 1, #channels do
        if TryPlaySoundFile(self, path, channels[j]) then
            return
        end
    end
    local forward = forwardPath or string_gsub(path, "\\", "/")
    if forward ~= path then
        for j = 1, #channels do
            if TryPlaySoundFile(self, forward, channels[j]) then
                return
            end
        end
    end

    if force then
        self:Print("The sound did not play. Turn up the selected sound channel volume, then try again.")
    end
end

function ns:SendTierAnnouncement(tier, streakCount)
    local db = XiusKillStreakDB
    if not db or not tier then
        return
    end
    local count = streakCount or tier.streakCount or 0
    local title = tier.title or "Kill Streak"

    if db.chatAnnounce then
        local msg = string_format("%s! (%d Kill Streak)", title, count)
        local channel = db.announceChannel or "SELF"
        if channel == "SELF" or type(SendChatMessage) ~= "function" then
            self:Print(msg)
        elseif channel == "PARTY" then
            if PlainBool(IsInGroup) == true then
                local ok = pcall(SendChatMessage, msg, "PARTY")
                if not ok then
                    self:Print(msg)
                end
            else
                self:Print(msg)
            end
        elseif channel == "RAID" then
            local targetChat
            if LE_PARTY_CATEGORY_INSTANCE and PlainBool(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) == true then
                targetChat = "INSTANCE_CHAT"
            elseif PlainBool(IsInRaid) == true then
                targetChat = "RAID"
            elseif PlainBool(IsInGroup) == true then
                targetChat = "PARTY"
            end
            if targetChat then
                local ok = pcall(SendChatMessage, msg, targetChat)
                if not ok then
                    self:Print(msg)
                end
            else
                self:Print(msg)
            end
        elseif channel == "EMOTE" or channel == "SAY" or channel == "YELL" then
            local ok = pcall(SendChatMessage, msg, channel)
            if not ok then
                self:Print(msg)
            end
        else
            self:Print(msg)
        end
    end

    if db.emoteAnnounce and type(DoEmote) == "function" then
        local token = db.emoteToken
        if not VALID_EMOTE_TOKENS[token] then
            token = "ROAR"
        end
        pcall(DoEmote, token, "none")
    end
end

function ns:AnnounceTier(tier, streakCount)
    if not tier then
        return
    end
    local count = streakCount or tier.streakCount or 0
    local title = tier.upperTitle or string_upper(tier.title or "")
    local sub = (count == tier.streakCount and tier.testSub) or string_format("%d KILL STREAK!", count)
    self:ShowBanner(title, sub)
    self:PlaySound(tier.sound, false, tier.soundForward)
    self:SendTierAnnouncement(tier, count)
end

function ns:AnnounceIfNeeded()
    local config = ns.tiers
    local reached = self.firedTier or 0
    local index = reached
    local i = reached + 1
    while config[i] do
        if self.streak >= config[i].streakCount then
            index = i
        else
            break
        end
        i = i + 1
    end
    if index > reached then
        self.firedTier = index
        for t = index, reached + 1, -1 do
            if self:IsTierEnabled(t) then
                self:AnnounceTier(config[t], self.streak)
                break
            end
        end
    end
end

function ns:CheckExpiry()
    local last = PlainStamp(self.lastKillAt)
    if not self.streak or self.streak <= 0 or not last then
        return
    end
    local now = Now()
    if now and (now - last) > self:CurrentWindow() then
        self:ResetStreak()
    end
end

local function UnitIdentity(unit)
    if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
        if PlainBool(C_Secrets.ShouldUnitIdentityBeSecret, unit) == true then
            return nil, nil
        end
    end
    return ShortName(PlainString(UnitName, unit)), PlainString(UnitGUID, unit)
end

function ns:OnCombatText(eventType, name)
    if not self.loaded then
        return
    end
    local token = SafeText(eventType)
    if not token then
        return
    end
    token = string_upper(token)
    if token ~= "KILLINGBLOW" and token ~= "KILLING_BLOW" then
        return
    end

    local victim = ShortName(name)
    if not victim and GetCurrentCombatTextEventInfo then
        victim = ShortName(PlainString(GetCurrentCombatTextEventInfo))
    end
    self:CreditKill(victim, nil, "KB")
end

local function NameFromXP(text)
    local name = MatchPattern(text, "^(.+) dies,")
    if name then
        return name
    end
    name = MatchPattern(text, "^(.+) dies%.")
    if name then
        return name
    end

    EnsurePatterns()
    for i = 1, #xpPatterns do
        name = MatchPattern(text, xpPatterns[i])
        if name then
            return name
        end
    end
    return nil
end

local function IsQuestXP(text)
    text = SafeText(text)
    if not text then
        return true
    end
    if string_find(text, "dies", 1, true) then
        return false
    end
    EnsurePatterns()
    if unnamedXPPrefix and string_sub(text, 1, string_len(unnamedXPPrefix)) == unnamedXPPrefix then
        return true
    end
    return string_find(text, "^You gain ") and true or false
end

function ns:OnXPGain(message)
    if not self.loaded then
        return
    end

    local now = Now()
    if not now then
        return
    end
    local turnin = PlainStamp(self.lastQuestTurnin)
    local recentQuest = turnin and (now - turnin) < 1.5

    -- In Modern WoW / Forever, XP messages from mob deaths in combat may be marked secret
    -- because they embed the secret enemy unit name. Quest/discovery XP has no enemy name.
    if IsSecret(message) then
        if not recentQuest then
            self:CreditKill(nil, nil, "XP")
        end
        return
    end

    local text = SafeText(message)
    if not text then
        return
    end

    local name = NameFromXP(text)
    if recentQuest and not name and IsQuestXP(text) then
        return
    end
    if name then
        self:CreditKill(name, nil, "XP")
        return
    end
    if IsQuestXP(text) then
        return
    end

    if string_find(text, "dies", 1, true) then
        self:CreditKill(nil, nil, "XP")
    end
end

function ns:OnHonorGain(message)
    if not self.loaded then
        return
    end
    if IsSecret(message) then
        self:CreditKill(nil, nil, "HONOR")
        return
    end
    local text = SafeText(message)
    if not text then
        return
    end
    local name = MatchPattern(text, "^(.+) dies,")
    if not name then
        EnsurePatterns()
        for i = 1, #honorPatterns do
            name = MatchPattern(text, honorPatterns[i])
            if name then
                break
            end
        end
    end
    if name or string_find(text, "dies", 1, true) then
        self:CreditKill(name, nil, "HONOR")
    end
end

function ns:OnHostileDeathChat(message)
    if not self.loaded then
        return
    end
    local text = SafeText(message)
    if not text then
        return
    end

    EnsurePatterns()
    local name = MatchPattern(text, slainPattern)
    if not name then
        name = MatchPattern(text, "^You have slain (.+)!$")
    end
    if name then
        self:CreditKill(name, nil, "SLAIN")
    end
end

function ns:OnPartyKill(attackerGUID, targetGUID)
    if not self.loaded then
        return
    end
    local victimGUID = PublicString(targetGUID)
    if IsSecret(attackerGUID) then
        -- When solo, any PARTY_KILL event is guaranteed to be our own or our pet's kill.
        if PlainBool(IsInGroup) ~= true then
            self:CreditKill(nil, victimGUID, "PARTYKILL")
        end
        return
    end
    local killerGUID = PublicString(attackerGUID)
    if not killerGUID then
        return
    end
    local playerGUID = self.playerGUID or PlainString(UnitGUID, "player")
    if playerGUID then
        self.playerGUID = playerGUID
    end
    local petGUID = PlainString(UnitGUID, "pet")
    local vehicleGUID = PlainString(UnitGUID, "vehicle")
    if (playerGUID and killerGUID == playerGUID) or (petGUID and killerGUID == petGUID) or (vehicleGUID and killerGUID == vehicleGUID) then
        self:CreditKill(nil, victimGUID, "PARTYKILL")
    end
end

local function ClearTargetState(self)
    self.targetAliveAt = nil
    self.targetName = nil
    self.targetGUID = nil
    self.targetIsPlayer = nil
    self.targetIsTrivial = nil
end

function ns:WatchTarget(fromTargetChange)
    if not TrackingEnabled() then
        return
    end
    if PlainBool(UnitExists, "target") ~= true then
        ClearTargetState(self)
        return
    end

    local isDead = PlainBool(UnitIsDeadOrGhost, "target")
    if isDead == nil then
        return
    end

    -- Fast path: target is still alive and already tracked from PLAYER_TARGET_CHANGED.
    if not isDead and not fromTargetChange and self.targetAliveAt then
        return
    end

    if PlainBool(UnitIsUnit, "target", "player") ~= false then
        ClearTargetState(self)
        return
    end

    if UnitIsFeignDeath and PlainBool(UnitIsFeignDeath, "target") == true then
        return
    end

    local now = Now()
    if not now then
        return
    end

    if not isDead then
        if PlainBool(UnitCanAttack, "player", "target") ~= true then
            ClearTargetState(self)
            return
        end
        if UnitIsTapDenied and PlainBool(UnitIsTapDenied, "target") == true then
            ClearTargetState(self)
            return
        end
        local name, guid = UnitIdentity("target")
        self.targetAliveAt = now
        self.targetName = name
        self.targetGUID = guid
        self.targetIsPlayer = PlainBool(UnitIsPlayer, "target")
        self.targetIsTrivial = UnitIsTrivial and PlainBool(UnitIsTrivial, "target") or nil
        if StartTicker then
            StartTicker()
        end
        return
    end

    -- Never credit a unit that was already dead when the player first targeted it.
    if fromTargetChange then
        ClearTargetState(self)
        return
    end

    local seen = self.targetAliveAt
    local savedName = self.targetName
    local savedGUID = self.targetGUID
    local savedIsPlayer = self.targetIsPlayer
    local savedIsTrivial = self.targetIsTrivial
    ClearTargetState(self)

    if not PlainStamp(seen) then
        return
    end
    local name, guid = UnitIdentity("target")
    if savedGUID and guid and savedGUID ~= guid then
        return
    end
    if self:IsCombatActive(now) then
        self:CreditKill(name or savedName, guid or savedGUID, "TARGET", nil, savedIsPlayer, savedIsTrivial)
    end
end

function ns:Test(index)
    if not self.banner then
        self:Print("Still loading. Try again in a moment.")
        return
    end
    local tier = ns.tiers[index]
    if not tier then
        self:Print("Use /xks test for Toasty, or /xks test 1 through 10.")
        return
    end
    local title = tier.upperTitle or string_upper(tier.title or "")
    local sub = tier.testSub or string_format("%d KILL STREAK!", tier.streakCount or index)
    self:ShowBanner(title, sub)
    self:PlaySound(tier.sound, true, tier.soundForward)
end

function ns:HandleSlash(message)
    local text = string_lower(Trim(SafeText(message) or ""))
    if text == "" or text == "options" or text == "config" then
        local Lib = _G.XiusCoreSettingsLib
        if not self.loaded then
            self:Print("Still loading. Try /xks again in a moment.")
            return
        end
        if self.InLockdown and self.InLockdown() then
            self:Print("Cannot open the Settings window in combat. Use /xks unlock, /xks lock, /xks sound, or /xks reset.")
            return
        end
        if not self.optionsReady and self.SetupOptions then
            self:SetupOptions()
        end
        if Lib and Lib.OpenModule then
            Lib:OpenModule("KillStreak")
            return
        end
        self:OpenOptions()
        return
    end
    if text == "test" then
        self:Test(10)
        return
    end
    if text == "reset" or text == "clear" then
        self:ResetStreak()
        self:Print("Streak cleared.")
        return
    end
    if text == "resetpos" or text == "default" then
        self:ResetPositions()
        self:Print("Banner and counter positions reset to default.")
        return
    end
    if text == "unlock" then
        self:SetUnlocked(true)
        self:Print("Banner and counter unlocked. Drag to move.")
        return
    end
    if text == "lock" then
        self:SetUnlocked(false)
        self:Print("Banner and counter locked.")
        return
    end
    if text == "sound" then
        local nextState = not (XiusKillStreakDB and XiusKillStreakDB.sound)
        self:SetSoundEnabled(nextState)
        self:Print("Streak sounds " .. (nextState and "enabled." or "disabled."))
        return
    end
    if text == "on" or text == "enable" then
        self:SetEnabled(true)
        self:Print("Kill streaks enabled.")
        return
    end
    if text == "off" or text == "disable" then
        self:SetEnabled(false)
        self:Print("Kill streaks disabled.")
        return
    end

    local tierText = string_match(text, "^test%s+(%d+)$")
    if tierText then
        local tier = tonumber(tierText)
        if tier and tier >= 1 and tier <= #ns.tiers then
            self:Test(tier)
        else
            self:Print("Pick a tier from 1 to " .. tostring(#ns.tiers) .. ".")
        end
        return
    end

    self:Print("Commands: /xks (options), /xks test [1-10], /xks reset, /xks unlock, /xks lock, /xks resetpos, /xks sound, /xks on, /xks off.")
end

function ns:OnLoaded()
    if self.loaded then
        return
    end
    self:InitDB()
    EnsurePatterns()
    self.streak = 0
    self.firedTier = 0
    self.lastKillAt = nil
    WipeRecords(self.recentKills)
    ClearTargetState(self)
    self.inCombat = PlainBool(UnitAffectingCombat, "player") == true
    self.lastCombatAt = self.inCombat and (Now() or 0) or 0
    self.lastQuestTurnin = 0
    self.playerName = ShortName(PlainString(UnitName, "player"))
    self.playerGUID = PlainString(UnitGUID, "player")
    self:UpdateInstanceState()
    self:CreateBanner()
    self:CreateCounter()
    if self.RegisterMovers then
        self:RegisterMovers()
    end
    self:ApplyBannerScale()
    self:ApplyBannerPosition()
    self:ApplyCounterPosition()
    self.loaded = true
    pcall(eventFrame.UnregisterEvent, eventFrame, "ADDON_LOADED")
    self:RegisterTrackingEvents()
    self:SetupOptions()
    self:UpdateLock()
    if self.inCombat then
        StartTicker()
    end
end

local function EventAllowed(eventName)
    if RESTRICTED_EVENTS[eventName] then
        return false
    end
    if C_EventUtils and C_EventUtils.IsEventValid then
        local ok, valid = pcall(C_EventUtils.IsEventValid, eventName)
        if ok and valid == false then
            return false
        end
    end
    return true
end

local function RegisterSafe(frame, eventName)
    if not EventAllowed(eventName) then
        return false
    end
    return pcall(frame.RegisterEvent, frame, eventName)
end

local function RegisterUnitSafe(frame, eventName, unit)
    if not EventAllowed(eventName) then
        return false
    end
    if frame.RegisterUnitEvent then
        local ok = pcall(frame.RegisterUnitEvent, frame, eventName, unit)
        if ok then
            return true
        end
    end
    return pcall(frame.RegisterEvent, frame, eventName)
end

RegisterSafe(eventFrame, "ADDON_LOADED")
RegisterSafe(eventFrame, "PLAYER_LOGIN")

function ns:RegisterTrackingEvents()
    if self.trackingEventsRegistered then
        return
    end
    self.trackingEventsRegistered = true
    RegisterSafe(eventFrame, "PLAYER_ENTERING_WORLD")
    RegisterSafe(eventFrame, "PLAYER_DEAD")
    RegisterSafe(eventFrame, "PLAYER_REGEN_DISABLED")
    RegisterSafe(eventFrame, "PLAYER_REGEN_ENABLED")
    RegisterSafe(eventFrame, "PLAYER_ENTER_COMBAT")
    RegisterSafe(eventFrame, "COMBAT_TEXT_UPDATE")
    RegisterSafe(eventFrame, "CHAT_MSG_COMBAT_HOSTILE_DEATH")
    RegisterSafe(eventFrame, "CHAT_MSG_COMBAT_XP_GAIN")
    RegisterSafe(eventFrame, "CHAT_MSG_COMBAT_HONOR_GAIN")
    RegisterSafe(eventFrame, "PARTY_KILL")
    RegisterSafe(eventFrame, "QUEST_COMPLETE")
    RegisterSafe(eventFrame, "QUEST_TURNED_IN")
    RegisterSafe(eventFrame, "PLAYER_TARGET_CHANGED")
    RegisterUnitSafe(eventFrame, "UNIT_HEALTH", "target")
end

local function TickerOnUpdate(self, elapsed)
    if not ns.loaded or not TrackingEnabled() then
        self.tickerActive = false
        self:SetScript("OnUpdate", nil)
        return
    end
    if type(elapsed) ~= "number" or elapsed < 0 then
        return
    end
    if elapsed > 1 then
        elapsed = 1
    end
    self.accum = self.accum + elapsed
    if self.accum < 0.2 then
        return
    end
    self.accum = 0

    local now = Now()
    if not now then
        return
    end
    local hasStreak = ns.streak and ns.streak > 0
    local hasRecent = #ns.recentKills > 0
    local combatActive = ns:IsCombatActive(now)

    if hasStreak then
        if PlainBool(UnitIsDeadOrGhost, "player") == true then
            ns:ResetStreak()
            hasStreak = false
        else
            ns:CheckExpiry()
            hasStreak = ns.streak and ns.streak > 0
        end
    end
    if hasRecent then
        ns:PruneRecent(now)
        hasRecent = #ns.recentKills > 0
    end
    if ns.targetAliveAt then
        ns:WatchTarget(false)
    end
    if hasStreak or (XiusKillStreakDB and XiusKillStreakDB.unlocked) then
        ns:UpdateCounter()
    end

    if not hasStreak and not hasRecent and not combatActive and not ns.targetAliveAt then
        self.tickerActive = false
        self:SetScript("OnUpdate", nil)
    end
end

StartTicker = function()
    if not TrackingEnabled() then
        if eventFrame.tickerActive then
            eventFrame.tickerActive = false
            eventFrame:SetScript("OnUpdate", nil)
        end
        return
    end
    if not eventFrame.tickerActive then
        eventFrame.tickerActive = true
        eventFrame.accum = 0
        eventFrame:SetScript("OnUpdate", TickerOnUpdate)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if PublicString(arg1) == ns.ADDON_NAME then
            ns:OnLoaded()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        if not ns.loaded then
            ns:OnLoaded()
        else
            ns:SetupOptions()
        end
        return
    end
    if not ns.loaded then
        return
    end
    if event == "PLAYER_DEAD" then
        ns:ResetStreak()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.playerName = ShortName(PlainString(UnitName, "player")) or ns.playerName
        ns.playerGUID = PlainString(UnitGUID, "player") or ns.playerGUID
        ns:UpdateInstanceState()
    elseif event == "COMBAT_TEXT_UPDATE" then
        ns:OnCombatText(arg1, arg2)
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        ns:OnHostileDeathChat(arg1)
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        ns:OnXPGain(arg1)
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        ns:OnHonorGain(arg1)
    elseif event == "PARTY_KILL" then
        ns:OnPartyKill(arg1, arg2)
    elseif event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" then
        local now = Now()
        if now then
            ns.lastQuestTurnin = now
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ClearTargetState(ns)
        ns:WatchTarget(true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.inCombat = true
        local now = Now()
        if now then
            ns.lastCombatAt = now
        end
        StartTicker()
        ns:WatchTarget(false)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.inCombat = false
        local now = Now()
        if now then
            ns.lastCombatAt = now
        end
        if ns.FlushLayout then
            ns:FlushLayout()
        end
        StartTicker()
        ns:WatchTarget(false)
    elseif event == "PLAYER_ENTER_COMBAT" then
        local now = Now()
        if now then
            ns.lastCombatAt = now
        end
        StartTicker()
        ns:WatchTarget(false)
    elseif event == "UNIT_HEALTH" then
        if not arg1 or PublicString(arg1) == "target" then
            ns:WatchTarget(false)
        end
    end
end)

do
    local core = _G.XiusCore
    if core and core.RegisterModule then
        core:RegisterModule("KillStreak", ns)
    end
end

SLASH_XIUSKILLSTREAK1 = "/xks"
SLASH_XIUSKILLSTREAK2 = "/xiuskillstreak"
SlashCmdList.XIUSKILLSTREAK = function(message)
    ns:HandleSlash(message)
end
