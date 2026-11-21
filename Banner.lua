--[[
    Bloody streak banner and the gold-bordered streak counter.
    The banner is the only place the custom fonts are used.
    The counter uses the same metallic gold Blizzard frame as the other Xius HUD plates.
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

local TITLE_SIZE = 44
local SUB_SIZE = 20
local DEFAULT_COUNTER_W = 200
local DEFAULT_COUNTER_H = 84
local MIN_COUNTER_W = 180
local MIN_COUNTER_H = 72
local MAX_COUNTER_W = 420
local MAX_COUNTER_H = 180

local math_floor = math.floor
local math_max = math.max
local string_format = string.format
local string_gsub = string.gsub
local pcall = pcall
local type = type
local CreateFrame = CreateFrame

local layoutQueued = false
local pendingTitle
local pendingSub

local function Defer(frame)
    if frame and frame._protected and ns.InLockdown() then
        layoutQueued = true
        return true
    end
    return false
end

local function SetMouse(frame, enabled)
    enabled = enabled and true or false
    if frame.mouseEnabled == enabled then
        return
    end
    if Defer(frame) then
        return
    end
    frame.mouseEnabled = enabled
    frame:EnableMouse(enabled)
end

local function SetShown(frame, shown)
    local visible = frame:IsShown() and true or false
    if shown == visible then
        return
    end
    if Defer(frame) then
        return
    end
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function TrySetFont(fontObject, path, size)
    if not fontObject or not fontObject.SetFont or not path or path == "" then
        return false
    end
    local ok, result = pcall(fontObject.SetFont, fontObject, path, size, "OUTLINE")
    if ok and result then
        return true
    end
    local forward = string_gsub(path, "\\", "/")
    if forward ~= path then
        ok, result = pcall(fontObject.SetFont, fontObject, forward, size, "OUTLINE")
        if ok and result then
            return true
        end
    end
    return false
end

function ns:ApplyFontObject(fontObject, size, primaryPath, secondaryPath)
    if TrySetFont(fontObject, primaryPath, size) then
        return
    end
    if TrySetFont(fontObject, secondaryPath, size) then
        return
    end
    local fallback = self.FALLBACK_FONT or "Fonts\\FRIZQT__.TTF"
    if not TrySetFont(fontObject, fallback, size) then
        pcall(fontObject.SetFont, fontObject, fallback, size, "")
    end
end

function ns:GetBannerScale()
    local db = XiusKillStreakDB
    local scale = ns.PlainNumber(db and (db.bannerScale or db.fontScale)) or 1
    if scale < 0.5 then
        scale = 0.5
    elseif scale > 2.0 then
        scale = 2.0
    end
    return scale
end

function ns:ApplyBannerScale()
    local banner = self.banner
    if not banner then
        return
    end
    local scale = self:GetBannerScale()
    local w = math_max(360, math_floor((720 * scale) + 0.5))
    local h = math_max(60, math_floor((120 * scale) + 0.5))
    if not Defer(banner) then
        banner:SetSize(w, h)
    end
    if banner.content then
        banner.content:SetSize(w, h)
    end
    local titleSize = math_max(18, math_floor((TITLE_SIZE * scale) + 0.5))
    local subSize = math_max(10, math_floor((SUB_SIZE * scale) + 0.5))
    if banner.title then
        self:ApplyFontObject(banner.title, titleSize, self.TITLE_FONT, self.SUB_FONT)
        banner.title:ClearAllPoints()
        banner.title:SetPoint("CENTER", banner.content, "CENTER", 0, math_floor((18 * scale) + 0.5))
    end
    if banner.sub and banner.title then
        self:ApplyFontObject(banner.sub, subSize, self.SUB_FONT, self.TITLE_FONT)
        banner.sub:ClearAllPoints()
        banner.sub:SetPoint("TOP", banner.title, "BOTTOM", 0, -math_max(2, math_floor((4 * scale) + 0.5)))
    end
    self:StyleBannerText()
end

ns.ApplyFontScale = ns.ApplyBannerScale

local function SetBannerAlpha(banner, alpha)
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    if banner.currentAlpha ~= alpha then
        banner.currentAlpha = alpha
        banner:SetAlpha(alpha)
    end
end

local function BannerOnUpdate(frame, elapsed)
    if not frame.animating or Defer(frame) then
        frame:SetScript("OnUpdate", nil)
        return
    end
    elapsed = ns.PlainNumber(elapsed) or 0
    if elapsed > 0.08 then
        elapsed = 0.08
    end
    local t = (frame.animElapsed or 0) + elapsed
    frame.animElapsed = t
    local slam = frame.content
    if t < 0.15 then
        local p = t / 0.15
        if slam then
            slam:SetScale(1.6 - 0.6 * p)
        end
        SetBannerAlpha(frame, p)
    elseif t < 1.5 then
        if not frame.holdSet then
            frame.holdSet = true
            if slam then
                slam:SetScale(1)
            end
            SetBannerAlpha(frame, 1)
        end
    elseif t < 2.0 then
        local p = (t - 1.5) / 0.5
        SetBannerAlpha(frame, 1 - p)
    else
        ns:FinishBanner()
    end
end

function ns:StyleBannerText()
    local banner = self.banner
    if not banner then
        return
    end
    banner.title:SetTextColor(0.9, 0.08, 0.08, 1)
    banner.title:SetShadowColor(0, 0, 0, 1)
    banner.title:SetShadowOffset(3, -3)
    banner.sub:SetTextColor(0.9, 0.85, 0.75, 1)
    banner.sub:SetShadowColor(0, 0, 0, 1)
    banner.sub:SetShadowOffset(2, -2)
end

function ns:SetBannerMouse(enabled)
    local banner = self.banner
    if not banner then
        return
    end
    SetMouse(banner, enabled)
    if banner.content then
        banner.content:EnableMouse(false)
    end
end

function ns:FinishBanner()
    local banner = self.banner
    if not banner then
        return
    end
    if banner.moving then
        banner.moving = false
        banner:StopMovingOrSizing()
    end
    banner.animating = false
    banner.animElapsed = 0
    banner.holdSet = false
    banner:SetScript("OnUpdate", nil)
    if banner.content then
        banner.content:SetScale(1)
    end
    SetBannerAlpha(banner, 0)
    self:SetBannerMouse(false)
    SetShown(banner, false)
    if XiusKillStreakDB and XiusKillStreakDB.unlocked then
        self:ShowPlacementPreview()
    end
end

function ns:ShowPlacementPreview()
    local banner = self.banner
    if not banner then
        return
    end
    banner.animating = false
    banner.animElapsed = 0
    banner.holdSet = false
    banner:SetScript("OnUpdate", nil)
    if banner.content then
        banner.content:SetScale(1)
    end
    banner.title:SetText("DOUBLE KILL")
    banner.sub:SetText("DRAG TO MOVE")
    SetBannerAlpha(banner, 1)
    self:SetBannerMouse(true)
    SetShown(banner, true)
end

function ns:CreateBanner()
    if self.banner then
        return
    end

    local banner = CreateFrame("Frame", nil, UIParent)
    banner._protected = false
    banner:SetSize(720, 120)
    banner:SetFrameStrata("HIGH")
    banner:SetFrameLevel(20)
    banner:SetClampedToScreen(true)
    banner:SetMovable(false)
    banner:EnableMouse(false)
    banner:RegisterForDrag("LeftButton")
    banner:Hide()
    banner:SetScale(1)
    banner.animating = false
    banner.animElapsed = 0
    banner.holdSet = false
    banner.moving = false

    local content = CreateFrame("Frame", nil, banner)
    content:SetSize(720, 120)
    content:SetPoint("CENTER", banner, "CENTER", 0, 0)
    content:SetScale(1)
    content:SetAlpha(1)
    banner.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    self:ApplyFontObject(title, TITLE_SIZE, self.TITLE_FONT, self.SUB_FONT)
    title:SetPoint("CENTER", content, "CENTER", 0, 18)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(false)
    title:SetAlpha(1)
    banner.title = title

    local sub = content:CreateFontString(nil, "OVERLAY")
    self:ApplyFontObject(sub, SUB_SIZE, self.SUB_FONT, self.TITLE_FONT)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetJustifyH("CENTER")
    sub:SetJustifyV("TOP")
    sub:SetWordWrap(false)
    sub:SetAlpha(1)
    banner.sub = sub

    self.banner = banner
    self:ApplyBannerScale()
    self:SetBannerMouse(false)
    SetBannerAlpha(banner, 0)

    banner:SetScript("OnDragStart", function(frame)
        if not XiusKillStreakDB or not XiusKillStreakDB.unlocked or Defer(frame) then
            return
        end
        frame.animating = false
        frame.holdSet = false
        frame:SetScript("OnUpdate", nil)
        if frame.content then
            frame.content:SetScale(1)
        end
        SetBannerAlpha(frame, 1)
        frame.moving = true
        frame:StartMoving()
    end)

    banner:SetScript("OnDragStop", function(frame)
        frame.moving = false
        frame:StopMovingOrSizing()
        ns:SaveBannerPosition()
    end)

    banner:SetScript("OnHide", function(frame)
        if frame.moving then
            frame.moving = false
            frame:StopMovingOrSizing()
        end
    end)
end

function ns:ShowBanner(titleText, subText)
    if not self.banner then
        self:CreateBanner()
    end
    local banner = self.banner
    if Defer(banner) then
        pendingTitle = titleText or ""
        pendingSub = subText or ""
        return
    end
    banner.title:SetText(titleText or "")
    banner.sub:SetText(subText or "")
    banner.animElapsed = 0
    banner.holdSet = false
    banner.animating = true
    banner:SetScale(1)
    if banner.content then
        banner.content:SetScale(1.6)
    end
    SetBannerAlpha(banner, 0)
    self:SetBannerMouse(XiusKillStreakDB and XiusKillStreakDB.unlocked and true or false)
    banner:SetScript("OnUpdate", BannerOnUpdate)
    SetShown(banner, true)
end

function ns:FlushLayout()
    if not layoutQueued or ns.InLockdown() then
        return
    end
    layoutQueued = false
    self:ApplyBannerScale()
    self:ApplyBannerPosition()
    self:ApplyCounterPosition()
    self:UpdateLock()
    local banner = self.banner
    if banner and banner.animating then
        banner:SetScript("OnUpdate", BannerOnUpdate)
    end
    if pendingTitle ~= nil then
        local title = pendingTitle
        local sub = pendingSub
        pendingTitle = nil
        pendingSub = nil
        self:ShowBanner(title, sub)
    end
end

local function PlainAnchor(value, fallback)
    if value == nil or ns.IsSecret(value) or type(value) ~= "string" or value == "" then
        return fallback
    end
    return value
end

local function RestorePoint(frame, pos, point, x, y)
    if Defer(frame) then
        return
    end
    frame:ClearAllPoints()
    if type(pos) == "table" then
        local anchor = PlainAnchor(pos.point, nil)
        local relPoint = PlainAnchor(pos.relPoint, point)
        local posX = ns.PlainNumber(pos.x)
        local posY = ns.PlainNumber(pos.y)
        if anchor and posX and posY then
            local ok = pcall(frame.SetPoint, frame, anchor, UIParent, relPoint, posX, posY)
            if ok then
                return
            end
            frame:ClearAllPoints()
        end
    end
    frame:SetPoint(point, UIParent, point, x, y)
end

local function ReadPoint(frame)
    local ok, point, _, relPoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not ok or ns.IsSecret(point) or ns.IsSecret(relPoint) or ns.IsSecret(x) or ns.IsSecret(y) then
        return nil
    end
    point = PlainAnchor(point, nil)
    if not point then
        return nil
    end
    relPoint = PlainAnchor(relPoint, point)
    x = ns.PlainNumber(x) or 0
    y = ns.PlainNumber(y) or 0
    return point, relPoint, x, y
end

function ns:GetBannerOffset()
    local pos = XiusKillStreakDB and XiusKillStreakDB.bannerPos
    if type(pos) == "table" then
        local x = ns.PlainNumber(pos.x)
        local y = ns.PlainNumber(pos.y)
        if x ~= nil and y ~= nil then
            return math_floor(x + 0.5), math_floor(y + 0.5)
        end
    end
    return 0, 160
end

function ns:SetBannerOffset(x, y)
    if type(XiusKillStreakDB) ~= "table" then
        return
    end
    local curX, curY = self:GetBannerOffset()
    local nextX = ns.PlainNumber(x)
    local nextY = ns.PlainNumber(y)
    if nextX == nil then
        nextX = curX
    end
    if nextY == nil then
        nextY = curY
    end
    local existing = XiusKillStreakDB.bannerPos
    local point = (type(existing) == "table" and PlainAnchor(existing.point, "CENTER")) or "CENTER"
    local relPoint = (type(existing) == "table" and PlainAnchor(existing.relPoint, point)) or point
    XiusKillStreakDB.bannerPos = {
        point = point,
        relPoint = relPoint,
        x = nextX,
        y = nextY,
    }
    self:ApplyBannerPosition()
end

function ns:ApplyBannerPosition()
    local banner = self.banner
    if not banner then
        return
    end
    RestorePoint(banner, XiusKillStreakDB and XiusKillStreakDB.bannerPos, "CENTER", 0, 160)
end

function ns:SaveBannerPosition()
    local banner = self.banner
    if not banner or not XiusKillStreakDB then
        return
    end
    local point, relPoint, x, y = ReadPoint(banner)
    if not point then
        return
    end
    XiusKillStreakDB.bannerPos = {
        point = point,
        relPoint = relPoint,
        x = math_floor(x + 0.5),
        y = math_floor(y + 0.5),
    }
    local Lib = _G.XiusCoreSettingsLib
    if Lib and Lib.RefreshPage and Lib.frame and Lib.frame:IsShown() and Lib.page == "KillStreak" then
        Lib:RefreshPage()
    end
end

local COUNTER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function AddInnerShadow(frame)
    local function Line(horizontal)
        local tex = frame:CreateTexture(nil, "BORDER", nil, 1)
        tex:SetColorTexture(0, 0, 0, 0.65)
        if horizontal then
            tex:SetHeight(1)
        else
            tex:SetWidth(1)
        end
        return tex
    end
    local top = Line(true)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    local bottom = Line(true)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    local left = Line(false)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    local right = Line(false)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
end

function ns:CreateCounter()
    if self.counter then
        return
    end

    local counter
    if BackdropTemplateMixin then
        local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "BackdropTemplate")
        if ok and frame then
            counter = frame
        end
    end
    if not counter then
        counter = CreateFrame("Frame", nil, UIParent)
    end
    counter._protected = false

    counter:SetSize(DEFAULT_COUNTER_W, DEFAULT_COUNTER_H)
    counter:SetFrameStrata("MEDIUM")
    counter:SetClampedToScreen(true)
    counter:SetMovable(false)
    counter:SetResizable(false)
    counter:EnableMouse(false)
    counter:RegisterForDrag("LeftButton")
    counter:Hide()
    counter.moving = false

    if counter.SetBackdrop then
        pcall(counter.SetBackdrop, counter, COUNTER_BACKDROP)
        pcall(counter.SetBackdropColor, counter, 0.06, 0.06, 0.08, 0.92)
        pcall(counter.SetBackdropBorderColor, counter, 1.0, 0.82, 0.35, 1)
        pcall(AddInnerShadow, counter)
    end

    if counter.SetResizeBounds then
        pcall(counter.SetResizeBounds, counter, MIN_COUNTER_W, MIN_COUNTER_H, MAX_COUNTER_W, MAX_COUNTER_H)
    elseif counter.SetMinResize and counter.SetMaxResize then
        pcall(counter.SetMinResize, counter, MIN_COUNTER_W, MIN_COUNTER_H)
        pcall(counter.SetMaxResize, counter, MAX_COUNTER_W, MAX_COUNTER_H)
    end

    local heading = counter:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOP", counter, "TOP", 0, -14)
    heading:SetText("Kill Streak")
    heading:SetTextColor(1, 0.82, 0, 1)
    counter.heading = heading

    local text = counter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", heading, "BOTTOM", 0, -4)
    text:SetTextColor(0.93, 0.93, 0.91, 1)
    text:SetWidth(160)
    text:SetJustifyH("CENTER")
    text:SetText("Streak: 0")
    counter.text = text

    local grip = CreateFrame("Button", nil, counter)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", counter, "BOTTOMRIGHT", -6, 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:Hide()
    counter.grip = grip

    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not XiusKillStreakDB or not XiusKillStreakDB.unlocked or Defer(counter) then
            return
        end
        ns.sizing = true
        counter:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
        if ns.sizing then
            ns.sizing = false
            counter:StopMovingOrSizing()
            ns:SaveCounterSize()
            ns:SaveCounterPosition()
        end
    end)

    counter:SetScript("OnDragStart", function(frame)
        if not XiusKillStreakDB or not XiusKillStreakDB.unlocked or Defer(frame) then
            return
        end
        frame.moving = true
        frame:StartMoving()
    end)

    counter:SetScript("OnDragStop", function(frame)
        frame.moving = false
        frame:StopMovingOrSizing()
        ns:SaveCounterPosition()
    end)

    counter:SetScript("OnHide", function(frame)
        if frame.moving or ns.sizing then
            frame.moving = false
            ns.sizing = false
            frame:StopMovingOrSizing()
        end
    end)

    counter:SetScript("OnSizeChanged", function(frame, width, height)
        if frame.OnBackdropSizeChanged then
            pcall(frame.OnBackdropSizeChanged, frame)
        end
        width = ns.PlainNumber(width)
        height = ns.PlainNumber(height)
        if not width or not height then
            return
        end
        if ns.sizing and XiusKillStreakDB then
            XiusKillStreakDB.counterWidth = width
            XiusKillStreakDB.counterHeight = height
        end
        if frame.text then
            frame.text:SetWidth(math_max(80, width - 40))
        end
    end)

    self.counter = counter
