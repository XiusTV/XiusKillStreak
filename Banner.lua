--[[
    Bloody streak banner and the small default-styled streak counter.
    The banner is the only place the custom fonts are used.
]]

XiusKillStreak = XiusKillStreak or {}

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
local GetTime = GetTime
local CreateFrame = CreateFrame
local CreateFont = CreateFont

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

function XiusKillStreak:ApplyFontObject(fontObject, size, primaryPath, secondaryPath)
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
    if not frame.animating then
        frame:SetScript("OnUpdate", nil)
        return
    end
    if elapsed > 0.08 then
        elapsed = 0.08
    elseif elapsed < 0 then
        elapsed = 0
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
        XiusKillStreak:FinishBanner()
    end
end

function XiusKillStreak:StyleBannerText()
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

function XiusKillStreak:SetBannerMouse(enabled)
    local banner = self.banner
    if not banner then
        return
    end
    banner:EnableMouse(enabled and true or false)
    if banner.content then
        banner.content:EnableMouse(false)
    end
end

function XiusKillStreak:FinishBanner()
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
    banner:Hide()
    if XiusKillStreakDB and XiusKillStreakDB.unlocked then
        self:ShowPlacementPreview()
    end
end

function XiusKillStreak:ShowPlacementPreview()
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
    banner:Show()
end

function XiusKillStreak:CreateBanner()
    if self.banner then
        return
    end

    local banner = CreateFrame("Frame", "XiusKillStreak_BannerFrame", UIParent)
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

    local titleFont = _G.XiusKillStreakTitleFont
    if not titleFont then
        titleFont = CreateFont("XiusKillStreakTitleFont")
    end
    local subFont = _G.XiusKillStreakSubFont
    if not subFont then
        subFont = CreateFont("XiusKillStreakSubFont")
    end

    self:ApplyFontObject(titleFont, TITLE_SIZE, self.TITLE_FONT, self.SUB_FONT)
    self:ApplyFontObject(subFont, SUB_SIZE, self.SUB_FONT, self.TITLE_FONT)

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(titleFont)
    self:ApplyFontObject(title, TITLE_SIZE, self.TITLE_FONT, self.SUB_FONT)
    title:SetPoint("CENTER", content, "CENTER", 0, 18)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(false)
    title:SetAlpha(1)
    banner.title = title

    local sub = content:CreateFontString(nil, "OVERLAY")
    sub:SetFontObject(subFont)
    self:ApplyFontObject(sub, SUB_SIZE, self.SUB_FONT, self.TITLE_FONT)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetJustifyH("CENTER")
    sub:SetJustifyV("TOP")
    sub:SetWordWrap(false)
    sub:SetAlpha(1)
    banner.sub = sub

    self.banner = banner
    self:StyleBannerText()
    self:SetBannerMouse(false)
    SetBannerAlpha(banner, 0)

    banner:SetScript("OnDragStart", function(frame)
        if not XiusKillStreakDB or not XiusKillStreakDB.unlocked then
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
        XiusKillStreak:SaveBannerPosition()
    end)

    banner:SetScript("OnHide", function(frame)
        if frame.moving then
            frame.moving = false
            frame:StopMovingOrSizing()
        end
    end)
end

function XiusKillStreak:ShowBanner(titleText, subText)
    if not self.banner then
        self:CreateBanner()
    end
    local banner = self.banner
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
    banner:Show()
end

local function RestorePoint(frame, pos, point, x, y)
    frame:ClearAllPoints()
    if type(pos) == "table" and type(pos.point) == "string" and (pos.x == nil or type(pos.x) == "number") and (pos.y == nil or type(pos.y) == "number") then
        local relPoint = type(pos.relPoint) == "string" and pos.relPoint or point
        local ok = pcall(frame.SetPoint, frame, pos.point, UIParent, relPoint, pos.x or 0, pos.y or 0)
        if ok then
            return
        end
        frame:ClearAllPoints()
    end
    frame:SetPoint(point, UIParent, point, x, y)
end

function XiusKillStreak:ApplyBannerPosition()
    local banner = self.banner
    if not banner then
        return
    end
    RestorePoint(banner, XiusKillStreakDB and XiusKillStreakDB.bannerPos, "CENTER", 0, 160)
end

function XiusKillStreak:SaveBannerPosition()
    local banner = self.banner
    if not banner or not XiusKillStreakDB then
        return
    end
    local point, _, relPoint, x, y = banner:GetPoint(1)
    if not point then
        return
    end
    XiusKillStreakDB.bannerPos = {
        point = point,
        relPoint = relPoint or point,
        x = x or 0,
        y = y or 0,
    }
end

