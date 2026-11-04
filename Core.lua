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

XiusKillStreak = XiusKillStreak or {}

XiusKillStreak.streak = 0
XiusKillStreak.firedTier = 0
XiusKillStreak.lastKillAt = nil
XiusKillStreak.loaded = false
XiusKillStreak.recentKills = {}
XiusKillStreak.aliveWatch = {}
XiusKillStreak.targetAliveAt = nil
XiusKillStreak.targetName = nil
XiusKillStreak.targetGUID = nil
XiusKillStreak.inCombat = false
XiusKillStreak.lastCombatAt = 0
XiusKillStreak.lastQuestTurnin = 0
XiusKillStreak.lastXPAt = 0
XiusKillStreak.lastCountedAt = 0
XiusKillStreak.lastCountedName = nil
XiusKillStreak.pendingNameless = nil
XiusKillStreak.soundHandle = nil

local pcall = pcall
local type = type
local tostring = tostring
local tonumber = tonumber
local print = print
local GetTime = GetTime
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local string_upper = string.upper
local table_remove = table.remove

local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue

local CORRELATE_WINDOW = 0.35
local GUID_WINDOW = 5.0
local SOUND_CHANNELS = { "Master", "Dialog", "SFX" }

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

local function IsTrue(value)
    return value == true
end

local function IsSecret(value)
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
    name = Trim(name)
    if name == "" then
        return nil
    end
    local short = string_match(name, "^([^%-]+)")
    if short and short ~= "" then
        return short
    end
    return name
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

function XiusKillStreak:Print(text)
    print("Xius Kill Streak: " .. tostring(text))
end

function XiusKillStreak:InitDB()
    if type(XiusKillStreakDB) ~= "table" then
        XiusKillStreakDB = {}
    end
    local db = XiusKillStreakDB
    if db.enabled == nil then
        db.enabled = true
    end
    if db.sound == nil then
        db.sound = true
    end
    if db.unlocked == nil then
        db.unlocked = false
    end
end

function XiusKillStreak:CurrentWindow()
    local config = XiusKillStreak_Config
    local index = self.firedTier
    if index and index > 0 and config[index] and config[index].countdown then
        return config[index].countdown
    end
    if self.BASE_COUNTDOWN then
        return self.BASE_COUNTDOWN
    end
    return 25
end

function XiusKillStreak:ResetStreak()
    self.streak = 0
    self.firedTier = 0
    self.lastKillAt = nil
    self.recentKills = {}
    self.aliveWatch = {}
    self.targetAliveAt = nil
    self.targetName = nil
    self.targetGUID = nil
    self.pendingNameless = nil
    self.lastCountedName = nil
    if self.UpdateCounter then
        self:UpdateCounter()
    end
end

function XiusKillStreak:StopSound()
    if self.soundHandle and type(self.soundHandle) == "number" and StopSound then
        pcall(StopSound, self.soundHandle, 0)
    end
    self.soundHandle = nil
end

function XiusKillStreak:NameIsSelf(name)
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

function XiusKillStreak:GuidIsSelf(guid)
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

function XiusKillStreak:IsCombatActive(now)
    if self.inCombat then
        return true
    end
    if PlainBool(UnitAffectingCombat, "player") == true or PlainBool(UnitAffectingCombat, "pet") == true then
        self.inCombat = true
        self.lastCombatAt = now
        return true
    end
    if self.lastCombatAt and (now - self.lastCombatAt) <= 2.5 then
        return true
    end
    return false
end

function XiusKillStreak:PruneRecent(now)
    local recent = self.recentKills
    for i = #recent, 1, -1 do
        local rec = recent[i]
        if type(rec) ~= "table" or type(rec.at) ~= "number" or (now - rec.at) > GUID_WINDOW then
            table_remove(recent, i)
        end
    end
end

function XiusKillStreak:QueueNameless(source)
    self:CreditKill(nil, nil, source or "GENERIC")
end

function XiusKillStreak:FlushPending()
    local pending = self.pendingNameless
    if type(pending) ~= "table" then
        self.pendingNameless = nil
        return
    end
    self.pendingNameless = nil
    local count = pending.count or 1
    if count > 8 then
        count = 8
    end
    for _ = 1, count do
        self:CreditKill(nil, nil, "GENERIC", pending.at)
    end
