--[[
    CrosshairsPlus v1.0
    Based on Crosshairs by Semlar (WotLK backport: Kader)
    Extended by xLT69x
    /chp  — open settings   /chp reset — restore defaults
]]

-- ============================================================
-- DIAGNOSTIC FRAME  — created FIRST so it survives if anything
-- below crashes.  Even if rest of file errors, this frame's
-- OnEvent is already registered and will fire at login.
-- ============================================================
do
    local _d = CreateFrame("Frame")
    _d:RegisterEvent("PLAYER_ENTERING_WORLD")
    _d:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if not LibStub then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444CrosshairsPlus|r ERROR: LibStub is nil — libs did not load at all")
            return
        end
        if not LibStub("LibNameplates-1.0", true) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444CrosshairsPlus|r ERROR: LibNameplates-1.0 failed to register (lib crash or missing file)")
        end
        -- If both are fine, the main frame's PLAYER_ENTERING_WORLD
        -- handler will print the "loaded!" message instead.
    end)
end

-- ============================================================
-- Lib check  — use silent=true so LibStub returns nil instead
-- of throwing a Lua error when LibNameplates isn't registered
-- ============================================================
local LibNameplates = LibStub and LibStub("LibNameplates-1.0", true)
if not LibNameplates then return end

-- ============================================================
-- Constants
-- ============================================================
local ASSET = "Interface\\AddOns\\CrosshairsPlus\\Assets\\"

-- Unified crosshair-texture list.  Each entry = { display name, texture path }.
-- First block = the original glowing circle rings; second block = crosshair
-- graphics imported from WoH-Reticle (256x256 32-bit TGA).
local STYLES = {
    { "Original",   ASSET.."circle"     },
    { "Glow",       ASSET.."CircleGlow" },
    { "Circle 2",   ASSET.."Circle2"    },
    { "Circle 3",   ASSET.."Circle3"    },
    { "Circle 4",   ASSET.."Circle4"    },
    { "Circle 5",   ASSET.."Circle5"    },
    { "Cross Default", ASSET.."CrossDefault" },
    { "Cross 1",    ASSET.."Cross1"     },
    { "Cross 2",    ASSET.."Cross2"     },
    { "Cross 3",    ASSET.."Cross3"     },
    { "Cross 4",    ASSET.."Cross4"     },
    { "Cross 5",    ASSET.."Cross5"     },
    { "Cross 6",    ASSET.."Cross6"     },
    { "Cross 7",    ASSET.."Cross7"     },
    { "Cross 8",    ASSET.."Cross8"     },
    { "Cross 9",    ASSET.."Cross9"     },
    { "Cross A",    ASSET.."CrossA"     },
    { "Cross B",    ASSET.."CrossB"     },
    { "Cross C",    ASSET.."CrossC"     },
}

local DEFAULTS = {
    alpha       = 0.75,
    lineAlpha   = 0.5,
    scale       = 1.0,
    showLines   = true,
    circleStyle = 1,
    showArrows  = true,
    rotSpeed    = 5,
    rotCW       = false,
    spin        = false,   -- continuously rotate the main crosshair texture
    spinSpeed   = 8,       -- seconds per full rotation
    spinCW      = false,   -- spin direction (false = counter-clockwise)
    glide       = false,   -- slide between targets instead of snapping
    glideSpeed  = 0.25,    -- glide duration in seconds (lower = faster)
    colorMode   = "class", -- "class" | "reaction" | "health"
}

-- ============================================================
-- Upvalues  (kept in sync with DB so fade helpers are correct)
-- ============================================================
local alpha      = 0.75
local lineAlpha  = 0.5
local showLines  = true
local showArrows = true
local spin       = false -- crosshair-texture spin enabled
local speed      = 0.1   -- fade duration in seconds

-- ============================================================
-- Localise globals  (identical to working Crosshairs)
-- ============================================================
local UIFrameFadeIn        = UIFrameFadeIn
local CreateFrame          = CreateFrame
local tonumber             = tonumber
local strmatch             = strmatch or string.match
local UnitClass            = UnitClass
local UnitIsPlayer         = UnitIsPlayer
local UnitIsTapped         = UnitIsTapped
local UnitIsTappedByPlayer = UnitIsTappedByPlayer
local UnitIsUnit           = UnitIsUnit
local UnitSelectionColor   = UnitSelectionColor
local UnitHealth           = UnitHealth
local UnitHealthMax        = UnitHealthMax
local UnitExists           = UnitExists

-- ============================================================
-- UI scale  — identical calc to working Crosshairs, but the
-- whole block is wrapped in pcall so a nil/OOB resolution index
-- (windowed mode, custom res) can never crash the addon
-- ============================================================
local uiScale = 1
do
    local ok, val = pcall(function()
        local h = select(2, strmatch(
            ({GetScreenResolutions()})[GetCurrentResolution()],
            "(%d+)x(%d+)"))
        h = tonumber(h)
        return (h and h > 0) and (768 / h) or 1
    end)
    if ok and val then uiScale = val end
end
local lineWidth = uiScale * 2