local COUNTER_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function XiusKillStreak:CreateCounter()
    if self.counter then
        return
    end

    local counter
    if BackdropTemplateMixin then
        local ok, frame = pcall(CreateFrame, "Frame", "XiusKillStreak_CounterFrame", UIParent, "BackdropTemplate")
        if ok and frame then
            counter = frame
        end
    end
    if not counter then
        counter = CreateFrame("Frame", "XiusKillStreak_CounterFrame", UIParent)
    end

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
    end

    if counter.SetResizeBounds then
        pcall(counter.SetResizeBounds, counter, MIN_COUNTER_W, MIN_COUNTER_H, MAX_COUNTER_W, MAX_COUNTER_H)
    elseif counter.SetMinResize and counter.SetMaxResize then
        pcall(counter.SetMinResize, counter, MIN_COUNTER_W, MIN_COUNTER_H)
        pcall(counter.SetMaxResize, counter, MAX_COUNTER_W, MAX_COUNTER_H)
    end

    local heading = counter:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOP", counter, "TOP", 0, -16)
    heading:SetText("Kill Streak")
    counter.heading = heading

    local text = counter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", heading, "BOTTOM", 0, -4)
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
        if button ~= "LeftButton" or not XiusKillStreakDB or not XiusKillStreakDB.unlocked then
            return
        end
        XiusKillStreak.sizing = true
        counter:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
        if XiusKillStreak.sizing then
            XiusKillStreak.sizing = false
            counter:StopMovingOrSizing()
            XiusKillStreak:SaveCounterSize()
            XiusKillStreak:SaveCounterPosition()
        end
    end)

    counter:SetScript("OnDragStart", function(frame)
        if not XiusKillStreakDB or not XiusKillStreakDB.unlocked then
            return
        end
        frame.moving = true
        frame:StartMoving()
    end)

    counter:SetScript("OnDragStop", function(frame)
        frame.moving = false
        frame:StopMovingOrSizing()
        XiusKillStreak:SaveCounterPosition()
    end)

    counter:SetScript("OnHide", function(frame)
        if frame.moving or XiusKillStreak.sizing then
            frame.moving = false
            XiusKillStreak.sizing = false
            frame:StopMovingOrSizing()
        end
    end)

    counter:SetScript("OnSizeChanged", function(frame, width, height)
        if frame.OnBackdropSizeChanged then
            pcall(frame.OnBackdropSizeChanged, frame)
        end
        if type(width) ~= "number" or type(height) ~= "number" then
            return
        end
        if XiusKillStreak.sizing and XiusKillStreakDB then
            XiusKillStreakDB.counterWidth = width
            XiusKillStreakDB.counterHeight = height
        end
        if frame.text then
            frame.text:SetWidth(math_max(80, width - 40))
        end
    end)

    self.counter = counter
end

function XiusKillStreak:ApplyCounterPosition()
    local counter = self.counter
    if not counter then
        return
    end
    local db = XiusKillStreakDB
    local width = DEFAULT_COUNTER_W
    local height = DEFAULT_COUNTER_H
    if db and type(db.counterWidth) == "number" and type(db.counterHeight) == "number" then
        width = db.counterWidth
        height = db.counterHeight
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
    end
    counter:SetSize(width, height)
    RestorePoint(counter, db and db.counterPos, "TOP", 0, -24)
end

function XiusKillStreak:SaveCounterPosition()
    local counter = self.counter
    if not counter or not XiusKillStreakDB then
        return
    end
    local point, _, relPoint, x, y = counter:GetPoint(1)
    if not point then
        return
    end
    XiusKillStreakDB.counterPos = {
        point = point,
        relPoint = relPoint or point,
        x = x or 0,
        y = y or 0,
    }
end

function XiusKillStreak:SaveCounterSize()
    local counter = self.counter
    if not counter or not XiusKillStreakDB then
        return
    end
    XiusKillStreakDB.counterWidth = counter:GetWidth()
    XiusKillStreakDB.counterHeight = counter:GetHeight()
end

function XiusKillStreak:ResetPositions()
    if XiusKillStreakDB then
        XiusKillStreakDB.bannerPos = nil
        XiusKillStreakDB.counterPos = nil
        XiusKillStreakDB.counterWidth = nil
        XiusKillStreakDB.counterHeight = nil
    end
    self:ApplyBannerPosition()
    self:ApplyCounterPosition()
end

function XiusKillStreak:UpdateLock()
    local unlocked = XiusKillStreakDB and XiusKillStreakDB.unlocked and true or false
    local banner = self.banner
    local counter = self.counter

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
            counter.grip:EnableMouse(unlocked)
            if unlocked then
                counter.grip:Show()
            else
                counter.grip:Hide()
            end
        end
    end

    self:UpdateCounter()
end

function XiusKillStreak:UpdateCounter()
    local counter = self.counter
    if not counter then
        return
    end

    local db = XiusKillStreakDB
    local unlocked = db and db.unlocked and true or false
    local enabled = db and db.enabled and true or false

    if not enabled and not unlocked then
        counter:EnableMouse(false)
        counter:Hide()
        counter.lastMode = nil
        counter.line = nil
        return
    end

    if self.streak and self.streak > 0 and self.lastKillAt then
        local remain = self:CurrentWindow() - (GetTime() - self.lastKillAt)
        if remain < 0 then
            remain = 0
        end
        local sec = math_floor(remain + 0.5)
        if counter.lastMode ~= 1 or counter.lastStreak ~= self.streak or counter.lastSec ~= sec then
            local line = string_format("Streak: %d\nNext kill: %ds", self.streak, sec)
            counter.lastMode = 1
            counter.lastStreak = self.streak
            counter.lastSec = sec
            counter.line = line
            counter.text:SetText(line)
        end
        counter:EnableMouse(unlocked)
        counter:Show()
    elseif unlocked then
        if counter.lastMode ~= 2 then
            local line = "Streak: 0\nDrag to move"
            counter.lastMode = 2
            counter.lastStreak = 0
            counter.lastSec = nil
            counter.line = line
            counter.text:SetText(line)
        end
        counter:EnableMouse(true)
        counter:Show()
    else
        counter:EnableMouse(false)
        counter:Hide()
        counter.lastMode = nil
        counter.lastStreak = nil
        counter.lastSec = nil
        counter.line = nil
    end
end