end

function ns:ApplyCounterPosition()
    local counter = self.counter
    if not counter then
        return
    end
    if Defer(counter) then
        return
    end
    local db = XiusKillStreakDB
    local width = ns.PlainNumber(db and db.counterWidth) or DEFAULT_COUNTER_W
    local height = ns.PlainNumber(db and db.counterHeight) or DEFAULT_COUNTER_H
    if width < MIN_COUNTER_W then
        width = MIN_COUNTER_W
    elseif width > MAX_COUNTER_W then
        width = MAX_COUNTER_W
    end
    if height < MIN_COUNTER_H then
        height = MIN_COUNTER_H
    elseif height > MAX_COUNTER_H then
        height = MAX_COUNTER_H
    end
    counter:SetSize(width, height)
    RestorePoint(counter, db and db.counterPos, "TOP", 0, -24)
end

function ns:SaveCounterPosition()
    local counter = self.counter
    if not counter or not XiusKillStreakDB then
        return
    end
    local point, relPoint, x, y = ReadPoint(counter)
    if not point then
        return
    end
    XiusKillStreakDB.counterPos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

function ns:SaveCounterSize()
    local counter = self.counter
    if not counter or not XiusKillStreakDB then
        return
    end
    local okW, rawW = pcall(counter.GetWidth, counter)
    local okH, rawH = pcall(counter.GetHeight, counter)
    local width = okW and ns.PlainNumber(rawW) or nil
    local height = okH and ns.PlainNumber(rawH) or nil
    if width then
        XiusKillStreakDB.counterWidth = width
    end
    if height then
        XiusKillStreakDB.counterHeight = height
    end