-- ============================================================
-- Frame  (identical to working Crosshairs)
-- ============================================================
local f = CreateFrame("frame", "CrosshairsPlusFrame", UIParent)
f:SetFrameLevel(0)
f:SetFrameStrata("BACKGROUND")
f:SetPoint("CENTER")
f:SetSize(64 * uiScale, 64 * uiScale)

-- Circle texture  (child of UIParent so alpha==0 hides it while
-- the frame itself can be shown/hidden for layout purposes)
local circle = UIParent:CreateTexture(nil, "ARTWORK")
circle:SetTexture(ASSET.."circle")
circle:SetAllPoints(f)
circle:SetAlpha(alpha)
circle:SetBlendMode("ADD")

-- Line textures  (children of f)
local left   = f:CreateTexture(nil, "ARTWORK")
local right  = f:CreateTexture(nil, "ARTWORK")
local top    = f:CreateTexture(nil, "ARTWORK")
local bottom = f:CreateTexture(nil, "ARTWORK")
for _, t in ipairs({left, right, top, bottom}) do
    t:SetTexture([[Interface\Buttons\WHITE8X8]])
    t:SetVertexColor(1, 1, 1, alpha)
    t:SetBlendMode("ADD")
end
left:SetPoint("RIGHT",  f, "LEFT",    8,  0);  left:SetSize(2000, lineWidth)
right:SetPoint("LEFT",  f, "RIGHT",  -8,  0);  right:SetSize(2000, lineWidth)
top:SetPoint("BOTTOM",  f, "TOP",     0, -8);  top:SetSize(lineWidth, 2000)
bottom:SetPoint("TOP",  f, "BOTTOM",  0,  8);  bottom:SetSize(lineWidth, 2000)

-- Arrow ring  (child of UIParent, same as original)
local tx = UIParent:CreateTexture(nil, "ARTWORK")
tx:SetTexture(ASSET.."arrows")
tx:SetAllPoints(f)
tx:SetBlendMode("ADD")

-- Rotation animation  (identical to working Crosshairs)
local ag       = tx:CreateAnimationGroup()
local rotation = ag:CreateAnimation("Rotation")
rotation:SetDegrees(-360)
rotation:SetDuration(5)
ag:SetLooping("REPEAT")

-- Crosshair spin  — independent rotation of the central crosshair texture
-- (ported from WoH-Reticle's continuously-rotating reticle).  Separate from
-- the arrow ring so the two can spin at different speeds / directions.
local spinAG  = circle:CreateAnimationGroup()
local spinRot = spinAG:CreateAnimation("Rotation")
spinRot:SetDegrees(-360)
spinRot:SetDuration(8)
spinAG:SetLooping("REPEAT")

-- ============================================================
-- Glide  — when switching targets, slide the crosshair from its
-- current position to the new nameplate instead of snapping.  A
-- one-shot OnUpdate transition that re-reads the destination plate
-- every frame (so it tracks a moving target), then hard-anchors to
-- the plate on arrival so normal tracking resumes.
-- ============================================================
local glideEnabled = false   -- synced from DB in ApplySettings
local glideDur     = 0.25
local g_fromX, g_fromY, g_plate, g_elapsed

local glideDriver = CreateFrame("Frame")
glideDriver:Hide()
glideDriver:SetScript("OnUpdate", function(self, dt)
    if not g_plate then self:Hide(); return end
    -- destination = the plate's current center, in absolute screen pixels
    local pcx, pcy = g_plate:GetCenter()
    if not pcx then                          -- plate vanished mid-glide
        f:ClearAllPoints(); f:SetPoint("CENTER", g_plate)
        self:Hide(); return
    end
    g_elapsed = g_elapsed + dt
    local t = g_elapsed / glideDur
    if t >= 1 then                           -- arrived: live-anchor to plate
        f:ClearAllPoints(); f:SetPoint("CENTER", g_plate)
        self:Hide(); return
    end
    local e  = t * t * (3 - 2 * t)           -- smoothstep ease in/out
    local ps = g_plate:GetEffectiveScale()
    local destX, destY = pcx * ps, pcy * ps
    local sx = g_fromX + (destX - g_fromX) * e
    local sy = g_fromY + (destY - g_fromY) * e
    local fs = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx / fs, sy / fs)
end)

-- Begin a glide from f's current position to toPlate.  Returns false
-- if f has no resolved position yet (caller then falls back to a snap).
local function StartGlide(toPlate)
    local cx, cy = f:GetCenter()
    if not cx then return false end
    local fs = f:GetEffectiveScale()
    g_fromX, g_fromY = cx * fs, cy * fs
    g_plate   = toPlate
    g_elapsed = 0
    glideDriver:Show()
    return true
end

-- ============================================================
-- Hide / Show  — HookScript registered BEFORE f:Hide() so
-- the initial hide correctly zeroes all alpha values
-- ============================================================
local function HideEverything()
    UIFrameFadeIn(circle, speed, alpha,     0)
    UIFrameFadeIn(left,   speed, lineAlpha, 0)
    UIFrameFadeIn(right,  speed, lineAlpha, 0)
    UIFrameFadeIn(top,    speed, lineAlpha, 0)
    UIFrameFadeIn(bottom, speed, lineAlpha, 0)
    UIFrameFadeIn(tx,     speed, alpha,     0)
    ag:Stop()
    spinAG:Stop()
    glideDriver:Hide()
    f.plate = nil