end

function XiusKillStreak:CreditKill(name, guid, source, happened)
    if not XiusKillStreakDB or not XiusKillStreakDB.enabled then
        return
    end
    if PlainBool(UnitIsDeadOrGhost, "player") == true then
        return
    end

    local now = GetTime()
    if type(happened) ~= "number" or happened > now or (now - happened) > 3 then
        happened = now
    end
    if self.lastKillAt and happened < self.lastKillAt then
        happened = now
    end

    local fromXP = false
    if source == true or source == "XP" then
        source = "XP"
        fromXP = true
    elseif type(source) ~= "string" or source == "" then
        source = "GENERIC"
    end

    name = ShortName(name)
    guid = PublicString(guid)
    if (name and self:NameIsSelf(name)) or (guid and self:GuidIsSelf(guid)) then
        return
    end

    self:PruneRecent(now)

    local recent = self.recentKills

    -- 1. Exact GUID match: a specific unit GUID can only die once within GUID_WINDOW.
    if guid then
        for i = 1, #recent do
            local rec = recent[i]
            if rec.guid == guid and (now - rec.at) < GUID_WINDOW then
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
            if (now - rec.at) <= CORRELATE_WINDOW and rec.sources and not rec.sources[source] then
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
                    if fromXP then
                        self.lastXPAt = now
                    end
                    return
                end
            end
        end
    end

    recent[#recent + 1] = {
        at = now,
        name = name,
        guid = guid,
        sources = { [source] = true },
    }

    if fromXP then
        self.lastXPAt = now
    end
    self.lastCountedAt = now
    self.lastCountedName = name

    local window = self:CurrentWindow()
    if self.streak > 0 and self.lastKillAt and (happened - self.lastKillAt) <= window then
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
    if not ok or IsSecret(first) or IsSecret(second) then
        return false
    end
    if first == true then
        if type(second) == "number" then
            self.soundHandle = second
        end
        return true
    end
    if type(first) == "number" then
        self.soundHandle = first
        return true
    end
    return false
end

function XiusKillStreak:PlaySound(path, force)
    if not path or path == "" or not PlaySoundFile then
        return
    end
    if not force and not (XiusKillStreakDB and XiusKillStreakDB.sound) then
        return
    end

    self:StopSound()

    local forward = string_gsub(path, "\\", "/")
    for j = 1, #SOUND_CHANNELS do
        if TryPlaySoundFile(self, path, SOUND_CHANNELS[j]) then
            return
        end
    end
    if forward ~= path then
        for j = 1, #SOUND_CHANNELS do
            if TryPlaySoundFile(self, forward, SOUND_CHANNELS[j]) then
                return
            end
        end
    end

    if force then
        self:Print("The sound did not play. Turn up the Master volume, then try again.")
    end
end

function XiusKillStreak:AnnounceTier(tier, streakCount)
    if not tier then
        return
    end
    local title = string_upper(tier.title or "")
    local sub = string_format("%d KILL STREAK!", streakCount or tier.streakCount or 0)
    self:ShowBanner(title, sub)
    self:PlaySound(tier.sound, false)
end

function XiusKillStreak:AnnounceIfNeeded()
    local config = XiusKillStreak_Config
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
        self:AnnounceTier(config[index], self.streak)
    end
end

function XiusKillStreak:CheckExpiry()
    if not self.streak or self.streak <= 0 or not self.lastKillAt then
        return
    end
    if (GetTime() - self.lastKillAt) > self:CurrentWindow() then
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

function XiusKillStreak:OnCombatText(eventType, name)
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

function XiusKillStreak:OnXPGain(message)
    if not self.loaded then
        return
    end

    local now = GetTime()
    local recentQuest = self.lastQuestTurnin and (now - self.lastQuestTurnin) < 1.5

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

function XiusKillStreak:OnHonorGain(message)
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

function XiusKillStreak:OnHostileDeathChat(message)
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

function XiusKillStreak:OnPartyKill(attackerGUID, targetGUID)
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