end

function ns:RegisterMovers()
    if self.moversRegistered then
        return
    end
    local core = _G.XiusCore
    if not core or type(core.RegisterMover) ~= "function" then
        return
    end
    if self.banner then
        core:RegisterMover("killstreakBanner", self.banner, "Kill Streak Banner", function(unlocked)
            if ns.SetUnlocked then
                ns:SetUnlocked(unlocked and true or false)
            end
        end)
    end
    if self.counter then
        core:RegisterMover("killstreakCounter", self.counter, "Kill Streak Counter", function(unlocked)
            if ns.SetUnlocked then
                ns:SetUnlocked(unlocked and true or false)
            end
        end)
    end
    self.moversRegistered = true
end

function ns:ResetPositions()
    if XiusKillStreakDB then
        XiusKillStreakDB.bannerPos = nil
        XiusKillStreakDB.counterPos = nil
        XiusKillStreakDB.counterWidth = nil
        XiusKillStreakDB.counterHeight = nil
    end
    self:ApplyBannerPosition()
    self:ApplyCounterPosition()
    local Lib = _G.XiusCoreSettingsLib
    if Lib and Lib.RefreshPage and Lib.frame and Lib.frame:IsShown() and Lib.page == "KillStreak" then
        Lib:RefreshPage()
    end