end

local function ShowEverything()
    UIFrameFadeIn(circle, speed, 0, alpha)
    if showLines then
        UIFrameFadeIn(left,   speed, 0, lineAlpha)
        UIFrameFadeIn(right,  speed, 0, lineAlpha)
        UIFrameFadeIn(top,    speed, 0, lineAlpha)
        UIFrameFadeIn(bottom, speed, 0, lineAlpha)
    end
    if showArrows then
        UIFrameFadeIn(tx, speed, 0, alpha)
        ag:Play()
    end
    if spin then
        spinAG:Play()
    end
end

f:HookScript("OnHide", HideEverything)
f:HookScript("OnShow", ShowEverything)
f:Hide()

-- Set initial line alpha (identical to working Crosshairs)
local function SetLineAlpha(a)
    left:SetAlpha(a); right:SetAlpha(a); top:SetAlpha(a); bottom:SetAlpha(a)
end
SetLineAlpha(lineAlpha)

-- ============================================================
-- Color helpers
-- ============================================================
local function SetColor(r, g, b)
    circle:SetVertexColor(r, g, b)
    left:SetVertexColor(r, g, b)
    right:SetVertexColor(r, g, b)
    top:SetVertexColor(r, g, b)
    bottom:SetVertexColor(r, g, b)
    tx:SetVertexColor(r, g, b)
end

-- HP gradient stops (ported from WoH-Reticle's HPlerps, converted to 0-1).
-- green @100%  ->  yellow @50%  ->  red @0%
local HP_GREEN  = { 35/255, 180/255,  75/255 }
local HP_YELLOW = { 255/255, 240/255,  0/255 }
local HP_RED    = { 240/255,  30/255, 35/255 }

-- Piecewise-linear interpolation of the health color for a 0..1 percent.
local function HealthColor(pct)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local lo, hi, t
    if pct >= 0.5 then
        lo, hi, t = HP_YELLOW, HP_GREEN, (pct - 0.5) / 0.5
    else
        lo, hi, t = HP_RED, HP_YELLOW, pct / 0.5
    end
    return lo[1] + (hi[1] - lo[1]) * t,
           lo[2] + (hi[2] - lo[2]) * t,
           lo[3] + (hi[3] - lo[3]) * t
end

-- Choose color based on colorMode setting (or class if no DB)
local function PickColor()
    local r, g, b = 1, 1, 1
    local cm = CrosshairsPlusDB and CrosshairsPlusDB.colorMode or "class"
    if cm == "health" then
        local max = UnitHealthMax("target")
        local pct = (max and max > 0) and (UnitHealth("target") / max) or 1
        return HealthColor(pct)
    elseif UnitIsTapped("target") and not UnitIsTappedByPlayer("target") then
        r, g, b = 0.5, 0.5, 0.5
    elseif cm == "class" and UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            r, g, b = c.r, c.g, c.b
        else
            r, g, b = 0.274, 0.705, 0.392
        end
    else
        r, g, b = UnitSelectionColor("target")
    end
    return r, g, b
end

local function FocusPlate(plate)
    -- Glide only when switching from one shown plate to a different one;
    -- gaining a target from nothing (or re-focusing the same plate) snaps.
    if glideEnabled and f:IsShown() and f.plate and f.plate ~= plate
       and StartGlide(plate) then
        f.plate = plate
        SetColor(PickColor())
        return
    end
    glideDriver:Hide()          -- cancel any in-flight glide
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate)
    f:Show()
    f.plate = plate
    SetColor(PickColor())
end

-- Re-tint while a target is held — used by UNIT_HEALTH events so the crosshair
-- tracks the target's HP live when colorMode == "health".
local function UpdateHealthColor()
    if not f.plate then return end
    if (CrosshairsPlusDB and CrosshairsPlusDB.colorMode) ~= "health" then return end
    if not UnitExists("target") then return end
    SetColor(PickColor())
end

-- ============================================================
-- Apply settings to live textures
-- ============================================================
local function ApplySettings()
    local DB = CrosshairsPlusDB
    if not DB then return end

    alpha      = DB.alpha     or 0.75
    lineAlpha  = DB.lineAlpha or 0.5
    showLines  = (DB.showLines  ~= false)
    showArrows = (DB.showArrows ~= false)
    spin       = (DB.spin == true)
    glideEnabled = (DB.glide == true)
    glideDur     = DB.glideSpeed or 0.25

    local s = DB.scale or 1.0
    f:SetSize(64 * uiScale * s, 64 * uiScale * s)

    local idx = DB.circleStyle or 1
    circle:SetTexture((STYLES[idx] or STYLES[1])[2])

    rotation:SetDuration(DB.rotSpeed or 5)
    rotation:SetDegrees((DB.rotCW) and 360 or -360)

    spinRot:SetDuration(DB.spinSpeed or 8)
    spinRot:SetDegrees((DB.spinCW) and 360 or -360)
    -- keep the live spin state in sync if the crosshair is currently shown
    if f:IsShown() then
        if spin then spinAG:Play() else spinAG:Stop() end
    end