function XiusKillStreak:WatchTarget(fromTargetChange)
    if PlainBool(UnitExists, "target") ~= true then
        self.targetAliveAt = nil
        self.targetName = nil
        self.targetGUID = nil
        return
    end
    if PlainBool(UnitIsUnit, "target", "player") ~= false then
        self.targetAliveAt = nil
        self.targetName = nil
        self.targetGUID = nil
        return
    end

    local now = GetTime()
    local dead = PlainBool(UnitIsDead, "target")
    local ghost = PlainBool(UnitIsDeadOrGhost, "target")
    if dead == nil and ghost == nil then
        return
    end
    if UnitIsFeignDeath and PlainBool(UnitIsFeignDeath, "target") == true then
        return
    end

    local isDead = (dead == true) or (ghost == true)
    local name, guid = UnitIdentity("target")

    if not isDead then
        if PlainBool(UnitCanAttack, "player", "target") ~= true then
            self.targetAliveAt = nil
            self.targetName = nil
            self.targetGUID = nil
            return
        end
        if UnitIsTapDenied and PlainBool(UnitIsTapDenied, "target") == true then
            self.targetAliveAt = nil
            self.targetName = nil
            self.targetGUID = nil
            return
        end
        self.targetAliveAt = now
        if name then
            self.targetName = name
        end
        if guid then
            self.targetGUID = guid
        end
        if StartTicker then
            StartTicker()
        end
        return
    end

    -- Never credit a unit that was already dead when the player first targeted it.
    if fromTargetChange then
        self.targetAliveAt = nil
        self.targetName = nil
        self.targetGUID = nil
        return
    end

    local seen = self.targetAliveAt
    local savedName = self.targetName
    local savedGUID = self.targetGUID
    self.targetAliveAt = nil
    self.targetName = nil
    self.targetGUID = nil

    if savedGUID and guid and savedGUID ~= guid then
        return
    end
    if type(seen) == "number" and self:IsCombatActive(now) then
        self:CreditKill(name or savedName, guid or savedGUID, "TARGET")
    end
end

function XiusKillStreak:Test(index)
    if not self.banner then
        self:Print("Still loading. Try again in a moment.")
        return
    end
    local tier = XiusKillStreak_Config[index]
    if not tier then
        self:Print("Use /xks test for Toasty, or /xks test 1 through 10.")
        return
    end
    local title = string_upper(tier.title or "")
    local sub = string_format("%d KILL STREAK!", tier.streakCount or index)
    self:ShowBanner(title, sub)
    self:PlaySound(tier.sound, true)
end