end

function ns:UpdateLock()
    local unlocked = XiusKillStreakDB and XiusKillStreakDB.unlocked and true or false
    local banner = self.banner
    local counter = self.counter
    if ns.InLockdown() and ((banner and banner._protected) or (counter and counter._protected)) then
        layoutQueued = true
        return
    end

    if banner then
        if not unlocked and banner.moving then
            banner.moving = false
            banner:StopMovingOrSizing()
        end
        banner:SetMovable(unlocked)
        if not banner.animating then
            if unlocked then
                self:ShowPlacementPreview()
            else
                self:FinishBanner()
            end
        else
            self:SetBannerMouse(unlocked)
        end
    end

    if counter then
        if not unlocked and (counter.moving or self.sizing) then
            counter.moving = false
            self.sizing = false
            counter:StopMovingOrSizing()
        end
        counter:SetMovable(unlocked)
        counter:SetResizable(unlocked)
        if counter.grip then
            SetMouse(counter.grip, unlocked)
            SetShown(counter.grip, unlocked)
        end
    end

    self:UpdateCounter()
end

function ns:UpdateCounter()
    local counter = self.counter
    if not counter then
        return
    end

    local db = XiusKillStreakDB
    local unlocked = db and db.unlocked and true or false
    local enabled = db and db.enabled and true or false

    if Defer(counter) then
        return
    end

    if not enabled and not unlocked then
        SetMouse(counter, false)
        SetShown(counter, false)
        counter.lastMode = nil
        counter.lastStreak = nil
        counter.lastSec = nil
        return
    end

    local now = ns.Now()
    local lastKill = ns.PlainNumber(self.lastKillAt)
    if enabled and self.streak and self.streak > 0 and lastKill and now then
        local remain = self:CurrentWindow() - (now - lastKill)
        if remain < 0 then
            remain = 0
        end
        local sec = math_floor(remain + 0.5)
        if counter.lastMode ~= 1 or counter.lastStreak ~= self.streak or counter.lastSec ~= sec then
            counter.lastMode = 1
            counter.lastStreak = self.streak
            counter.lastSec = sec
            if counter.text.SetFormattedText then
                counter.text:SetFormattedText("Streak: %d\nNext kill: %ds", self.streak, sec)
            else
                counter.text:SetText(string_format("Streak: %d\nNext kill: %ds", self.streak, sec))
            end
        end
        SetMouse(counter, unlocked)
        SetShown(counter, true)
    elseif unlocked then
        if counter.lastMode ~= 2 then
            counter.lastMode = 2
            counter.lastStreak = 0
            counter.lastSec = nil
            counter.text:SetText("Streak: 0\nDrag to move")
        end
        SetMouse(counter, true)
        SetShown(counter, true)
    else
        SetMouse(counter, false)
        SetShown(counter, false)
        counter.lastMode = nil
        counter.lastStreak = nil
        counter.lastSec = nil
    end
end