end

-- ============================================================
-- Plate finder
-- Three back-ends for locating the current target's nameplate, in
-- order of reliability (decided once at PLAYER_ENTERING_WORLD):
--   • awesome_wotlk (if the client exposes C_NamePlate) — returns the
--     target's plate by GUID directly.  Exact, immune to shared names.
--   • Pretty Nameplates (if loaded) — scan WorldFrame for PNP-tagged
--     plates (frame.myPlate); the target is the fully-visible (alpha==1)
--     one, with the unit name only as a tie-breaker.
--   • LibNameplates — the default GUID-based matcher otherwise.
-- ============================================================
local hasAwesome = false
local usePNP     = false
local WorldFrame = WorldFrame
local UnitName   = UnitName

-- Find the target's plate via Pretty Nameplates' own frame tagging.
-- Alpha is the authoritative "this is the target" signal: WoW lights
-- only the target's plate to full alpha.  We therefore prefer the
-- single fully-visible plate (so shared names don't matter), use the
-- name only to break ties, and fall back to name when no fade is used.
local function GetTargetPlate_PNP()
    if not UnitExists("target") then return nil end
    local tName = UnitName("target")
    local onlyAlpha1, alpha1Count = nil, 0
    local alpha1NameMatch, alpha1NameCount = nil, 0
    local nameAny
    local kids = { WorldFrame:GetChildren() }
    for i = 1, #kids do
        local frame = kids[i]
        local mp = frame.myPlate
        if mp and frame:IsShown() then
            local a1     = (frame:GetAlpha() == 1)
            local nameOK = (mp.nameText and mp.nameText:GetText() == tName)
            if a1 then
                alpha1Count = alpha1Count + 1
                onlyAlpha1  = onlyAlpha1 or frame
                if nameOK then
                    alpha1NameCount = alpha1NameCount + 1
                    alpha1NameMatch = alpha1NameMatch or frame
                end
            elseif nameOK then
                nameAny = nameAny or frame
            end
        end
    end
    if alpha1Count == 1     then return onlyAlpha1     end  -- the fully-visible target
    if alpha1NameCount == 1 then return alpha1NameMatch end  -- several lit → name breaks the tie
    if alpha1Count > 1      then return nil            end  -- fade still settling → poll again
    return nameAny                                          -- server doesn't fade → best effort
end

-- Unified accessor used by all target handling.
local function GetTargetPlate()
    if not UnitExists("target") then return nil end
    if hasAwesome then return C_NamePlate.GetNamePlateForUnit("target") end
    if usePNP     then return GetTargetPlate_PNP() end
    return LibNameplates:GetNameplateByGUID(UnitGUID("target"))
end

-- ============================================================
-- Target acquisition
-- The plate is usually NOT ready the instant PLAYER_TARGET_CHANGED
-- fires (LibNameplates matches asynchronously; PNP plates need a
-- frame or two for the fade to settle / the plate to be hooked).
-- Hiding in that gap caused a flicker AND defeated the glide (it
-- wiped the start position).  Instead we keep the current crosshair
-- up and poll briefly for the new plate; FocusPlate then glides from
-- the old position.  If nothing turns up, we hide.
-- ============================================================
local SEARCH_TIMEOUT = 0.6
local searchElapsed
local searchFrame = CreateFrame("Frame")
searchFrame:Hide()
searchFrame:SetScript("OnUpdate", function(self, dt)
    if not UnitExists("target") then
        self:Hide(); f.plate = nil; f:Hide(); return
    end
    local np = GetTargetPlate()
    if np then
        self:Hide()
        FocusPlate(np)
        return
    end
    searchElapsed = searchElapsed + dt
    if searchElapsed >= SEARCH_TIMEOUT then
        self:Hide(); f.plate = nil; f:Hide()
    end
end)

function f:PLAYER_TARGET_CHANGED()
    searchFrame:Hide()
    if not UnitExists("target") then
        self.plate = nil
        self:Hide()
        return
    end
    local nameplate = GetTargetPlate()
    if nameplate then
        FocusPlate(nameplate)               -- plate already known → focus/glide now
    else
        searchElapsed = 0                   -- keep old crosshair up; poll for the new plate
        searchFrame:Show()
    end
end

function f:LibNameplates_FoundGUID(_, nameplate, guid, unit)
    if hasAwesome or usePNP then return end  -- those paths drive acquisition themselves
    if nameplate and UnitExists("target") and guid == UnitGUID("target") then
        searchFrame:Hide()
        FocusPlate(nameplate)
    end
end

-- awesome_wotlk pushes plates by GUID; focus the instant the target's
-- plate appears, and drop it the instant it's removed (avoids the plate
-- frame being recycled onto a different unit).
function f:NAME_PLATE_UNIT_ADDED(unit)
    if not hasAwesome then return end
    if UnitExists("target") and UnitIsUnit(unit, "target") then
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if np then searchFrame:Hide(); FocusPlate(np) end
    end
end

function f:NAME_PLATE_UNIT_REMOVED(unit)
    if not hasAwesome then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if np and self.plate == np then
        searchFrame:Hide()
        self.plate = nil
        self:Hide()
    end