function XiusKillStreak:HandleSlash(message)
    local text = string_lower(Trim(SafeText(message) or ""))
    if text == "" or text == "options" or text == "config" then
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
        if tier and tier >= 1 and tier <= #XiusKillStreak_Config then
            self:Test(tier)
        else
            self:Print("Pick a tier from 1 to " .. tostring(#XiusKillStreak_Config) .. ".")
        end
        return
    end

    self:Print("Commands: /xks (options), /xks test [1-10], /xks reset, /xks unlock, /xks lock, /xks resetpos, /xks sound, /xks on, /xks off.")
end

function XiusKillStreak:OnLoaded()
    if self.loaded then
        return
    end
    self:InitDB()
    EnsurePatterns()
    self.streak = 0
    self.firedTier = 0
    self.lastKillAt = nil
    self.recentKills = {}
    self.aliveWatch = {}
    self.targetAliveAt = nil
    self.targetName = nil
    self.targetGUID = nil
    self.inCombat = PlainBool(UnitAffectingCombat, "player") == true
    self.lastCombatAt = self.inCombat and GetTime() or 0
    self.lastQuestTurnin = 0
    self.lastXPAt = 0
    self.lastCountedAt = 0
    self.lastCountedName = nil
    self.pendingNameless = nil
    self.playerName = ShortName(PlainString(UnitName, "player"))
    self.playerGUID = PlainString(UnitGUID, "player")
    self:CreateBanner()
    self:CreateCounter()
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

function XiusKillStreak:RegisterTrackingEvents()
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
    if not XiusKillStreak.loaded then
        return
    end
    self.accum = self.accum + elapsed
    if self.accum < 0.2 then
        return
    end
    self.accum = 0

    local now = GetTime()
    local hasStreak = XiusKillStreak.streak and XiusKillStreak.streak > 0
    local hasRecent = #XiusKillStreak.recentKills > 0
    local hasPending = XiusKillStreak.pendingNameless ~= nil
    local combatActive = XiusKillStreak:IsCombatActive(now)

    if hasPending then
        XiusKillStreak:FlushPending()
    end
    if hasStreak then
        if PlainBool(UnitIsDeadOrGhost, "player") == true then
            XiusKillStreak:ResetStreak()
            hasStreak = false
        else
            XiusKillStreak:CheckExpiry()
            hasStreak = XiusKillStreak.streak and XiusKillStreak.streak > 0
        end
    end
    if hasRecent then
        XiusKillStreak:PruneRecent(now)
        hasRecent = #XiusKillStreak.recentKills > 0
    end
    if combatActive or XiusKillStreak.targetAliveAt then
        XiusKillStreak:WatchTarget(false)
    end
    if hasStreak or (XiusKillStreakDB and XiusKillStreakDB.unlocked) then
        XiusKillStreak:UpdateCounter()
    end

    if not hasStreak and not hasRecent and XiusKillStreak.pendingNameless == nil and not combatActive and not XiusKillStreak.targetAliveAt then
        self.tickerActive = false
        self:SetScript("OnUpdate", nil)
    end
end

StartTicker = function()
    if not eventFrame.tickerActive then
        eventFrame.tickerActive = true
        eventFrame.accum = 0
        eventFrame:SetScript("OnUpdate", TickerOnUpdate)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if PublicString(arg1) == "XiusKillStreak" then
            XiusKillStreak:OnLoaded()
        end
        return
    end
    if not XiusKillStreak.loaded then
        return
    end
    if event == "PLAYER_DEAD" then
        XiusKillStreak:ResetStreak()
    elseif event == "PLAYER_ENTERING_WORLD" then
        XiusKillStreak.playerName = ShortName(PlainString(UnitName, "player")) or XiusKillStreak.playerName
        XiusKillStreak.playerGUID = PlainString(UnitGUID, "player") or XiusKillStreak.playerGUID
    elseif event == "COMBAT_TEXT_UPDATE" then
        XiusKillStreak:OnCombatText(arg1, arg2)
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        XiusKillStreak:OnHostileDeathChat(arg1)
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        XiusKillStreak:OnXPGain(arg1)
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        XiusKillStreak:OnHonorGain(arg1)
    elseif event == "PARTY_KILL" then
        XiusKillStreak:OnPartyKill(arg1, arg2)
    elseif event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" then
        XiusKillStreak.lastQuestTurnin = GetTime()
    elseif event == "PLAYER_TARGET_CHANGED" then
        XiusKillStreak.targetAliveAt = nil
        XiusKillStreak.targetName = nil
        XiusKillStreak.targetGUID = nil
        XiusKillStreak:WatchTarget(true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        XiusKillStreak.inCombat = true
        XiusKillStreak.lastCombatAt = GetTime()
        StartTicker()
        XiusKillStreak:WatchTarget(false)
    elseif event == "PLAYER_REGEN_ENABLED" then
        XiusKillStreak.inCombat = false
        XiusKillStreak.lastCombatAt = GetTime()
        StartTicker()
        XiusKillStreak:WatchTarget(false)
    elseif event == "PLAYER_ENTER_COMBAT" then
        XiusKillStreak.lastCombatAt = GetTime()
        StartTicker()
        XiusKillStreak:WatchTarget(false)
    elseif event == "UNIT_HEALTH" then
        if not arg1 or PublicString(arg1) == "target" then
            XiusKillStreak:WatchTarget(false)
        end
    end
end)

SLASH_XIUSKILLSTREAK1 = "/xks"
SLASH_XIUSKILLSTREAK2 = "/xiuskillstreak"
SlashCmdList.XIUSKILLSTREAK = function(message)
    XiusKillStreak:HandleSlash(message)
end