end

function f:LibNameplates_RecycleNameplate(_, nameplate)
    if nameplate and self.plate == nameplate then
        self.plate = nil
        self:Hide()
    end
end

function f:ADDON_LOADED(name)
    if name ~= "CrosshairsPlus" then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- Initialise SavedVariables
    CrosshairsPlusDB = CrosshairsPlusDB or {}
    for k, v in pairs(DEFAULTS) do
        if CrosshairsPlusDB[k] == nil then
            CrosshairsPlusDB[k] = v
        end
    end

    ApplySettings()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    LibNameplates.RegisterCallback(self, "LibNameplates_FoundGUID")
    LibNameplates.RegisterCallback(self, "LibNameplates_RecycleNameplate")
end

-- Live health tracking for colorMode == "health"
function f:UNIT_HEALTH(unit)
    if unit == "target" then UpdateHealthColor() end
end
f.UNIT_HEALTH_FREQUENT = f.UNIT_HEALTH
f.UNIT_MAXHEALTH       = f.UNIT_HEALTH

function f:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- Decide the plate back-end now that every addon / the client is loaded.
    hasAwesome = (C_NamePlate and C_NamePlate.GetNamePlateForUnit) and true or false
    usePNP     = (not hasAwesome) and IsAddOnLoaded and IsAddOnLoaded("PrettyNameplates") and true or false
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_HEALTH_FREQUENT")
    self:RegisterEvent("UNIT_MAXHEALTH")
    if hasAwesome then
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    end
    self:PLAYER_TARGET_CHANGED()
    -- Silence the diagnostic frame (it already fired before this)
    local mode = hasAwesome and "  |cff00ccff(awesome_wotlk mode)|r"
              or usePNP     and "  |cff00ccff(Pretty Nameplates mode)|r" or ""
    DEFAULT_CHAT_FRAME:AddMessage("|cff22ff44CrosshairsPlus|r loaded!  Type |cffffff00/chp|r to open settings." .. mode)
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)
end)

-- ============================================================
-- Settings panel  (built lazily on first /chp call)
-- Futuristic dark-HUD style
-- ============================================================
local cfgPanel

local function BuildPanel()
    -- ── outer frame ──────────────────────────────────────────
    cfgPanel = CreateFrame("Frame", "CrosshairsPlusCfg", UIParent)
    cfgPanel:SetSize(330, 740)
    cfgPanel:SetPoint("CENTER")
    cfgPanel:SetMovable(true)
    cfgPanel:EnableMouse(true)
    cfgPanel:RegisterForDrag("LeftButton")
    cfgPanel:SetScript("OnDragStart", cfgPanel.StartMoving)
    cfgPanel:SetScript("OnDragStop",  cfgPanel.StopMovingOrSizing)
    cfgPanel:SetFrameStrata("HIGH")

    -- Dark background with 1-px sharp cyan border
    cfgPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 4, edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    cfgPanel:SetBackdropColor(0.04, 0.07, 0.14, 0.97)
    cfgPanel:SetBackdropBorderColor(0, 0.78, 1, 1)

    -- Inner accent line below header
    local headerLine = cfgPanel:CreateTexture(nil, "ARTWORK")
    headerLine:SetTexture([[Interface\Buttons\WHITE8X8]])
    headerLine:SetVertexColor(0, 0.78, 1, 0.6)
    headerLine:SetSize(310, 1)
    headerLine:SetPoint("TOPLEFT", 10, -52)

    -- Corner accents (top-left, top-right, bottom-left, bottom-right)
    local function Corner(px, py, w, h)
        local c = cfgPanel:CreateTexture(nil, "OVERLAY")
        c:SetTexture([[Interface\Buttons\WHITE8X8]])
        c:SetVertexColor(0, 0.9, 1, 1)
        c:SetSize(w, h)
        c:SetPoint("TOPLEFT", px, py)
    end
    Corner(0,   0,   10, 2);  Corner(0,   0,   2, 10)   -- top-left  (horiz, vert)
    Corner(320, 0,   10, 2);  Corner(328, 0,   2, 10)   -- top-right
    Corner(0,  -738, 10, 2);  Corner(0,  -728, 2, 10)   -- bottom-left
    Corner(320,-738, 10, 2);  Corner(328,-728, 2, 10)   -- bottom-right

    -- ── title area ────────────────────────────────────────────
    local ttl = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ttl:SetPoint("TOPLEFT", 14, -14)
    ttl:SetText("|cff00ccffCROSSHAIRS|cff0077ffPLUS|r")

    local ver = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("BOTTOMLEFT", ttl, "BOTTOMRIGHT", 6, 1)
    ver:SetText("|cff336688v1.0|r")

    local made = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    made:SetPoint("TOPLEFT", ttl, "BOTTOMLEFT", 0, -2)
    made:SetText("|cff005577Made by |r|cffffd700xLT69x|r")

    local closeBtn = CreateFrame("Button", nil, cfgPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -1, -1)
    closeBtn:SetScript("OnClick", function() cfgPanel:Hide() end)

    -- ── helpers ───────────────────────────────────────────────
    -- Section header: cyan label + full-width dim divider below
    local function SHdr(txt, y)
        -- label
        local l = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        l:SetPoint("TOPLEFT", 14, y)
        l:SetText("|cff00ccff\xE2\x96\xba|r |cff00aaffUPPER" )  -- placeholder; overwritten below
        l:SetText("|cff00ccff\xE2\x96\xba|r |cff00aaff"..txt.."|r")
        -- thin divider line under label
        local div = cfgPanel:CreateTexture(nil, "ARTWORK")
        div:SetTexture([[Interface\Buttons\WHITE8X8]])
        div:SetVertexColor(0, 0.6, 0.9, 0.25)
        div:SetSize(302, 1)
        div:SetPoint("TOPLEFT", 14, y - 16)
    end

    -- Value display (right-aligned current value)
    local function ValLbl(y)
        local l = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPRIGHT", -14, y)
        l:SetTextColor(0, 0.9, 1)
        return l
    end

    -- Slider factory
    local sliderCount = 0
    local function MakeSlider(name, y, lo, hi, step)
        sliderCount = sliderCount + 1
        local n = "CHPSl"..sliderCount
        local sl = CreateFrame("Slider", n, cfgPanel, "OptionsSliderTemplate")
        sl:SetPoint("TOPLEFT", 14, y)
        sl:SetWidth(302)
        sl:SetMinMaxValues(lo, hi)
        sl:SetValueStep(step)
        _G[n.."Low"]:SetText(tostring(lo))
        _G[n.."High"]:SetText(tostring(hi))
        _G[n.."Text"]:SetText("")
        return sl
    end

    -- ── CROSSHAIR STYLE  (y = -58) ────────────────────────────
    SHdr("Crosshair Style", -58)
    local circLbl = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    circLbl:SetPoint("TOPLEFT", 72, -80)
    circLbl:SetWidth(180)
    circLbl:SetJustifyH("LEFT")
    circLbl:SetTextColor(1, 1, 1)

    local circPrev = CreateFrame("Button", nil, cfgPanel, "UIPanelButtonTemplate")
    circPrev:SetSize(26, 20); circPrev:SetText("<")
    circPrev:SetPoint("TOPLEFT", 14, -78)
    local circNext = CreateFrame("Button", nil, cfgPanel, "UIPanelButtonTemplate")
    circNext:SetSize(26, 20); circNext:SetText(">")
    circNext:SetPoint("LEFT", circPrev, "RIGHT", 4, 0)

    local function CircRefresh()
        local DB = CrosshairsPlusDB
        circLbl:SetText((DB and STYLES[DB.circleStyle] and STYLES[DB.circleStyle][1]) or "?")
    end
    circPrev:SetScript("OnClick", function()
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.circleStyle = DB.circleStyle - 1
        if DB.circleStyle < 1 then DB.circleStyle = #STYLES end
        circle:SetTexture((STYLES[DB.circleStyle] or STYLES[1])[2])
        CircRefresh()
    end)
    circNext:SetScript("OnClick", function()
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.circleStyle = DB.circleStyle + 1
        if DB.circleStyle > #STYLES then DB.circleStyle = 1 end
        circle:SetTexture((STYLES[DB.circleStyle] or STYLES[1])[2])
        CircRefresh()
    end)

    -- ── SCALE  (y = -110) ─────────────────────────────────────
    SHdr("Scale", -110)
    local scaleVal = ValLbl(-110)
    local scaleSl  = MakeSlider("scale", -128, 0.5, 3.0, 0.05)
    _G["CHPSl"..sliderCount.."Low"]:SetText("0.5")
    scaleSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        scaleVal:SetText(string.format("%.2f", v))
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.scale = v; f:SetSize(64 * uiScale * v, 64 * uiScale * v)
    end)

    -- ── OPACITY  (y = -172) ───────────────────────────────────
    SHdr("Opacity", -172)
    local alphaVal = ValLbl(-172)
    local alphaSl  = MakeSlider("alpha", -190, 0.05, 1.0, 0.05)
    _G["CHPSl"..sliderCount.."Low"]:SetText("0")
    alphaSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        alphaVal:SetText(string.format("%.2f", v))
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.alpha = v; alpha = v
    end)

    -- ── LINES  (y = -236) ─────────────────────────────────────
    SHdr("Lines", -236)
    local linesCB = CreateFrame("CheckButton", "CHPLinesCB", cfgPanel, "UICheckButtonTemplate")
    linesCB:SetPoint("TOPLEFT", 14, -256)
    _G["CHPLinesCBText"]:SetText("|cffccccccShow lines|r")
    linesCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.showLines = v; showLines = v
    end)

    SHdr("Line Opacity", -286)
    local lineAlphaVal = ValLbl(-286)
    local lineAlphaSl  = MakeSlider("linealpha", -304, 0.0, 1.0, 0.05)
    _G["CHPSl"..sliderCount.."Low"]:SetText("0")
    lineAlphaSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        lineAlphaVal:SetText(string.format("%.2f", v))
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.lineAlpha = v; lineAlpha = v; SetLineAlpha(v)
    end)

    -- ── ARROWS  (y = -350) ────────────────────────────────────
    SHdr("Arrows", -350)
    local arrowsCB = CreateFrame("CheckButton", "CHPArrowsCB", cfgPanel, "UICheckButtonTemplate")
    arrowsCB:SetPoint("TOPLEFT", 14, -370)
    _G["CHPArrowsCBText"]:SetText("|cffccccccShow arrows|r")
    arrowsCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.showArrows = v; showArrows = v
        if v then if f:IsShown() then ag:Play() end else ag:Stop() end
    end)

    local rotCWCB = CreateFrame("CheckButton", "CHPRotCWCB", cfgPanel, "UICheckButtonTemplate")
    rotCWCB:SetPoint("LEFT", arrowsCB, "RIGHT", 60, 0)
    _G["CHPRotCWCBText"]:SetText("|cffccccccClockwise|r")
    rotCWCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.rotCW = v
        ag:Stop(); rotation:SetDegrees(v and 360 or -360)
        if showArrows and f:IsShown() then ag:Play() end
    end)

    SHdr("Rotation Speed  (sec/turn)", -400)
    local rotSpeedVal = ValLbl(-400)
    local rotSpeedSl  = MakeSlider("rotspeed", -418, 1, 30, 1)
    rotSpeedSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        rotSpeedVal:SetText(v.."s")
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.rotSpeed = v
        ag:Stop(); rotation:SetDuration(v)
        if showArrows and f:IsShown() then ag:Play() end
    end)

    -- ── SPIN CROSSHAIR  (y = -462) ────────────────────────────
    SHdr("Spin Crosshair", -462)
    local spinCB = CreateFrame("CheckButton", "CHPSpinCB", cfgPanel, "UICheckButtonTemplate")
    spinCB:SetPoint("TOPLEFT", 14, -482)
    _G["CHPSpinCBText"]:SetText("|cffccccccSpin crosshair|r")
    spinCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.spin = v; spin = v
        if v then if f:IsShown() then spinAG:Play() end else spinAG:Stop() end
    end)

    local spinCWCB = CreateFrame("CheckButton", "CHPSpinCWCB", cfgPanel, "UICheckButtonTemplate")
    spinCWCB:SetPoint("LEFT", spinCB, "RIGHT", 60, 0)
    _G["CHPSpinCWCBText"]:SetText("|cffccccccClockwise|r")
    spinCWCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.spinCW = v
        spinAG:Stop(); spinRot:SetDegrees(v and 360 or -360)
        if spin and f:IsShown() then spinAG:Play() end
    end)

    SHdr("Spin Speed  (sec/turn)", -512)
    local spinSpeedVal = ValLbl(-512)
    local spinSpeedSl  = MakeSlider("spinspeed", -530, 1, 30, 1)
    spinSpeedSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        spinSpeedVal:SetText(v.."s")
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.spinSpeed = v
        spinAG:Stop(); spinRot:SetDuration(v)
        if spin and f:IsShown() then spinAG:Play() end
    end)

    -- ── GLIDE  (y = -562) ─────────────────────────────────────
    SHdr("Glide", -562)
    local glideCB = CreateFrame("CheckButton", "CHPGlideCB", cfgPanel, "UICheckButtonTemplate")
    glideCB:SetPoint("TOPLEFT", 14, -582)
    _G["CHPGlideCBText"]:SetText("|cffccccccSlide between targets|r")
    glideCB:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.glide = v; glideEnabled = v
    end)

    SHdr("Glide Speed  (sec)", -612)
    local glideSpeedVal = ValLbl(-612)
    local glideSpeedSl  = MakeSlider("glidespeed", -630, 0.1, 1.0, 0.05)
    _G["CHPSl"..sliderCount.."Low"]:SetText("0.1")
    glideSpeedSl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        glideSpeedVal:SetText(string.format("%.2f", v).."s")
        local DB = CrosshairsPlusDB; if not DB then return end
        DB.glideSpeed = v; glideDur = v
    end)

    -- ── COLOR MODE  (y = -662) ────────────────────────────────
    SHdr("Color Mode", -662)
    local colorLbl = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLbl:SetPoint("TOPLEFT", 72, -684)
    colorLbl:SetWidth(190)
    colorLbl:SetJustifyH("LEFT")
    colorLbl:SetTextColor(1, 1, 1)

    local colorPrev = CreateFrame("Button", nil, cfgPanel, "UIPanelButtonTemplate")
    colorPrev:SetSize(26, 20); colorPrev:SetText("<")
    colorPrev:SetPoint("TOPLEFT", 14, -682)
    local colorNext = CreateFrame("Button", nil, cfgPanel, "UIPanelButtonTemplate")
    colorNext:SetSize(26, 20); colorNext:SetText(">")
    colorNext:SetPoint("LEFT", colorPrev, "RIGHT", 4, 0)

    -- Cycle order: class -> reaction -> health -> (class)
    local COLOR_ORDER = { "class", "reaction", "health" }
    local COLOR_LABEL = { class = "Class Color", reaction = "Reaction Color", health = "Health Color" }
    local function ColorRefresh()
        local DB = CrosshairsPlusDB
        local m = DB and DB.colorMode or "class"
        colorLbl:SetText(COLOR_LABEL[m] or "Class Color")
    end
    local function CycleColor(dir)
        local DB = CrosshairsPlusDB; if not DB then return end
        local cur = 1
        for i, m in ipairs(COLOR_ORDER) do if m == DB.colorMode then cur = i break end end
        cur = cur + dir
        if cur < 1 then cur = #COLOR_ORDER elseif cur > #COLOR_ORDER then cur = 1 end
        DB.colorMode = COLOR_ORDER[cur]
        ColorRefresh()
        if f.plate then SetColor(PickColor()) end   -- live preview on current target
    end
    colorPrev:SetScript("OnClick", function() CycleColor(-1) end)
    colorNext:SetScript("OnClick", function() CycleColor( 1) end)

    -- ── bottom bar ────────────────────────────────────────────
    local barLine = cfgPanel:CreateTexture(nil, "ARTWORK")
    barLine:SetTexture([[Interface\Buttons\WHITE8X8]])
    barLine:SetVertexColor(0, 0.78, 1, 0.4)
    barLine:SetSize(310, 1)
    barLine:SetPoint("BOTTOMLEFT", 10, 34)

    local resetBtn = CreateFrame("Button", nil, cfgPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(116, 22)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetPoint("BOTTOMLEFT", 14, 9)
    resetBtn:SetScript("OnClick", function()
        local DB = CrosshairsPlusDB; if not DB then return end
        for k, v in pairs(DEFAULTS) do DB[k] = v end
        ApplySettings()
        scaleSl:SetValue(DB.scale); alphaSl:SetValue(DB.alpha)
        lineAlphaSl:SetValue(DB.lineAlpha); rotSpeedSl:SetValue(DB.rotSpeed)
        spinSpeedSl:SetValue(DB.spinSpeed); glideSpeedSl:SetValue(DB.glideSpeed)
        linesCB:SetChecked(DB.showLines and 1 or 0)
        arrowsCB:SetChecked(DB.showArrows and 1 or 0)
        rotCWCB:SetChecked(DB.rotCW and 1 or 0)
        spinCB:SetChecked(DB.spin and 1 or 0)
        spinCWCB:SetChecked(DB.spinCW and 1 or 0)
        glideCB:SetChecked(DB.glide and 1 or 0)
        CircRefresh(); ColorRefresh()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffCrosshairsPlus|r: Settings reset to defaults.")
    end)

    local cred = cfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cred:SetPoint("BOTTOMRIGHT", -14, 12)
    cred:SetText("|cff003355Made by |r|cff00aaff\xE2\x97\x86 |r|cffffd700xLT69x|r")

    -- ── populate controls from current DB ─────────────────────
    function cfgPanel:Refresh()
        local DB = CrosshairsPlusDB; if not DB then return end
        CircRefresh(); ColorRefresh()
        scaleSl:SetValue(DB.scale);         scaleVal:SetText(string.format("%.2f", DB.scale))
        alphaSl:SetValue(DB.alpha);         alphaVal:SetText(string.format("%.2f", DB.alpha))
        lineAlphaSl:SetValue(DB.lineAlpha); lineAlphaVal:SetText(string.format("%.2f", DB.lineAlpha))
        rotSpeedSl:SetValue(DB.rotSpeed);   rotSpeedVal:SetText(DB.rotSpeed.."s")
        spinSpeedSl:SetValue(DB.spinSpeed); spinSpeedVal:SetText(DB.spinSpeed.."s")
        glideSpeedSl:SetValue(DB.glideSpeed); glideSpeedVal:SetText(string.format("%.2f", DB.glideSpeed).."s")
        linesCB:SetChecked(DB.showLines   and 1 or 0)
        arrowsCB:SetChecked(DB.showArrows and 1 or 0)
        rotCWCB:SetChecked(DB.rotCW       and 1 or 0)
        spinCB:SetChecked(DB.spin         and 1 or 0)
        spinCWCB:SetChecked(DB.spinCW     and 1 or 0)
        glideCB:SetChecked(DB.glide       and 1 or 0)
    end

    -- Start hidden so the first /chp correctly shows the panel
    cfgPanel:Hide()
end

-- ============================================================
-- Slash command
-- ============================================================
SLASH_CROSSHAIRSPLUS1 = "/crosshairsplus"
SLASH_CROSSHAIRSPLUS2 = "/chp"
SlashCmdList["CROSSHAIRSPLUS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""
    if msg == "" or msg == "config" or msg == "settings" then
        if not cfgPanel then BuildPanel() end
        if cfgPanel:IsShown() then cfgPanel:Hide()
        else cfgPanel:Refresh(); cfgPanel:Show() end
    elseif msg == "reset" then
        local DB = CrosshairsPlusDB
        if DB then
            for k, v in pairs(DEFAULTS) do DB[k] = v end
            ApplySettings()
            DEFAULT_CHAT_FRAME:AddMessage("|cff22ff44CrosshairsPlus|r: Settings reset to defaults.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff22ff44CrosshairsPlus|r v1.0  -  by xLT69x")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/chp|r          open/close settings")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/chp reset|r    restore defaults")
    end
end
