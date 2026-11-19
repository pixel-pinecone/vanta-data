-- Vanta hub v0.6.10 — universal. Piano and its catalog are free; ESP and Fly are paid.
-- Game packs load by PlaceId from the public vanta-data repo, so a new game is a new file.
-- The main chunk stays well under Luau's 200-local ceiling: one-off UI is built
-- inside do-blocks, and all polish lives in functions.
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local Tween           = game:GetService("TweenService")
local HS              = game:GetService("HttpService")
local TextService     = game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting        = game:GetService("Lighting")
local LP              = Players.LocalPlayer
local Teleport        = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local Stats           = game:GetService("Stats")

-- every TextBox registers here so hotkeys can tell typing from playing
local textBoxes = {}
local function typing()
    for _, box in ipairs(textBoxes) do
        if box:IsFocused() then return true end
    end
    return false
end

local Config = {
    Name = "Vanta", Version = "0.6.10",
    ToggleKey = Enum.KeyCode.RightControl,
    Accent = Color3.fromRGB(126, 92, 255),
    Modules = {}, Order = {},
}

local T = {
    bg = Color3.fromRGB(12, 12, 15), bar = Color3.fromRGB(17, 17, 21),
    hover = Color3.fromRGB(24, 24, 30),
    text = Color3.fromRGB(240, 240, 246), dim = Color3.fromRGB(152, 152, 165),
    label = Color3.fromRGB(110, 110, 124), grid = Color3.fromRGB(255, 255, 255),
    line = Color3.fromRGB(32, 32, 40), lineStrong = Color3.fromRGB(48, 48, 60),
    chip = Color3.fromRGB(28, 28, 35), amber = Color3.fromRGB(255, 184, 64),
    green = Color3.fromRGB(61, 220, 132),
    badgeLine = Color3.fromRGB(62, 62, 78), badgeText = Color3.fromRGB(170, 170, 184),
}

local ALPHA = { panel = 0, sidebar = 0.1, card = 0.06, header = 0.02, grid = 0.975, veil = 0.3 }

local LIFT = 1

local LOGO_ASSET = nil

local WHITE       = Color3.new(1, 1, 1)
local accentEdge  = Config.Accent:Lerp(T.bg, 0.62)
local accentMuted = Config.Accent:Lerp(T.dim, 0.35)
local accentDeep  = Config.Accent:Lerp(T.bg, 0.45)
local accentHot   = Config.Accent:Lerp(WHITE, 0.3)

local MONO      = Font.new("rbxasset://fonts/families/RobotoMono.json")
local SANS      = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local SANS_SEMI = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)

local Style, Dir = Enum.EasingStyle, Enum.EasingDirection

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function tween(o, time, props, style, dir, repeats, reverses)
    local t = Tween:Create(o, TweenInfo.new(time, style or Style.Quad,
        dir or Dir.Out, repeats or 0, reverses or false), props)
    t:Play()
    return t
end

local function ns(...)
    local a, kp = { ... }, {}
    for i = 1, #a, 2 do kp[#kp + 1] = NumberSequenceKeypoint.new(a[i], a[i + 1]) end
    return NumberSequence.new(kp)
end

local function gradient(parent, color, transp, rot)
    return New("UIGradient", {
        Color = typeof(color) == "Color3" and ColorSequence.new(color) or color,
        Transparency = transp or NumberSequence.new(0), Rotation = rot or 0 }, parent)
end

local function band(a, b)
    return ColorSequence.new({ ColorSequenceKeypoint.new(0, a),
        ColorSequenceKeypoint.new(0.5, b), ColorSequenceKeypoint.new(1, a) })
end

local px = UDim2.fromOffset
local LEFT, RIGHT, CENTER = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center

local function corner(o, r) return New("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function outline(o, color, transp)
    return New("UIStroke", { Color = color, Thickness = 1, Transparency = transp or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function rect(parent, x, y, w, h, color, transp)
    return New("Frame", { Position = px(x, y), Size = px(w, h), BackgroundColor3 = color,
        BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
local function label(parent, text, x, cy, w, size, color, font, xa)
    local h = size + 8
    return New("TextLabel", { Position = px(x, math.floor(cy - h / 2 + 0.5) - LIFT), Size = px(w, h),
        BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
        FontFace = font or SANS, TextXAlignment = xa or LEFT,
        TextTruncate = Enum.TextTruncate.AtEnd }, parent)
end

local function ripple(btn, color)
    btn.ClipsDescendants = true
    btn.MouseButton1Down:Connect(function()
        local k = btn.AbsoluteSize.X / math.max(btn.Size.X.Offset, 1)
        local m = UIS:GetMouseLocation()
        local d = math.max(btn.Size.X.Offset, btn.Size.Y.Offset) * 2.2
        local disc = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
            Position = px((m.X - btn.AbsolutePosition.X) / k, (m.Y - btn.AbsolutePosition.Y) / k),
            Size = px(0, 0), BackgroundColor3 = color or WHITE, BackgroundTransparency = 0.8,
            BorderSizePixel = 0, ZIndex = 0 }, btn)
        New("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
        tween(disc, 0.5, { Size = px(d, d), BackgroundTransparency = 1 })
        task.delay(0.55, function() disc:Destroy() end)
    end)
end

local function outlineButton(parent, text, x, y, w, h, size, textColor, strokeColor, font)
    local b = New("TextButton", { Position = px(x, y), Size = px(w, h),
        BackgroundColor3 = textColor, BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = text, TextSize = size, TextColor3 = textColor,
        FontFace = font or SANS }, parent)
    corner(b, 6)
    local s = outline(b, strokeColor)
    b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.92 }) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = 1 }) end)
    b.MouseButton1Down:Connect(function() tween(b, 0.06, { BackgroundTransparency = 0.84 }) end)
    b.MouseButton1Up:Connect(function() tween(b, 0.12, { BackgroundTransparency = 0.92 }) end)
    ripple(b, textColor)
    return b, s
end

local function halo(parent, color, layers, alpha, radius, step)
    local out = {}
    for i = 1, layers do
        local f = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ZIndex = 0 }, parent)
        corner(f, radius)
        local t = 1 - alpha * (1 - (i - 1) / layers)
        out[i] = { New("UIStroke", { Color = color, Thickness = i * (step or 1.5),
            Transparency = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f), t }
    end
    return out
end

local function wash(parent, x, y, w, h, color, from, to, rot)
    local f = rect(parent, x, y, w, h, color)
    f.ZIndex = 0
    gradient(f, WHITE, ns(0, from, 1, to), rot)
    return f
end

local function chevron(parent, x, y, size, color)
    local holder = New("Frame", { Position = px(x, y), Size = px(size, size),
        BackgroundTransparency = 1 }, parent)
    local s = size / 32
    local function seg(row, a, b)
        local l, r = math.floor(a * s + 0.5), math.floor(b * s + 0.5)
        if r > l then rect(holder, l, row, r - l, 1, color) end
    end
    for row = 0, size - 1 do
        local v = (row + 0.5) / s
        local oL, oR = v * 0.5, 32 - v * 0.5
        if v < 20 then
            seg(row, oL, 8 + v * 0.4)
            seg(row, 24 - v * 0.4, oR)
        else
            seg(row, oL, oR)
        end
    end
    return holder
end

local function logo(parent, x, y, size)
    if LOGO_ASSET then
        return New("ImageLabel", { Position = px(x, y), Size = px(size, size),
            BackgroundTransparency = 1, Image = LOGO_ASSET, ImageColor3 = Config.Accent,
            ScaleType = Enum.ScaleType.Fit }, parent)
    end
    return chevron(parent, x, y, size, Config.Accent)
end

local function Module(name, cat, desc, bind, paid, momentary)
    local m = { Name = name, Category = cat, Desc = desc or "", Bind = bind, Paid = paid or false,
        Momentary = momentary or false,
        Enabled = false, Connections = {}, Instances = {}, Cleanups = {} }
    function m:On(fn)      table.insert(self.Connections, fn) end
    function m:Keep(i)     table.insert(self.Instances, i) return i end
    function m:Cleanup(fn) table.insert(self.Cleanups, fn) end
    function m:Start()     self.Enabled = true end
    function m:Stop()
        self.Enabled = false
        for _, fn in ipairs(self.Cleanups) do pcall(fn) end
        for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
        for _, i in ipairs(self.Instances)   do pcall(function() i:Destroy() end) end
        self.Connections, self.Instances, self.Cleanups = {}, {}, {}
    end
    Config.Modules[name] = m
    table.insert(Config.Order, m)
    return m
end

local function descFor(m)
    return m.Desc .. (m.Paid and " · paid" or "")
end

local gui = New("ScreenGui", { Name = Config.Name, ResetOnSpawn = false,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = LP:WaitForChild("PlayerGui") })

local toastHolder = New("Frame", { AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16), Size = px(280, 220),
    BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)

local MAX_TOASTS = 4
local toasts = {}

local function dismissToast(rec)
    if rec.gone then return end
    rec.gone = true
    local i = table.find(toasts, rec)
    if i then table.remove(toasts, i) end
    tween(rec.label, 0.2, { BackgroundTransparency = 1, TextTransparency = 1 })
    tween(rec.stroke, 0.2, { Transparency = 1 })
    tween(rec.tick, 0.2, { BackgroundTransparency = 1 })
    task.delay(0.22, function()
        if rec.label and rec.label.Parent then rec.label:Destroy() end
    end)
end

local function Toast(text)
    local t = New("TextLabel", { Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.bar, BackgroundTransparency = 1, TextTransparency = 1,
        Text = "    " .. text, TextColor3 = T.text, TextSize = 12, FontFace = SANS,
        TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
        BorderSizePixel = 0, Parent = toastHolder })
    corner(t, 6)
    local stroke = outline(t, T.lineStrong, 1)
    local tick = rect(t, 0, 9, 2, 16, Config.Accent, 1)

    local rec = { label = t, stroke = stroke, tick = tick, gone = false }
    table.insert(toasts, rec)
    while #toasts > MAX_TOASTS do dismissToast(toasts[1]) end

    tween(t, 0.18, { BackgroundTransparency = 0, TextTransparency = 0 })
    tween(stroke, 0.18, { Transparency = 0 })
    tween(tick, 0.18, { BackgroundTransparency = 0 })
    task.delay(2.4, function() dismissToast(rec) end)
end

local function stubExecutor()
    local ok, name = pcall(function() return identifyexecutor and identifyexecutor() end)
    return (ok and type(name) == "string" and name ~= "") and name or "Unknown"
end

local function stubFingerprint()
    local ok, id = pcall(function() return gethwid and gethwid() end)
    if ok and id then return tostring(id), true end
    ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if ok and id then return tostring(id), true end
    return HS:GenerateGUID(false), false
end

local PLATFORM_NAMES = {
    [Enum.Platform.Windows] = "Windows",
    [Enum.Platform.OSX]     = "macOS",
    [Enum.Platform.Linux]   = "Linux",
    [Enum.Platform.Android] = "Android",
    [Enum.Platform.IOS]     = "iOS",
    [Enum.Platform.UWP]     = "Windows",
    [Enum.Platform.XBoxOne] = "Xbox",
    [Enum.Platform.PS4]     = "PlayStation",
    [Enum.Platform.PS5]     = "PlayStation",
}
local function stubDevice()
    local ok, platform = pcall(function() return UIS:GetPlatform() end)
    local name = ok and PLATFORM_NAMES[platform]
    if name then return name end
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then return "Mobile" end
    if UIS.GamepadEnabled and not UIS.KeyboardEnabled then return "Console" end
    return "Desktop"
end

local function clip(text)
    return (pcall(function() setclipboard(text) end))
end

local EXECUTOR = stubExecutor()
local HWID, HWID_OK = stubFingerprint()
local SUPPORTED_GAMES = {
    [5593470048] = { Name = "Visual Pianos", Category = "Visual Pianos" },
    [73814454293317] = { Name = "Engine", Category = "Engine" },
}
local URLS = {
    discord = "https://discord.gg/vanta",
    getKey  = "https://vanta.example/key",
    plans   = "https://vanta.example/plans",
}

local PANEL_W, PANEL_H = 880, 580
local SIDEBAR_W, HEADER_H = 248, 64
local MINI_W, COLLAPSED_H = 320, 40
local COL_X, COL_W = SIDEBAR_W + 24, PANEL_W - SIDEBAR_W - 48

local frame = New("Frame", { Size = px(PANEL_W, PANEL_H), Position = px(40, 70),
    BackgroundColor3 = T.bg, BackgroundTransparency = ALPHA.panel, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = false, ZIndex = 1, Parent = gui })
corner(frame, 6)
outline(frame, T.line)
local uiScale = New("UIScale", { Scale = 1 }, frame)

local body = New("Frame", { Size = px(PANEL_W, PANEL_H), BackgroundTransparency = 1 }, frame)

local grid = New("Frame", { Position = px(SIDEBAR_W, HEADER_H),
    Size = px(PANEL_W - SIDEBAR_W, PANEL_H - HEADER_H), BackgroundTransparency = 1,
    ClipsDescendants = true }, body)
for gx = 31, PANEL_W - SIDEBAR_W - 1, 32 do rect(grid, gx, 0, 1, PANEL_H, T.grid, ALPHA.grid) end
for gy = 31, PANEL_H - HEADER_H - 1, 32 do rect(grid, 0, gy, PANEL_W, 1, T.grid, ALPHA.grid) end

local sidebar = rect(body, 0, 0, SIDEBAR_W, PANEL_H, T.bar, ALPHA.sidebar)
corner(sidebar, 6)
rect(sidebar, SIDEBAR_W - 1, 0, 1, PANEL_H, T.line)

local SB_L, SB_R = 24, 224

do
    local avatar = rect(sidebar, SB_L, 22, 44, 44, T.chip)
    corner(avatar, 8)
    outline(avatar, T.lineStrong)
    local letter = New("TextLabel", { Size = px(44, 44), BackgroundTransparency = 1,
        Text = LP.Name:sub(1, 1):upper(), TextColor3 = T.text, TextSize = 18,
        FontFace = SANS_SEMI }, avatar)
    local img = New("ImageLabel", { Size = px(44, 44), BackgroundTransparency = 1,
        ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop }, avatar)
    corner(img, 8)

    local ring = rect(sidebar, SB_L + 34, 56, 12, 12, T.bar)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    local dot = rect(ring, 2, 2, 8, 8, T.green)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)

    local shown = false
    local function reveal()
        if shown or not img.Parent then return end
        shown = true
        tween(img, 0.25, { ImageTransparency = 0 })
        tween(letter, 0.25, { TextTransparency = 1 })
    end
    img:GetPropertyChangedSignal("IsLoaded"):Connect(function()
        if img.IsLoaded then reveal() end
    end)
    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150)
        end)
        img.Image = (ok and content)
            or ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(LP.UserId)
        local fetched = false
        pcall(function()
            ContentProvider:PreloadAsync({ img }, function(_, status)
                fetched = status == Enum.AssetFetchStatus.Success
            end)
        end)
        if fetched or img.IsLoaded then reveal() end
    end)
end

label(sidebar, "PERSONAL ACCOUNT", 82, 35, 142, 10, T.label, MONO)
label(sidebar, "@" .. LP.Name, 82, 54, 142, 14, T.text, SANS_SEMI)

local function sbGroup(text, cy) label(sidebar, text, SB_L, cy, 200, 10, T.label, MONO) end
local function sbRow(name, value, cy)
    label(sidebar, name, SB_L, cy, 92, 13, T.dim)
    return label(sidebar, value, SB_R - 112, cy, 112, 12, T.text, MONO, RIGHT)
end
local function sbDivider(y) rect(sidebar, SB_L, y, SB_R - SB_L, 1, T.line) end

sbDivider(86)
sbGroup("IDENTITY", 106)
sbRow("Executor", EXECUTOR, 132)
sbDivider(152)

sbGroup("MACHINE", 172)
sbRow("Device", stubDevice(), 198)
sbRow("HWID", HWID_OK and "HWID Linked" or "Session only", 224)
sbDivider(244)

rect(sidebar, 0, 256, 2, 104, Config.Accent)
sbGroup("SESSION", 268)
local timerVal  = sbRow("Timer", "00:00:00", 294)
local pingVal   = sbRow("Ping", "-- ms", 320)
local statusVal = sbRow("Status", "Connected", 346)
local statusDot = rect(sidebar, 0, 346 - 3 - LIFT, 6, 6, T.green)
corner(statusDot, 3)
do
    local function place()
        local w = TextService:GetTextSize(statusVal.Text, 12, Enum.Font.RobotoMono, Vector2.new(400, 40)).X
        statusDot.Position = px(SB_R - math.floor(w) - 14, 346 - 3 - LIFT)
    end
    statusVal:GetPropertyChangedSignal("Text"):Connect(place)
    place()
end
sbDivider(372)

sbGroup("SHORTCUTS", 392)
sbRow("Show / hide", Config.ToggleKey.Name, 418)
sbRow("Navigate", "Up / Down", 444)
sbRow("Toggle", "Enter", 470)

sbDivider(PANEL_H - 52)
label(sidebar, ("%s v%s"):format(Config.Name, Config.Version), SB_L, PANEL_H - 26, 130, 12, T.dim)
label(sidebar, "STABLE", SB_R - 60, PANEL_H - 26, 60, 10, T.label, MONO, RIGHT)

local header = rect(body, SIDEBAR_W, 0, PANEL_W - SIDEBAR_W, HEADER_H, T.bar, ALPHA.header)
corner(header, 6)
rect(header, 0, HEADER_H - 1, PANEL_W - SIDEBAR_W, 1, T.line)

logo(header, 24, 18, 28)
local wordmark = label(header, Config.Name, 62, 32, 68, 19, T.text, SANS_SEMI)

local verified = New("TextLabel", { Position = px(134, 21), Size = px(78, 22),
    BackgroundColor3 = Config.Accent, BackgroundTransparency = 1, Text = "VERIFIED",
    TextSize = 10, TextColor3 = Config.Accent, FontFace = MONO }, header)
corner(verified, 11)
outline(verified, Config.Accent)

local catBar = New("Frame", { Position = px(230, 20), Size = px(310, 24),
    BackgroundTransparency = 1 }, header)

local closeBtn = outlineButton(header, "×", 554, 20, 24, 24, 16, T.dim, T.line)
local minBtn   = outlineButton(header, "–", 584, 20, 24, 24, 14, T.dim, T.line)

local listedName = SUPPORTED_GAMES[game.PlaceId]
if type(listedName) == "table" then listedName = listedName.Name end
do
    local strip = New("Frame", { Position = px(COL_X, 80), Size = px(COL_W, 36),
        BackgroundColor3 = T.bar, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, body)
    corner(strip, 6)
    outline(strip, T.line)
    label(strip, "GAME", 14, 18, 40, 10, T.label, MONO)
    label(strip, listedName or "Game not listed", 62, 18, 280, 13, listedName and T.text or T.amber)
    label(strip, listedName and "SESSION ACTIVE" or "WAITING FOR SESSION",
        COL_W - 14 - 200, 18, 200, 10, T.dim, MONO, RIGHT)
end

label(body, "License key", COL_X, 136, 200, 13, T.text, SANS_SEMI)

local keyStroke, keyBox
do
    local field = rect(body, COL_X, 150, COL_W - 130, 38, T.bar)
    corner(field, 6)
    keyStroke = outline(field, T.lineStrong)
    keyBox = New("TextBox", { Size = px(COL_W - 130, 38), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Enter key", PlaceholderColor3 = T.label, TextColor3 = T.text,
        TextSize = 13, FontFace = MONO, TextXAlignment = LEFT, ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.AtEnd }, field)
    New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, keyBox)
    textBoxes[#textBoxes + 1] = keyBox
end

local activateBtn = New("TextButton", { Position = px(COL_X + COL_W - 120, 150), Size = px(120, 38),
    BackgroundColor3 = Config.Accent, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "", TextSize = 13, TextColor3 = T.bg, FontFace = SANS_SEMI }, body)
corner(activateBtn, 6)
ripple(activateBtn, WHITE)
-- own label above the sheen overlay so the text never washes out
local activateLbl = New("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "Activate", TextSize = 13, TextColor3 = T.bg, FontFace = SANS_SEMI, ZIndex = 2 }, activateBtn)

local getKeyBtn = New("TextButton", { Position = px(COL_X, 204 - 9 - LIFT), Size = px(52, 18),
    BackgroundTransparency = 1, AutoButtonColor = false, Text = "Get key", TextSize = 12,
    TextColor3 = Config.Accent, FontFace = SANS_SEMI, TextXAlignment = LEFT }, body)
label(body, "·  Keys are tied to this device. Keep yours private.", COL_X + 58, 204, 420, 12, T.dim)

local discordBtn  = outlineButton(body, "Discord", COL_X, 222, 112, 32, 12, T.text, T.lineStrong)
local hwidBtn     = outlineButton(body, "Copy HWID", COL_X + 122, 222, 112, 32, 12, T.text, T.lineStrong)
local settingsBtn = outlineButton(body, "Settings", COL_X + 244, 222, 112, 32, 12, T.text, T.lineStrong)

do
    local box = New("Frame", { Position = px(COL_X, 266), Size = px(COL_W, 32),
        BackgroundColor3 = T.amber, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, body)
    corner(box, 6)
    outline(box, T.amber:Lerp(T.bg, 0.6))
    rect(box, 0, 8, 2, 16, T.amber)
    label(box, "Piano and 4 songs are free. ESP, Fly, Click TP and Server Hop need a key.", 16, 16, 520, 12, T.amber)
end

local MOD_HDR_Y, MOD_HDR_H = 300, 16
label(body, "MODULES", COL_X, MOD_HDR_Y + 8, 60, 10, T.label, MONO)
local countLbl = label(body, "0 MODULES", COL_X + COL_W - 120, MOD_HDR_Y + 8, 120, 10, T.dim, MONO, RIGHT)

local search = New("TextBox", { Position = px(COL_X + 64, MOD_HDR_Y - 1 - LIFT), Size = px(170, MOD_HDR_H + 2),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "/ filter",
    PlaceholderColor3 = T.label, TextColor3 = T.text, TextSize = 11, FontFace = MONO,
    TextXAlignment = LEFT, ClearTextOnFocus = false }, body)
textBoxes[#textBoxes + 1] = search
local searchLine = rect(search, 0, MOD_HDR_H + 1, 170, 1, T.line)

local CARD_H = 84
local card = New("Frame", { Position = px(COL_X, PANEL_H - 24 - CARD_H),
    Size = px(COL_W, CARD_H), BackgroundColor3 = T.bar, BackgroundTransparency = ALPHA.card,
    BorderSizePixel = 0 }, body)
corner(card, 6)
outline(card, accentEdge)
label(card, "Premium Access", 20, 32, 300, 14, T.text, SANS_SEMI)
label(card, "ESP, Fly and all 438 songs. One key, this device, permanent.", 20, 54, 420, 12, T.dim)
local plansBtn = outlineButton(card, "View Plans", COL_W - 20 - 108, 27, 108, 30, 12,
    Config.Accent, Config.Accent, SANS_SEMI)

local LIST_Y = MOD_HDR_Y + MOD_HDR_H + 10
local LIST_H = math.max(100, (PANEL_H - 24 - CARD_H - 12) - LIST_Y)
local content = New("ScrollingFrame", { Position = px(COL_X, LIST_Y), Size = px(COL_W, LIST_H),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.lineStrong, ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    VerticalScrollBarInset = Enum.ScrollBarInset.None }, body)
New("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1),
    PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 1) }, content)
New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
local listVeil = rect(body, COL_X - 1, LIST_Y - 1, COL_W + 2, LIST_H + 2, T.bg, ALPHA.veil)

local miniBar = New("Frame", { Size = px(MINI_W, COLLAPSED_H), BackgroundTransparency = 1,
    Visible = false }, frame)
logo(miniBar, 12, 11, 18)
label(miniBar, Config.Name, 38, 20, 50, 13, T.text, SANS_SEMI)
local miniDot = rect(miniBar, 90, 20 - 3 - LIFT, 6, 6, T.green)
corner(miniDot, 3)
local miniTimer = label(miniBar, "00:00:00", 104, 20, 90, 11, T.dim, MONO)
local expandBtn    = outlineButton(miniBar, "+", 258, 8, 24, 24, 14, T.dim, T.line)
local miniCloseBtn = outlineButton(miniBar, "×", 288, 8, 24, 24, 16, T.dim, T.line)

local rows, activeCat, awaiting = {}, nil, nil
local minimized = false
local focusedModule = nil
local activated = false
local KEY_GATE = true
local refresh, setVisual, toggle, save

local function hum()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local ESP = Module("Player ESP", "Universal", "boxes, names, health", nil, true)
local esp = {}
local function espDraw(c, p)
    local d = Drawing.new(c)
    for k, v in pairs(p) do pcall(function() d[k] = v end) end
    pcall(function() d.AlwaysOnTop = true end)
    return d
end

local function espAdd(plr)
    if esp[plr] or plr == LP then return end
    esp[plr] = {
        box  = espDraw("Square", { Thickness = 1, Filled = false, Color = Color3.new(1, 1, 1) }),
        name = espDraw("Text", { Size = 13, Center = true, Outline = true, Color = Color3.new(1, 1, 1) }),
        dist = espDraw("Text", { Size = 11, Center = true, Outline = true, Color = Color3.fromRGB(180, 180, 180) }),
        hpBg = espDraw("Square", { Filled = true, Color = Color3.new(0, 0, 0) }),
        hp   = espDraw("Square", { Filled = true, Color = Color3.fromRGB(0, 255, 120) }),
    }
end

local function espRemove(plr)
    local t = esp[plr]
    if not t then return end
    for _, d in pairs(t) do pcall(function() d:Remove() end) end
    esp[plr] = nil
end

function ESP.Start()
    if not Drawing then warn("[Vanta] Drawing API unavailable") return false end
    for _, p in ipairs(Players:GetPlayers()) do espAdd(p) end
    ESP:On(Players.PlayerAdded:Connect(espAdd))
    ESP:On(Players.PlayerRemoving:Connect(espRemove))
    ESP:On(RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        for plr, t in pairs(esp) do
            local ch  = plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local show = hrp and hum and hum.Health > 0 and (not LP.Team or plr.Team ~= LP.Team)
            local dist = show and (cam.CFrame.Position - hrp.Position).Magnitude or 0
            if show and dist > 1200 then show = false end
            if not show then
                for _, d in pairs(t) do d.Visible = false end
            else
                local top    = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                local bottom = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local _, on  = cam:WorldToViewportPoint(hrp.Position)
                local h, w   = math.abs(top.Y - bottom.Y), math.abs(top.Y - bottom.Y) / 2
                t.box.Visible, t.box.Size, t.box.Position = on, Vector2.new(w * 2, h), Vector2.new(top.X - w, top.Y)
                t.name.Visible, t.name.Text, t.name.Position = on, plr.Name, Vector2.new(top.X, top.Y - 15)
                t.dist.Visible, t.dist.Text, t.dist.Position = on, ("%dm"):format(dist), Vector2.new(top.X, top.Y + h + 2)
                local f = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                t.hpBg.Visible, t.hpBg.Size, t.hpBg.Position = on, Vector2.new(2, h), Vector2.new(top.X - w - 4, top.Y)
                t.hp.Visible, t.hp.Size, t.hp.Position = on, Vector2.new(2, h * f), Vector2.new(top.X - w - 4, top.Y + h * (1 - f))
            end
        end
    end))
    ESP:Cleanup(function() for p in pairs(esp) do espRemove(p) end end)
end

do
    local Fly = Module("Fly", "Universal", "WASD + space, 60 studs/s", nil, true)
    function Fly.Start()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local bv = Fly:Keep(Instance.new("BodyVelocity"))
        bv.MaxForce, bv.Parent = Vector3.new(1e5, 1e5, 1e5), hrp
        local bg = Fly:Keep(Instance.new("BodyGyro"))
        bg.MaxTorque, bg.P, bg.CFrame, bg.Parent = Vector3.new(1e5, 1e5, 1e5), 1e4, hrp.CFrame, hrp
        Fly:On(RunService.RenderStepped:Connect(function()
            local cf, dir = workspace.CurrentCamera.CFrame, Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W)           then dir += cf.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.S)           then dir -= cf.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.A)           then dir -= cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D)           then dir += cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space)       then dir += Vector3.yAxis  end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis  end
            bv.Velocity = dir.Magnitude > 0 and dir.Unit * 60 or Vector3.zero
            bg.CFrame = cf
        end))
        Fly:Cleanup(function()
            local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if r then r.AssemblyLinearVelocity = Vector3.zero end
        end)
    end
end

do
    local Fullbright = Module("Fullbright", "Universal", "kill the fog and dark", Enum.KeyCode.F, false)
    function Fullbright.Start()
        local saved = {}
        for _, p in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "FogEnd", "ClockTime" }) do
            saved[p] = Lighting[p]
        end
        Fullbright:Cleanup(function()
            for p, v in pairs(saved) do pcall(function() Lighting[p] = v end) end
        end)
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(150, 150, 150)
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
        Lighting.FogEnd = 1e6
        Lighting.ClockTime = 14
    end
end

do
    local Speed = Module("Speed", "Universal", "walkspeed 45, restores on off", Enum.KeyCode.C, false)
    function Speed.Start()
        local h = hum()
        if not h then return false end
        local old = h.WalkSpeed
        h.WalkSpeed = 45
        Speed:Cleanup(function()
            local cur = hum()
            if cur then cur.WalkSpeed = old end
        end)
    end
end

do
    local Noclip = Module("Noclip", "Universal", "walk through geometry", Enum.KeyCode.N, false)
    function Noclip.Start()
        Noclip:On(RunService.Stepped:Connect(function()
            local ch = LP.Character
            if not ch then return end
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end))
    end
end

do
    local InfJump = Module("Infinite Jump", "Universal", "jump while airborne", Enum.KeyCode.J, false)
    function InfJump.Start()
        InfJump:On(UIS.JumpRequest:Connect(function()
            local h = hum()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end))
    end
end

do
    local ClickTP = Module("Click TP", "Universal", "teleport to the cursor", Enum.KeyCode.T, true)
    function ClickTP.Start()
        ClickTP:On(UIS.InputBegan:Connect(function(i, gp)
            if gp or typing() then return end
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if not frame.Visible then return end
            local h = hum()
            local cam = workspace.CurrentCamera
            if not (h and h.RootPart and cam) then return end
            local ray = cam:ScreenPointToRay(i.Position.X, i.Position.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { LP.Character }
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
            if hit then h.RootPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0)) end
        end))
    end
end

do
    local Hide = Module("Hide Character", "Universal", "fade your own model", Enum.KeyCode.H, false)
    function Hide.Start()
        local ch = LP.Character
        if not ch then return false end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                local old = p.LocalTransparencyModifier
                p.LocalTransparencyModifier = 0.9
                Hide:Cleanup(function()
                    if p.Parent then p.LocalTransparencyModifier = old end
                end)
            end
        end
    end
end

do
    local AutoClick = Module("Auto Click", "Universal", "10 clicks per second", nil, false)
    function AutoClick.Start()
        AutoClick:On(task.spawn(function()
            while AutoClick.Enabled do
                if frame.Visible and not typing() and not awaiting then
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton1(Vector2.zero)
                    end)
                end
                task.wait(0.1)
            end
        end))
    end
end

do
    local AntiAFK = Module("Anti AFK", "Universal", "no 20 minute kick", nil, false)
    function AntiAFK.Start()
        AntiAFK:On(LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end))
    end
end

do
    local FPS = Module("FPS HUD", "Universal", "frame rate and ping", Enum.KeyCode.P, false)
    function FPS.Start()
        local box = New("TextLabel", { Position = px(18, 18), Size = px(150, 40),
            BackgroundColor3 = T.bg, BackgroundTransparency = 0.2, BorderSizePixel = 0,
            Text = "", TextColor3 = T.text, TextSize = 11, FontFace = MONO,
            TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 15, Parent = gui })
        corner(box, 6)
        outline(box, T.line)
        New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, box)
        FPS:Keep(box)
        local frames, acc = 0, 0
        FPS:On(RunService.Heartbeat:Connect(function(dt)
            frames += 1
            acc += dt
            if acc < 0.5 then return end
            local ping = 0
            pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            box.Text = ("fps   %d\nping  %dms"):format(math.floor(frames / acc), ping)
            frames, acc = 0, 0
        end))
    end
end

do
    local Hop = Module("Server Hop", "Universal", "move to a quieter server", nil, true, true)
    function Hop.Start()
        Toast("finding a server")
        task.spawn(function()
            local ok, res = pcall(function()
                return HS:JSONDecode(game:HttpGet(
                    ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100")
                    :format(game.PlaceId)))
            end)
            if not ok or type(res) ~= "table" or type(res.data) ~= "table" then
                Toast("hop failed")
                Hop:Stop()
                task.delay(0.1, function() setVisual(Hop) end)
                return
            end
            for _, s in ipairs(res.data) do
                if tonumber(s.playing) < tonumber(s.maxPlayers) and s.id ~= game.JobId then
                    Toast(("hopping · %d/%d"):format(s.playing, s.maxPlayers))
                    task.delay(1.5, function()
                        pcall(function() Teleport:TeleportToPlaceInstance(game.PlaceId, s.id, LP) end)
                    end)
                    return
                end
            end
            Toast("no open servers")
            Hop:Stop()
            task.delay(0.1, function() setVisual(Hop) end)
        end)
    end
end

do
    local Rejoin = Module("Rejoin", "Universal", "reconnect to this server", nil, false, true)
    function Rejoin.Start()
        Toast("rejoining in 2s")
        task.delay(2, function()
            local ok = pcall(function() Teleport:Teleport(game.PlaceId, LP) end)
            if not ok then
                Toast("rejoin failed")
                Rejoin:Stop()
                task.delay(0.1, function() setVisual(Rejoin) end)
                return
            end
            task.delay(6, function()
                if Rejoin.Enabled then
                    Rejoin:Stop()
                    setVisual(Rejoin)
                end
            end)
        end)
    end
end

do
    local CopyJob = Module("Copy JobId", "Universal", "for private links", nil, false, true)
    function CopyJob.Start()
        clip(game.JobId)
        Toast("JobId copied")
        CopyJob:Stop()
        task.delay(0.1, function() setVisual(CopyJob) end)
    end
end

do
    local Reset = Module("Reset Character", "Universal", "respawn now", Enum.KeyCode.R, false, true)
    function Reset.Start()
        local h = hum()
        if h then h.Health = 0 end
        Reset:Stop()
        task.delay(0.1, function() setVisual(Reset) end)
    end
end

local Piano = Module("Piano", "Universal", "song browser", nil, false)
do
    local function setup()
        local PRIMARY_API = "https://raw.githubusercontent.com/pixel-pinecone/vanta-data/main/midi/"
        local PRIMARY_CAT = "https://raw.githubusercontent.com/pixel-pinecone/vanta-data/main/catalog.json"
        local MIDI_API    = "https://api.nanomidi.net/api/midi/"
        local CATALOG_URL = "https://api.nanomidi.net/api/midiData"
        local SOURCES = {
            { id = "primary",  status = "live",   catalog = PRIMARY_CAT, midi = PRIMARY_API },
            { id = "nanomidi", status = "backup", catalog = CATALOG_URL, midi = MIDI_API },
        }

        Piano.Speed = 1

        local LAYOUT     = "1!2@34$5%6^78*9(0qQwWeErtTyYuiIoOpPasSdDfgGhHjJklLzZxcCvVbBnm"
        local START_NOTE = 36

        local DEFAULT_BEAT, DEFAULT_HOLD = 0.25, 0.06
        local MIN_KEYS        = 24
        local RESCAN_COOLDOWN = 2
        local ECHO_WINDOW     = 0.3
        local SONGS_KEY       = Enum.KeyCode.BackSlash
        local MAX_ROWS        = 50

        local MOUSE_LEFT, REPEAT = 0, 0

        local CATALOG_FILE     = "vanta_songs.json"
        local CATALOG_TTL      = 6 * 3600
        local CATALOG_MIN_BODY = 200
        local CATALOG_FALLBACK = ""

        local BUILTIN = {
            { name = "Twinkle Twinkle", artist = "built-in", beat = 0.32, hold = 0.08,
              notes = "t t o o p p o - i i u u y y t - o o i i u u y - o o i i u u y - t t o o p p o - i i u u y y t" },
            { name = "Ode to Joy", artist = "built-in", beat = 0.30, hold = 0.08,
              notes = "u u i o o i u y t t y u u - y y - u u i o o i u y t t y u y - t t" },
            { name = "Mary Had a Little Lamb", artist = "built-in", beat = 0.30, hold = 0.08,
              notes = "u y t y u u u - y y y - u o o - u y t y u u u u y y u y t" },
            { name = "Für Elise", artist = "built-in", beat = 0.17, hold = 0.05,
              notes = "f D f D f a d s p - - t u p a - - u O a s - - u f D f D f a d s p - - t u p a - - u s a p" },
        }

        local GuiService = game:GetService("GuiService")
        local vimOk, VIM = pcall(game.GetService, game, "VirtualInputManager")
        if not vimOk then VIM = nil end
        local canRequest = type(request) == "function"

        Config.Synthetic = {}

        local state = {
            map = nil, reason = nil, lastWalk = -math.huge, printed = nil,
            path = nil, echo = nil, expect = nil, expectAt = 0,
            gen = 0, held = {}, warned = {}, coveredGen = nil, midi = {},
            shifted = {},
            queue = {}, song = 1, playing = nil,
            caches = {}, cacheRead = false, bundled = nil,
            active = nil, source = nil, fetching = false, lastError = nil,
        }

        local function configured(src)
            return src.catalog ~= "" and not src.catalog:find("/YOU/", 1, true)
        end

        local function warnOnce(id, msg)
            if state.warned[id] then return end
            state.warned[id] = true
            warn("[Vanta] " .. msg)
        end

        local SHIFTED = { ["!"] = "1", ["@"] = "2", ["#"] = "3", ["$"] = "4", ["%"] = "5",
            ["^"] = "6", ["&"] = "7", ["*"] = "8", ["("] = "9", [")"] = "0" }
        local DIGIT_ORDER = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }

        local function isBlack(ch) return SHIFTED[ch] ~= nil or ch:match("^%u$") ~= nil end
        local function unshift(ch) return SHIFTED[ch] or ch:lower() end

        local function keyCodeFor(label)
            if label:match("^%d$") then return Enum.KeyCode[DIGIT_ORDER[tonumber(label) + 1]] end
            if label:match("^%a$") then return Enum.KeyCode[label:upper()] end
            return nil
        end

        local function charForNote(note)
            local i = note - START_NOTE
            while i < 0 do i += 12 end
            while i >= #LAYOUT do i -= 12 end
            return LAYOUT:sub(i + 1, i + 1)
        end

        local function parseMidi(data)
            local pos = 1
            local function need(n)
                if pos + n - 1 > #data then error("truncated MIDI data", 0) end
            end
            local function u8() need(1); local b = string.byte(data, pos); pos += 1; return b end
            local function u16() need(2); local v = string.unpack(">I2", data, pos); pos += 2; return v end
            local function u32() need(4); local v = string.unpack(">I4", data, pos); pos += 4; return v end
            local function tag() need(4); local s = string.sub(data, pos, pos + 3); pos += 4; return s end
            local function vlq()
                local v = 0
                for _ = 1, 4 do
                    local b = u8()
                    v = v * 128 + bit32.band(b, 0x7F)
                    if b < 0x80 then return v end
                end
                error("bad variable-length quantity", 0)
            end

            if tag() ~= "MThd" then error("not a MIDI file (no MThd)", 0) end
            local headerLen = u32()
            local headerEnd = pos + headerLen
            local _, trackCount, division = u16(), u16(), u16()
            pos = headerEnd

            local notes, tempos, tracks = {}, {}, 0
            while pos + 7 <= #data and tracks < trackCount do
                local id, len = tag(), u32()
                local stop = pos + len
                if id == "MTrk" then
                    tracks += 1
                    local tick, running = 0, nil
                    while pos < stop do
                        tick += vlq()
                        local status = u8()
                        if status < 0x80 then
                            if not running then error("running status with no previous status", 0) end
                            status = running
                            pos -= 1
                        elseif status < 0xF0 then
                            running = status
                        end
                        if status == 0xFF then
                            local kind, n = u8(), vlq()
                            if kind == 0x51 and n == 3 then
                                need(3)
                                local a, b, c = string.byte(data, pos, pos + 2)
                                table.insert(tempos, { tick = tick, us = a * 65536 + b * 256 + c })
                            end
                            pos += n
                            if kind == 0x2F then break end
                        elseif status == 0xF0 or status == 0xF7 then
                            pos += vlq()
                        elseif status >= 0xF1 then
                            pos += (status == 0xF2 and 2) or ((status == 0xF1 or status == 0xF3) and 1) or 0
                        else
                            local kind = bit32.rshift(status, 4)
                            if kind == 0x9 then
                                local note, velocity = u8(), u8()
                                if velocity > 0 then
                                    table.insert(notes, { tick = tick, note = note, order = #notes })
                                end
                            elseif kind == 0xC or kind == 0xD then
                                pos += 1
                            else
                                pos += 2
                            end
                        end
                    end
                end
                pos = stop
            end
            if #notes == 0 then error("no notes in MIDI file", 0) end

            table.sort(tempos, function(a, b) return a.tick < b.tick end)
            table.sort(notes, function(a, b)
                if a.tick ~= b.tick then return a.tick < b.tick end
                return a.order < b.order
            end)

            local smpteTick
            if bit32.band(division, 0x8000) ~= 0 then
                local fps = 256 - bit32.rshift(division, 8)
                smpteTick = 1 / (fps * math.max(bit32.band(division, 0xFF), 1))
            end
            local perQuarter = math.max(division, 1)
            local function secondsPerTick(us) return smpteTick or (us / 1e6 / perQuarter) end

            local events, ti, us, lastTick, now, prev = {}, 1, 500000, 0, 0, 0
            for _, n in ipairs(notes) do
                while ti <= #tempos and tempos[ti].tick <= n.tick do
                    now += (tempos[ti].tick - lastTick) * secondsPerTick(us)
                    lastTick, us = tempos[ti].tick, tempos[ti].us
                    ti += 1
                end
                now += (n.tick - lastTick) * secondsPerTick(us)
                lastTick = n.tick
                table.insert(events, { dt = now - prev, ch = charForNote(n.note) })
                prev = now
            end
            return events
        end

        local function compileSong(song)
            local events, pending, beat, skipped = {}, 0, song.beat or DEFAULT_BEAT, {}
            for token in song.notes:gmatch("%S+") do
                if token == "-" then
                    pending += beat
                elseif #token == 1 and LAYOUT:find(token, 1, true) then
                    table.insert(events, { dt = pending, ch = token })
                    pending = beat
                else
                    skipped[token] = true
                end
            end
            if next(skipped) then
                local list = {}
                for t in pairs(skipped) do table.insert(list, t) end
                warn(("[Vanta] %s: not on the keyboard, skipped: %s"):format(song.name, table.concat(list, " ")))
            end
            return events
        end

        local function loadMidi(song)
            local file, id = song.file, song.src or state.active
            local key = tostring(id) .. "/" .. file
            if state.midi[key] then return state.midi[key] end
            if not canRequest then return nil, "this executor has no request()" end
            local src
            for _, s in ipairs(SOURCES) do if s.id == id then src = s end end
            if not src then return nil, "no source for this song" end
            if not configured(src) then return nil, src.status .. ": placeholder URL, not set up" end

            local ok, res = pcall(request, { Url = src.midi .. HS:UrlEncode(file), Method = "GET" })
            local code = ok and type(res) == "table" and (tonumber(res.StatusCode) or (res.Success and 200)) or 0
            local body = code == 200 and res.Body
            if type(body) == "string" and body:sub(1, 4) == "MThd" then
                local parsed, events = pcall(parseMidi, body)
                if parsed then
                    state.midi[key] = events
                    return events
                end
                return nil, "MIDI parse failed: " .. tostring(events)
            elseif not ok then
                return nil, src.status .. ": request failed"
            end
            return nil, ("%s: HTTP %s"):format(src.status, tostring(code))
        end

        local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

        local function isShown(obj)
            local o = obj
            while o and o ~= game do
                if o:IsA("LayerCollector") then return o.Enabled end
                if o:IsA("GuiObject") and not o.Visible then return false end
                o = o.Parent
            end
            return false
        end

        local function keyLabel(btn)
            local best, bestSize, bestY
            local function consider(text, size, y)
                text = trim(text)
                if text:find("%s") then
                    local last
                    for piece in text:gmatch("%S+") do last = piece end
                    text = last or ""
                end
                local n = utf8.len(text)
                if not n or n < 1 or n > 2 then return end
                if not best or size > bestSize or (size == bestSize and y > bestY) then
                    best, bestSize, bestY = text, size, y
                end
            end
            if trim(btn.Text) ~= "" then
                consider(btn.Text, btn.TextBounds.Y, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2)
                if not best then return nil end
            end
            for _, d in ipairs(btn:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible then
                    consider(d.Text, d.TextBounds.Y, d.AbsolutePosition.Y + d.AbsoluteSize.Y / 2)
                end
            end
            return best and best:lower()
        end

        local function walk(root, groups)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextButton") and not d:IsDescendantOf(gui) and isShown(d) then
                    local lbl = keyLabel(d)
                    if lbl then
                        local g = groups[d.Parent]
                        if not g then g = {}; groups[d.Parent] = g end
                        table.insert(g, { button = d, label = lbl })
                    end
                end
            end
        end

        local function pickGroup(groups)
            local best, bestN = nil, 0
            for parent, g in pairs(groups) do
                if #g > bestN then best, bestN = parent, #g end
            end
            if not best or bestN < MIN_KEYS then return nil end

            local entries = {}
            for parent, g in pairs(groups) do
                local sibling = not best:IsA("LayerCollector") and parent ~= best
                    and parent.Parent == best.Parent and #g >= 5
                if parent == best or sibling then
                    for _, e in ipairs(g) do table.insert(entries, e) end
                end
            end

            local minY, maxY = math.huge, -math.huge
            for _, e in ipairs(entries) do
                e.y = e.button.AbsolutePosition.Y + e.button.AbsoluteSize.Y / 2
                e.x = e.button.AbsolutePosition.X
                minY, maxY = math.min(minY, e.y), math.max(maxY, e.y)
            end
            local split = (minY + maxY) / 2
            local twoRows = maxY - minY >= 4
            table.sort(entries, function(a, b)
                if a.x ~= b.x then return a.x < b.x end
                return a.y < b.y
            end)

            local map = { white = {}, black = {}, whiteLabels = {}, blackLabels = {}, count = 0, dupes = 0 }
            for _, e in ipairs(entries) do
                local black = twoRows and e.y < split
                local set = black and map.black or map.white
                if set[e.label] then
                    map.dupes += 1
                else
                    set[e.label] = e.button
                    table.insert(black and map.blackLabels or map.whiteLabels, e.label)
                    map.count += 1
                end
            end
            map.container = best
            map.is3D = not (best:IsA("ScreenGui") or best:FindFirstAncestorOfClass("ScreenGui") ~= nil)
            return map
        end

        local function scan()
            state.lastWalk = os.clock()
            local groups = {}
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if pg then pcall(walk, pg, groups) end
            local found = pickGroup(groups)
            if not found then
                groups = {}
                pcall(walk, workspace, groups)
                found = pickGroup(groups)
            end
            return found
        end

        local function mapValid()
            local m = state.map
            return m ~= nil and m.container:IsDescendantOf(game) and isShown(m.container)
        end

        local function resolve(ignoreCache, ignoreCooldown)
            if not ignoreCache and mapValid() then return false end
            if not ignoreCooldown and os.clock() - state.lastWalk < RESCAN_COOLDOWN then return false end
            local found
            local ok, err = pcall(function() found = scan() end)
            if not ok then warn("[Vanta] piano scan failed: " .. tostring(err)) end

            if found and not found.is3D and VIM then
                state.map, state.reason = found, nil
                local text = table.concat(found.whiteLabels, " ") .. " | black: " .. table.concat(found.blackLabels, " ")
                if text ~= state.printed then
                    state.printed = text
                    print("[Vanta] piano keys:", text)
                    if found.dupes > 0 then
                        warn(("[Vanta] %d duplicate key labels within one colour ignored"):format(found.dupes))
                    end
                end
            else
                state.map = nil
                if found and found.is3D then
                    state.reason = "3D piano"
                    warnOnce("3d", "piano buttons are on a 3D surface; screen clicks can't reach them")
                elseif found then
                    state.reason = "no VirtualInputManager"
                else
                    state.reason = "no keys found"
                end
            end
            return true
        end

        local function hold(id, release)
            if state.held[id] then state.held[id]() end
            local done = false
            local function once()
                if done then return end
                done = true
                if state.held[id] == once then state.held[id] = nil end
                release()
            end
            state.held[id] = once
            return once
        end

        local function releaseAll()
            for _, release in pairs(state.held) do pcall(release) end
            state.held, state.shifted = {}, {}
            if state.path == "vim" then
                pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end)
            elseif state.path == "os" then
                pcall(keyrelease, 0x10)
            end
        end

        local function vkFor(kc)
            if kc == Enum.KeyCode.LeftShift then return 0x10 end
            if #kc.Name == 1 then return kc.Name:byte() end
            local d = table.find(DIGIT_ORDER, kc.Name)
            return d and (0x30 + d - 1)
        end

        local function sendKey(down, kc)
            if down then Config.Synthetic[kc] = os.clock() + 0.25 end
            if state.path == "vim" then
                pcall(function() VIM:SendKeyEvent(down, kc, false, game) end)
            else
                local vk = vkFor(kc)
                if vk then pcall(down and keypress or keyrelease, vk) end
            end
        end

        local function keyNote(ch, holdTime)
            local kc = keyCodeFor(unshift(ch))
            if not kc then return end
            if state.echo == nil and not state.expect then
                state.expect, state.expectAt = kc, os.clock()
            end
            if isBlack(ch) then
                local release = hold(kc, function()
                    sendKey(false, kc)
                    sendKey(false, Enum.KeyCode.LeftShift)
                end)
                sendKey(true, Enum.KeyCode.LeftShift)
                sendKey(true, kc)
                state.shifted[kc] = release
                task.delay(0.04, release)
            else
                for _, release in pairs(state.shifted) do release() end
                state.shifted = {}
                local release = hold(kc, function() sendKey(false, kc) end)
                sendKey(true, kc)
                task.delay(holdTime, release)
            end
        end

        local function centreOf(btn)
            local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
            local sg = btn:FindFirstAncestorOfClass("ScreenGui")
            if sg and not sg.IgnoreGuiInset then
                local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
                if ok and inset then c += inset end
            end
            return c
        end

        local function clickNote(ch)
            local colour, label = isBlack(ch) and "black" or "white", unshift(ch)
            local btn = state.map and state.map[colour][label]
            if btn and not btn:IsDescendantOf(game) then
                if resolve(true, false) then
                    Toast("piano changed · " .. (state.map and ("%d keys"):format(state.map.count) or state.reason))
                end
                btn = state.map and state.map[colour][label]
            end
            if not (btn and btn:IsDescendantOf(game)) then return end

            local c = centreOf(btn)
            if frame.Visible then
                local p, s = frame.AbsolutePosition, frame.AbsoluteSize
                if c.X >= p.X and c.X <= p.X + s.X and c.Y >= p.Y and c.Y <= p.Y + s.Y
                    and state.coveredGen ~= state.gen then
                    state.coveredGen = state.gen
                    Toast("panel covers the piano · " .. Config.ToggleKey.Name .. " to hide")
                end
            end
            local release = hold("mouse", function()
                pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, MOUSE_LEFT, false, game, REPEAT) end)
            end)
            pcall(function() VIM:SendMouseMoveEvent(c.X, c.Y, game) end)
            pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, MOUSE_LEFT, true, game, REPEAT) end)
            release()
        end

        UIS.InputBegan:Connect(function(input)
            if state.expect and input.KeyCode == state.expect then
                state.echo, state.expect = true, nil
            end
        end)

        local function describe()
            local found = state.map and (" · %d keys found"):format(state.map.count) or ""
            if state.path == "vim" then return "key events" .. found end
            if state.path == "os" then return "keypresses" .. found end
            if state.path == "click" then return ("clicking %d keys"):format(state.map and state.map.count or 0) end
            return "no play path"
        end

        local function checkEcho()
            if state.path == "click" or state.echo ~= nil or not state.expect then return end
            if os.clock() - state.expectAt < ECHO_WINDOW then return end
            state.echo, state.expect = false, nil
            releaseAll()
            resolve(false, true)
            if state.map then
                state.path = "click"
                warn("[Vanta] key events produced no input; clicking the piano instead")
                Toast("key events got no input · " .. describe())
            else
                warnOnce("noecho", "key events produced no input and no piano buttons were found ("
                    .. tostring(state.reason) .. ")")
            end
        end

        local function normalize(decoded)
            local list = decoded
            if type(list) == "table" and #list == 0 then
                list = decoded.songs or decoded.data or decoded.items or decoded.midis or decoded.results
            end
            local out, seen = {}, {}
            if type(list) ~= "table" then return out end
            for _, e in ipairs(list) do
                if type(e) == "string" then e = { filename = e } end
                if type(e) == "table" then
                    local file = e.filename or e.fileName or e.file or e.path or e.midi
                    if type(file) == "string" and file ~= "" and not seen[file] then
                        seen[file] = true
                        local name = e.name or e.title or e.song or (file:gsub("%.midi?$", ""))
                        table.insert(out, { name = tostring(name),
                            artist = tostring(e.artist or e.author or e.composer or ""), file = file })
                    end
                end
            end
            return out
        end

        local function readCaches()
            local caches = {}
            if not (isfile and readfile) then return caches end
            local ok, data = pcall(function()
                if not isfile(CATALOG_FILE) then return nil end
                return HS:JSONDecode(readfile(CATALOG_FILE))
            end)
            if not ok or type(data) ~= "table" then return caches end
            local raw = (type(data.sources) == "table" and data.sources)
                or (type(data.songs) == "table" and { nanomidi = data }) or {}
            for _, src in ipairs(SOURCES) do
                local c = raw[src.id]
                if type(c) == "table" and type(c.songs) == "table" then
                    local songs = normalize(c.songs)
                    if #songs > 0 then
                        for _, s in ipairs(songs) do s.src = src.id end
                        caches[src.id] = { fetchedAt = tonumber(c.fetchedAt) or 0, songs = songs }
                    end
                end
            end
            return caches
        end

        local function writeCaches()
            if not writefile then return end
            local out = {}
            for id, c in pairs(state.caches) do
                local songs = {}
                for _, s in ipairs(c.songs) do
                    table.insert(songs, { name = s.name, artist = s.artist, file = s.file })
                end
                out[id] = { fetchedAt = c.fetchedAt, songs = songs }
            end
            pcall(writefile, CATALOG_FILE, HS:JSONEncode({ sources = out }))
        end

        local function fetchLive(src)
            if not configured(src) then return nil, src.status .. ": placeholder URL, not set up" end
            if not canRequest then return nil, "this executor has no request()" end
            local ok, res = pcall(request, { Url = src.catalog, Method = "GET" })
            if not ok or type(res) ~= "table" then return nil, src.status .. ": request failed" end
            local code = tonumber(res.StatusCode) or (res.Success and 200) or 0
            if code ~= 200 then return nil, ("%s: HTTP %d"):format(src.status, code) end
            local body = res.Body
            if type(body) ~= "string" or #body < CATALOG_MIN_BODY then
                return nil, ("%s: short response (%d bytes)"):format(src.status,
                    type(body) == "string" and #body or 0)
            end
            local okJson, decoded = pcall(function() return HS:JSONDecode(body) end)
            if not okJson then return nil, src.status .. ": response is not JSON" end
            local songs = normalize(decoded)
            if #songs == 0 then return nil, src.status .. ": no songs in response" end
            for _, s in ipairs(songs) do s.src = src.id end
            return songs
        end

        local function bundled()
            if state.bundled == nil then
                state.bundled = false
                if CATALOG_FALLBACK ~= "" then
                    local ok, decoded = pcall(function() return HS:JSONDecode(CATALOG_FALLBACK) end)
                    if ok then
                        local songs = normalize(decoded)
                        if #songs > 0 then state.bundled = songs end
                    end
                end
            end
            return state.bundled or nil
        end

        -- the disk cache is readable without request(), so don't gate it on canRequest
        local function catalogSongs()
            local c = state.active and state.caches[state.active]
            if c and (state.source == "live" or state.source == "backup" or state.source == "cache") then
                return c.songs
            end
            if state.source == "bundled" then return bundled() or {} end
            return {}
        end

        local function age(seconds)
            if seconds < 60 then return "just now" end
            if seconds < 3600 then return ("%dm"):format(seconds // 60) end
            if seconds < 86400 then return ("%dh"):format(seconds // 3600) end
            return ("%dd"):format(seconds // 86400)
        end

        local function statusLine()
            if state.source == "live" then return "live", T.green end
            local c = state.active and state.caches[state.active]
            if state.source == "backup" and c then
                return "backup · " .. age(os.time() - c.fetchedAt), T.amber
            end
            if state.source == "cache" and c then
                return "cached · " .. age(os.time() - c.fetchedAt), T.dim
            end
            if state.source == "bundled" then return "cached · bundled", T.dim end
            if not canRequest then return "offline · built-in songs only", T.amber end
            return "no catalog loaded", T.dim
        end

        local renderBrowser

        local function updateDesc()
            local s = state.queue[state.song]
            Piano.Desc = ("%s · \\ songs"):format(s and s.name or "no song")
            local r = rows[Piano.Name]
            if r and awaiting ~= Piano then r.DescLbl.Text = descFor(Piano) end
        end

        local function rebuildQueue()
            local current = state.queue[state.song]
            local q = {}
            for _, s in ipairs(catalogSongs()) do table.insert(q, s) end
            for _, s in ipairs(BUILTIN) do table.insert(q, s) end
            state.queue, state.song = q, 1
            if current then
                for i, s in ipairs(q) do
                    if s == current or (current.file and s.file == current.file) then
                        state.song = i
                        break
                    end
                end
            end
            updateDesc()
        end

        local function loadCatalog(force)
            if state.fetching then return false, "already refreshing" end
            state.fetching = true
            if renderBrowser then renderBrowser() end
            if not state.cacheRead then
                state.cacheRead = true
                state.caches = readCaches()
            end
            local function fresh(id)
                local c = state.caches[id]
                return c ~= nil and os.time() - c.fetchedAt < CATALOG_TTL
            end

            local ok, errors = false, {}
            if not force and fresh("primary") then
                state.active, state.source, ok = "primary", "cache", true
            else
                for _, src in ipairs(SOURCES) do
                    if not force and src.id ~= "primary" and fresh(src.id) then
                        state.active, state.source, ok = src.id, "cache", true
                        break
                    end
                    local songs, why = fetchLive(src)
                    if songs then
                        state.caches[src.id] = { fetchedAt = os.time(), songs = songs }
                        writeCaches()
                        state.active, state.source, ok = src.id, src.status, true
                        break
                    end
                    table.insert(errors, why)
                end
            end
            if not ok then
                state.active, state.source = nil, nil
                for _, src in ipairs(SOURCES) do
                    if state.caches[src.id] then
                        state.active, state.source = src.id, "cache"
                        break
                    end
                end
                if not state.source then state.source = bundled() and "bundled" or "offline" end
            end
            state.lastError = #errors > 0 and table.concat(errors, " · ") or nil
            if state.lastError then warn("[Vanta] catalog: " .. state.lastError) end
            state.fetching = false
            rebuildQueue()
            if renderBrowser then renderBrowser() end
            return ok, state.lastError
        end

        local function play(index)
            state.gen += 1
            local my = state.gen
            releaseAll()
            local song = state.queue[index]
            if not song then return end
            state.playing = song
            renderBrowser()

            task.spawn(function()
                local events, err
                if song.file then
                    Toast("loading " .. song.name)
                    events, err = loadMidi(song)
                else
                    events = compileSong(song)
                end
                if state.gen ~= my then return end
                if not events or #events == 0 then
                    Toast(song.name .. ": " .. (err or "nothing to play"))
                    if err then warn("[Vanta] " .. song.name .. ": " .. err) end
                    if Piano.Enabled then toggle(Piano) end
                    return
                end

                local speed = math.max(tonumber(Piano.Speed) or 1, 0.05)
                local due, pressedAny = os.clock(), false
                for _, ev in ipairs(events) do
                    if state.gen ~= my then return end
                    due += ev.dt / speed
                    local wait = due - os.clock()
                    if wait > 0 then task.wait(wait) end
                    if pressedAny and ev.dt < 0.0001 then task.wait(0.012) end
                    if state.gen ~= my then return end
                    checkEcho()
                    if state.path == "click" and not state.map then
                        Toast("no piano found · open one and press P again")
                        if Piano.Enabled then toggle(Piano) end
                        return
                    end
                    if state.path == "click" then
                        clickNote(ev.ch)
                    else
                        keyNote(ev.ch, math.min((song.hold or DEFAULT_HOLD) / speed, 0.5))
                    end
                    pressedAny = true
                end
                if state.gen == my and Piano.Enabled then
                    task.wait(0.1)
                    releaseAll()
                    Toast(song.name .. " finished")
                    toggle(Piano)
                end
            end)
        end

        local BW, BH, ROW_H = 300, 440, 36
        local LIST_TOP = 110
        local B = {}
        B.frame = New("Frame", { Size = px(BW, BH), BackgroundColor3 = T.bg,
            BackgroundTransparency = ALPHA.panel, BorderSizePixel = 0, ClipsDescendants = true,
            Visible = false, ZIndex = 2 }, gui)
        corner(B.frame, 6)
        outline(B.frame, T.line)
        B.scale = New("UIScale", { Scale = uiScale.Scale }, B.frame)
        uiScale:GetPropertyChangedSignal("Scale"):Connect(function() B.scale.Scale = uiScale.Scale end)

        B.header = rect(B.frame, 0, 0, BW, 44, T.bar, ALPHA.header)
        rect(B.header, 0, 43, BW, 1, T.line)
        label(B.header, "Songs", 16, 22, 120, 14, T.text, SANS_SEMI)
        B.close = outlineButton(B.header, "×", BW - 16 - 24, 10, 24, 24, 16, T.dim, T.line)
        B.count = label(B.header, "", 70, 22, BW - 70 - 16 - 24 - 10, 10, T.label, MONO, RIGHT)

        B.status = label(B.frame, "", 16, 58, BW - 32, 10, T.dim, MONO)

        local field = rect(B.frame, 16, 72, BW - 32, 28, T.bar)
        corner(field, 6)
        outline(field, T.lineStrong)
        B.search = New("TextBox", { Size = px(BW - 32, 28), BackgroundTransparency = 1, Text = "",
            PlaceholderText = "/ filter name or artist", PlaceholderColor3 = T.label, TextColor3 = T.text,
            TextSize = 11, FontFace = MONO, TextXAlignment = LEFT, ClearTextOnFocus = false }, field)
        New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, B.search)
        textBoxes[#textBoxes + 1] = B.search

        B.list = New("ScrollingFrame", { Position = px(16, LIST_TOP), Size = px(BW - 32, BH - LIST_TOP - 12),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            ScrollBarImageColor3 = T.lineStrong, ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            VerticalScrollBarInset = Enum.ScrollBarInset.None }, B.frame)
        New("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1),
            PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 1) }, B.list)
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, B.list)

        local pool = {}
        local onRow
        for i = 1, MAX_ROWS + 1 do
            local rw = BW - 34
            local btn = New("TextButton", { Size = px(rw, ROW_H), BackgroundColor3 = T.hover,
                BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                LayoutOrder = i, Visible = false }, B.list)
            corner(btn, 6)
            local entry = { button = btn, stroke = outline(btn, T.line),
                name = label(btn, "", 12, 12, rw - 24, 12, T.text, SANS_SEMI),
                sub = label(btn, "", 12, 26, rw - 24, 10, T.dim, MONO), song = nil }
            btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundTransparency = 0 }) end)
            btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundTransparency = 0.35 }) end)
            btn.MouseButton1Click:Connect(function() onRow(i, entry) end)
            pool[i] = entry
        end

        function renderBrowser()
            if not B.frame.Visible then return end
            local text, colour = statusLine()
            B.status.Text, B.status.TextColor3 = text, colour

            local r = pool[1]
            r.button.Visible = true
            r.name.Text = state.fetching and "refreshing catalog…" or "refresh catalog"
            r.name.TextColor3 = Config.Accent
            r.sub.Text = (state.fetching and "fetching the catalog")
                or (not canRequest and "unavailable: this executor has no request()")
                or (state.source == "backup" and state.lastError and ("primary failed · " .. state.lastError))
                or (state.lastError and ("last fetch failed · " .. state.lastError))
                or "fetch the catalog now"
            r.stroke.Color = accentDeep

            local gated = KEY_GATE and not activated
            local q = B.search.Text:lower()
            local shown, total = 0, 0
            for i, s in ipairs(state.queue) do
                if q == "" or s.name:lower():find(q, 1, true) or s.artist:lower():find(q, 1, true) then
                    total += 1
                    if shown < MAX_ROWS then
                        shown += 1
                        local e = pool[shown + 1]
                        e.song, e.index = s, i
                        e.button.Visible = true
                        local queued, playing = i == state.song, Piano.Enabled and state.playing == s
                        local locked = gated and s.file ~= nil
                        e.name.Text = s.name
                        e.name.TextColor3 = (queued or playing) and Config.Accent or (locked and T.dim or T.text)
                        e.sub.Text = (playing and "playing · " or (queued and "queued · " or ""))
                            .. (locked and "locked" or (s.artist ~= "" and s.artist or (s.file or "")))
                        e.sub.TextColor3 = locked and T.label or T.dim
                        e.stroke.Color = (queued or playing) and accentDeep or T.line
                    end
                end
            end
            if shown == 0 then
                local e = pool[2]
                e.song, e.index = nil, nil
                e.button.Visible = true
                e.name.Text, e.name.TextColor3 = "no matches", T.dim
                e.sub.Text, e.sub.TextColor3 = "clear the filter to see every song", T.dim
                e.stroke.Color = T.line
                shown = 1
            end
            for i = shown + 2, #pool do
                pool[i].button.Visible = false
                pool[i].song, pool[i].index = nil, nil
            end
            B.count.Text = total > MAX_ROWS and ("%d of %d · %d free"):format(MAX_ROWS, total, #BUILTIN)
                or ("%d songs · %d free"):format(total, #BUILTIN)
        end

        Piano.RefreshBrowser = renderBrowser
        function Piano.Ungated()
            local s = state.queue[state.song]
            return s ~= nil and s.file == nil
        end

        function onRow(i, entry)
            if i == 1 then
                if state.fetching then return end
                task.spawn(function()
                    local ok, why = loadCatalog(true)
                    Toast(ok and ("catalog %s · %d songs"):format((statusLine()), #catalogSongs())
                        or ("catalog unavailable · %s · %s"):format(why or "?", (statusLine())))
                end)
                return
            end
            if not entry.index then return end
            if entry.song and entry.song.file and KEY_GATE and not activated then
                Toast("catalog locked · key required")
                clip(URLS.plans)
                return
            end
            state.song = entry.index
            updateDesc()
            if Piano.Enabled then play(state.song) else toggle(Piano) end
            renderBrowser()
        end

        B.search:GetPropertyChangedSignal("Text"):Connect(function()
            B.list.CanvasPosition = Vector2.zero
            renderBrowser()
        end)

        local moved = false
        local function placeBrowser()
            if moved then return end
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
            local s = uiScale.Scale
            local fp, fs = frame.AbsolutePosition, frame.AbsoluteSize
            local x = fp.X + fs.X + 12
            if x + BW * s > vp.X then x = math.max(0, fp.X - BW * s - 12) end
            local y = math.clamp(fp.Y, 0, math.max(0, vp.Y - BH * s))
            B.frame.Position = px(math.floor(x), math.floor(y))
        end

        local function setBrowser(open)
            if open == B.frame.Visible then return end
            if open then
                placeBrowser()
                B.frame.Visible = true
                B.scale.Scale = uiScale.Scale * 0.96
                tween(B.scale, 0.18, { Scale = uiScale.Scale })
                renderBrowser()
                if state.source == nil and not state.fetching then task.spawn(loadCatalog, false) end
            else
                B.frame.Visible = false
                B.search:ReleaseFocus()
            end
        end
        B.close.MouseButton1Click:Connect(function() setBrowser(false) end)

        do
            local dragging, dragStart, startPos
            B.header.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging, dragStart, startPos = true, i.Position, B.frame.Position
                end
            end)
            UIS.InputChanged:Connect(function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local d = i.Position - dragStart
                    moved = true
                    B.frame.Position = px(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
                end
            end)
            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
        end

        UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if awaiting then return end
            if input.KeyCode == SONGS_KEY then
                if typing() then return end
                setBrowser(not B.frame.Visible)
                return
            end
            local step = (input.KeyCode == Enum.KeyCode.RightBracket and 1)
                or (input.KeyCode == Enum.KeyCode.LeftBracket and -1)
            if not step or #state.queue == 0 then return end
            if typing() then return end
            state.song = (state.song - 1 + step) % #state.queue + 1
            updateDesc()
            renderBrowser()
            Toast(("queued %d/%d · %s"):format(state.song, #state.queue, state.queue[state.song].name))
        end)

        function Piano.Start()
            resolve(false, true)
            local keyPath = (VIM and "vim") or ((keypress and keyrelease) and "os") or nil
            if keyPath and state.echo ~= false then
                state.path = keyPath
            elseif state.map then
                state.path = "click"
            elseif keyPath then
                state.path = keyPath
            else
                warn("[Vanta] no way to play: no VirtualInputManager, keypress or piano buttons")
                return false
            end
            local song = state.queue[state.song]
            Toast(("%s · %s"):format(describe(), song and song.name or "no song"))
            Piano:Cleanup(function()
                state.gen += 1
                releaseAll()
                state.playing = nil
                task.defer(renderBrowser)
            end)
            task.defer(play, state.song)
        end

        rebuildQueue()
        task.defer(loadCatalog, false)
    end
    setup()
end

local function makeItemESP(spec)
    local m = Module(spec.name, spec.cat, spec.desc, spec.bind, spec.paid ~= false)
    local marks, nextScan = {}, 0
    local match = spec.match or function(inst)
        local n = inst.Name:lower()
        for _, p in ipairs(spec.patterns or {}) do
            if n:find(p:lower(), 1, true) then return true end
        end
        return false
    end
    local function drop(part)
        local t = marks[part]
        if not t then return end
        for _, d in pairs(t) do pcall(function() d:Remove() end) end
        marks[part] = nil
    end
    function m.Start()
        if not Drawing then return false end
        m:On(RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            local now = os.clock()
            if now >= nextScan then
                nextScan = now + (spec.interval or 0.5)
                local seen, count = {}, 0
                for _, rootName in ipairs(spec.roots or { "workspace" }) do
                    local root = rootName == "workspace" and workspace or workspace:FindFirstChild(rootName)
                    if root then
                        for _, d in ipairs(root:GetDescendants()) do
                            if count > (spec.cap or 400) then break end
                            if d:IsA("BasePart") and match(d) then
                                count += 1
                                seen[d] = true
                                if not marks[d] then
                                    marks[d] = {
                                        box = espDraw("Square", { Thickness = 1, Filled = false,
                                            Color = spec.color or WHITE }),
                                        text = espDraw("Text", { Size = 10, Center = true,
                                            Outline = true, Color = spec.color or WHITE }),
                                    }
                                end
                            end
                        end
                    end
                end
                for part in pairs(marks) do
                    if not seen[part] then drop(part) end
                end
            end
            for part, t in pairs(marks) do
                if not part:IsDescendantOf(game) then
                    drop(part)
                else
                    local p, on = cam:WorldToViewportPoint(part.Position)
                    if on then
                        t.box.Visible, t.text.Visible = true, true
                        t.box.Size, t.box.Position = Vector2.new(14, 14), Vector2.new(p.X - 7, p.Y - 7)
                        t.text.Text = spec.label and spec.label(part)
                            or ("%dm"):format((cam.CFrame.Position - part.Position).Magnitude)
                        t.text.Position = Vector2.new(p.X, p.Y + 10)
                    else
                        t.box.Visible, t.text.Visible = false, false
                    end
                end
            end
        end))
        m:Cleanup(function() for p in pairs(marks) do drop(p) end end)
    end
    return m
end

local PACKS = {
    [142823291] = "mm2.lua",
    [73814454293317] = "ugc.lua",
}
local PACK_BASE = "https://raw.githubusercontent.com/pixel-pinecone/vanta-data/main/packs/"

local function renderBadge(m)
    local r = rows[m.Name]
    if not r then return end
    local b, s = r.Badge, r.BadgeStroke
    if awaiting == m then
        b.Text = "…"
        r.DescLbl.Text = "press a key · esc to cancel"
        tween(b, 0.14, { TextColor3 = Config.Accent })
        tween(s, 0.14, { Color = Config.Accent })
    else
        r.DescLbl.Text = descFor(m)
        if m.Bind then
            b.Text = m.Bind.Name
            tween(b, 0.14, { TextColor3 = T.badgeText })
            tween(s, 0.14, { Color = T.badgeLine })
        else
            b.Text = "+"
            tween(b, 0.14, { TextColor3 = accentMuted })
            tween(s, 0.14, { Color = accentDeep })
        end
    end
end

local bindCatcher
local function destroyCatcher()
    if bindCatcher then bindCatcher:Destroy() end
    bindCatcher = nil
end

local function cancelBind()
    if not awaiting then return end
    local m = awaiting
    awaiting = nil
    destroyCatcher()
    renderBadge(m)
end

local function makeCatcher()
    destroyCatcher()
    bindCatcher = New("TextButton", { Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        ZIndex = 50, Parent = gui })
    bindCatcher.MouseButton1Click:Connect(cancelBind)
    bindCatcher.MouseButton2Click:Connect(cancelBind)
end

local function beginBind(m)
    if awaiting and awaiting ~= m then cancelBind() end
    awaiting = m
    renderBadge(m)
    makeCatcher()
end

local function claimKey(newOwner, key)
    for _, o in ipairs(Config.Order) do
        if o ~= newOwner and o.Bind == key then
            o.Bind = nil
            renderBadge(o)
            Toast(o.Name .. " unbound")
        end
    end
end

local function applyBind(m, key)
    awaiting = nil
    destroyCatcher()
    if key == Config.ToggleKey then
        Toast(key.Name .. " is reserved")
        renderBadge(m)
        return
    end
    claimKey(m, key)
    m.Bind = key
    renderBadge(m)
    Toast(m.Name .. " → " .. key.Name)
    save()
end

local function resetBind(m)
    if awaiting then cancelBind() end
    local def = rows[m.Name].Default
    if m.Bind == def then
        Toast(m.Name .. " already default")
        renderBadge(m)
        return
    end
    if def then claimKey(m, def) end
    m.Bind = def
    renderBadge(m)
    Toast(m.Name .. (def and (" → " .. def.Name .. " (default)") or " bind cleared"))
    save()
end

do -- load the pack for this place, if any. Bounded so a dead network can't stall boot.
    local file = PACKS[game.PlaceId]
    if file and request then
        local env = setmetatable({
            Module = Module, makeItemESP = makeItemESP, espDraw = espDraw,
            LP = LP, Players = Players, RunService = RunService, workspace = workspace,
            Color3 = Color3, Vector3 = Vector3, Drawing = Drawing, Toast = Toast,
            UIS = UIS, Lighting = Lighting, HS = HS, Teleport = Teleport,
            VirtualUser = VirtualUser, Stats = Stats, hum = hum, setVisual = setVisual,
            clip = clip, frame = frame, gui = gui,
        }, { __index = getfenv() })
        local done, body, why = false, nil, nil
        task.spawn(function()
            local ok, res = pcall(request, { Url = PACK_BASE .. file, Method = "GET" })
            if ok and type(res) == "table" then
                if res.StatusCode == 200 then body = res.Body
                else why = "HTTP " .. tostring(res.StatusCode) end
            else
                why = tostring(res)
            end
            done = true
        end)
        local deadline = os.clock() + 2
        while not done and os.clock() < deadline do task.wait(0.05) end
        if type(body) == "string" then
            local fn, err = loadstring(body, "=vanta.pack")
            if fn then
                setfenv(fn, env)
                local ok2, err2 = pcall(fn)
                if not ok2 then warn("[Vanta] pack error: " .. tostring(err2)) end
            else
                warn("[Vanta] pack syntax: " .. tostring(err))
            end
        else
            warn("[Vanta] pack " .. file .. " unavailable · " .. tostring(why))
        end
    end
end

-- wrapper AFTER the pack, so pack modules get state tracking too
for _, m in ipairs(Config.Order) do
    local run = m.Start
    m.Start = function()
        if run() == false then return false end
        m.Enabled = true
    end
end

local ROW_W, ROW_H, ROW_GAP = COL_W - 2, 40, 6
for i, m in ipairs(Config.Order) do
    local row = New("TextButton", { Size = px(ROW_W, ROW_H), BackgroundColor3 = T.hover,
        BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        LayoutOrder = i, Parent = content })
    corner(row, 6)
    local rowStroke = outline(row, T.line)
    ripple(row, Config.Accent)
    local focusRing = New("Frame", { Position = px(1, 1), Size = px(ROW_W - 2, ROW_H - 2),
        BackgroundTransparency = 1 }, row)
    corner(focusRing, 5)
    local focusStroke = outline(focusRing, Config.Accent, 1)

    local bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = px(2, 0), BackgroundColor3 = Config.Accent, BorderSizePixel = 0 }, row)
    local nameLbl = label(row, m.Name, 16, 13, 360, 14, T.text, SANS_SEMI)
    local descLbl = label(row, descFor(m), 16, 27, 400, 12, T.dim)

    local switch = rect(row, ROW_W - 14 - 34, 11, 34, 18, T.chip)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, switch)
    local switchStroke = outline(switch, T.lineStrong)
    local knob = rect(switch, 3, 3, 12, 12, T.dim)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local badge = New("TextButton", { Position = px(ROW_W - 14 - 34 - 12 - 52, 9), Size = px(52, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        TextColor3 = T.badgeText, TextSize = 10, FontFace = MONO,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
    corner(badge, 5)
    local badgeStroke = outline(badge, T.badgeLine)

    row.MouseEnter:Connect(function()
        if not m.Enabled then tween(row, 0.12, { BackgroundTransparency = 0 }) end
    end)
    row.MouseLeave:Connect(function()
        if not m.Enabled then tween(row, 0.12, { BackgroundTransparency = 0.35 }) end
    end)
    row.MouseButton1Click:Connect(function() toggle(m) end)
    badge.MouseButton1Click:Connect(function() beginBind(m) end)
    badge.MouseButton2Click:Connect(function() resetBind(m) end)
    badge.MouseEnter:Connect(function()
        if awaiting ~= m then descLbl.Text = "click: rebind · right-click: default" end
    end)
    badge.MouseLeave:Connect(function()
        if awaiting ~= m then descLbl.Text = descFor(m) end
    end)

    rows[m.Name] = { Row = row, Stroke = rowStroke, NameLbl = nameLbl, DescLbl = descLbl,
        Badge = badge, BadgeStroke = badgeStroke, FocusStroke = focusStroke,
        Bar = bar, Switch = switch, SwitchStroke = switchStroke, Knob = knob,
        Category = m.Category, Default = m.Bind }
    m.Badge = badge
    renderBadge(m)
end

content.CanvasPosition = Vector2.zero

do
    local needed = #Config.Order * (ROW_H + ROW_GAP) - ROW_GAP + 2
    local overflow = needed > LIST_H
    content.ScrollingEnabled = overflow
    content.ScrollBarThickness = overflow and 2 or 0
end

local cats = {}
for _, m in ipairs(Config.Order) do
    if not table.find(cats, m.Category) then table.insert(cats, m.Category) end
end
activeCat = cats[1]

local catButtons = {}
local function paintCats()
    for c, cb in pairs(catButtons) do
        local sel = c == activeCat
        tween(cb.Button, 0.12, { TextColor3 = sel and Config.Accent or T.dim })
        tween(cb.Stroke, 0.12, { Color = sel and Config.Accent or T.line })
    end
end

do
    local widths, total = {}, 0
    for i, c in ipairs(cats) do
        widths[i] = #c * 7 + 22
        total += widths[i] + (i > 1 and 6 or 0)
    end
    local x = 310 - total
    for i, c in ipairs(cats) do
        local b, s = outlineButton(catBar, c:upper(), x, 0, widths[i], 24, 10, T.dim, T.line, MONO)
        b.BackgroundColor3 = Config.Accent
        catButtons[c] = { Button = b, Stroke = s }
        b.MouseButton1Click:Connect(function()
            activeCat = c
            paintCats()
            refresh()
        end)
        x += widths[i] + 6
    end
    paintCats()
end

local function applyFocusVisual(m, on)
    local r = rows[m.Name]
    if not r then return end
    tween(r.FocusStroke, 0.12, { Transparency = on and 0 or 1 })
end

local function visibleModules()
    local list = {}
    for _, m in ipairs(Config.Order) do
        local r = rows[m.Name]
        if r and r.Row.Visible then table.insert(list, m) end
    end
    return list
end

local function setFocus(m)
    if focusedModule == m then return end
    if focusedModule then applyFocusVisual(focusedModule, false) end
    focusedModule = m
    if not m then return end
    applyFocusVisual(m, true)
    if not content.ScrollingEnabled then return end
    local k = uiScale.Scale
    local r = rows[m.Name].Row
    local y = (r.AbsolutePosition.Y - content.AbsolutePosition.Y) / k + content.CanvasPosition.Y
    local viewTop, viewBottom = content.CanvasPosition.Y, content.CanvasPosition.Y + LIST_H
    if y < viewTop then
        content.CanvasPosition = Vector2.new(0, math.max(0, y - 1))
    elseif y + ROW_H > viewBottom then
        content.CanvasPosition = Vector2.new(0, y + ROW_H + 1 - LIST_H)
    end
end

local function moveFocus(dir)
    local list = visibleModules()
    if #list == 0 then setFocus(nil) return end
    local idx = dir > 0 and 1 or #list
    if focusedModule then
        local cur = table.find(list, focusedModule)
        if cur then idx = math.clamp(cur + dir, 1, #list) end
    end
    setFocus(list[idx])
end

-- keep the frame inside the viewport using its *current* size, not the expanded one
local function clampFrame()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local s = uiScale.Scale
    local w = (minimized and MINI_W or PANEL_W) * s
    local h = (minimized and COLLAPSED_H or PANEL_H) * s
    local p = frame.Position
    frame.Position = px(math.clamp(p.X.Offset, 0, math.max(0, vp.X - w)),
        math.clamp(p.Y.Offset, 0, math.max(0, vp.Y - h)))
end

local function setMinimized(min, animate)
    minimized = min
    local time = animate and 0.22 or 0
    if min then
        if focusedModule then applyFocusVisual(focusedModule, false); focusedModule = nil end
        body.Visible = false
        miniBar.Visible = true
        tween(frame, time, { Size = px(MINI_W, COLLAPSED_H) })
    else
        miniBar.Visible = false
        body.Visible = true
        tween(frame, time, { Size = px(PANEL_W, PANEL_H) })
    end
    clampFrame()
end

local function ValidateKey(key) -- STUB: swap in the real check
    key = (key or ""):gsub("%s", "")
    if #key == 0 then return false, "enter a key" end
    if not key:upper():match("^VANTA%-%w%w%w%w%-%w%w%w%w$") then return false, "invalid key" end
    return true
end

local function refreshDescs()
    for _, m in ipairs(Config.Order) do
        local r = rows[m.Name]
        if r and awaiting ~= m then r.DescLbl.Text = descFor(m) end
    end
end

local function setActivated(on, animate)
    activated = on
    tween(listVeil, animate and 0.3 or 0, { BackgroundTransparency = on and 1 or ALPHA.veil })
    activateLbl.Text = on and "Active" or "Activate"
    keyBox.TextEditable = not on
    tween(keyStroke, 0.15, { Color = on and accentEdge or T.lineStrong })
    refreshDescs()
    if Piano.RefreshBrowser then Piano.RefreshBrowser() end
end

local function tryActivate()
    if activated then return end
    local ok, why = ValidateKey(keyBox.Text)
    if ok then
        setActivated(true, true)
        Toast("key accepted · esp, fly and the full catalog unlocked")
        save()
    else
        Toast(why or "invalid key")
        tween(keyStroke, 0.1, { Color = T.amber })
        task.delay(0.6, function()
            if not activated then tween(keyStroke, 0.25, { Color = T.lineStrong }) end
        end)
    end
end

function refresh()
    local q = search.Text:lower()
    local n = 0
    for _, m in pairs(rows) do
        m.Row.Visible = (activeCat == nil or m.Category == activeCat)
            and (q == "" or m.Row.Parent ~= nil and m.NameLbl.Text:lower():find(q, 1, true) ~= nil)
        if m.Row.Visible then n += 1 end
    end
    countLbl.Text = ("%d %s"):format(n, n == 1 and "MODULE" or "MODULES")
    content.CanvasPosition = Vector2.zero
    if focusedModule and not rows[focusedModule.Name].Row.Visible then
        applyFocusVisual(focusedModule, false)
        focusedModule = nil
    end
end

function setVisual(m)
    local r = rows[m.Name]
    if not r then return end
    local on = m.Enabled
    tween(r.Row, 0.18, { BackgroundColor3 = on and Config.Accent or T.hover,
        BackgroundTransparency = on and 0.86 or 0.35 })
    tween(r.Stroke, 0.18, { Color = on and accentEdge or T.line })
    tween(r.NameLbl, 0.18, { TextColor3 = on and WHITE or T.text })
    tween(r.Bar, 0.22, { Size = px(2, on and 22 or 0) })
    tween(r.Switch, 0.18, { BackgroundColor3 = on and Config.Accent or T.chip })
    tween(r.SwitchStroke, 0.18, { Color = on and Config.Accent or T.lineStrong })
    tween(r.Knob, 0.18, { BackgroundColor3 = on and WHITE or T.dim })
    tween(r.Knob, 0.28, { Position = px(on and 19 or 3, 3) }, Style.Back)
end

function toggle(m)
    if m.Enabled then
        m:Stop()
    else
        if KEY_GATE and not activated and not (m.Ungated and m.Ungated()) then
            Toast(m.Paid and "paid module · activate a key first" or "activate a key first")
            return
        end
        local ok, res = pcall(m.Start)
        if not ok then Toast("error: " .. tostring(res):sub(1, 40)) return end
        if res == false then Toast(m.Name .. " unavailable here") return end
    end
    setVisual(m)
    Toast(m.Name .. (m.Enabled and " on" or " off"))
    save()
end

local FILE = "vanta_config.json"
local queued = false
function save()
    if queued then return end
    queued = true
    task.delay(0.5, function()
        queued = false
        if not writefile then return end
        local data = { binds = {}, enabled = {}, minimized = minimized,
            key = activated and keyBox.Text or nil }
        for _, m in ipairs(Config.Order) do
            if m.Bind then data.binds[m.Name] = m.Bind.Name end
            if not m.Momentary then data.enabled[m.Name] = m.Enabled end
        end
        pcall(writefile, FILE, HS:JSONEncode(data))
    end)
end

search:GetPropertyChangedSignal("Text"):Connect(refresh)
search.Focused:Connect(function() tween(searchLine, 0.15, { BackgroundColor3 = Config.Accent }) end)
search.FocusLost:Connect(function() tween(searchLine, 0.15, { BackgroundColor3 = T.line }) end)
refresh()

task.spawn(function()
    if not (isfile and isfile(FILE)) then return end
    local ok, data = pcall(function() return HS:JSONDecode(readfile(FILE)) end)
    if not ok or type(data) ~= "table" then return end
    for _, m in ipairs(Config.Order) do
        local def = rows[m.Name] and rows[m.Name].Default
        local saved = data.binds and data.binds[m.Name]
        if def ~= nil and type(saved) == "string" then
            local found, key = pcall(function() return Enum.KeyCode[saved] end)
            if found and key then
                m.Bind = key
                renderBadge(m)
            end
        end
    end
    if type(data.key) == "string" and ValidateKey(data.key) then
        keyBox.Text = data.key
        setActivated(true, false)
    end
    if type(data.minimized) == "boolean" then setMinimized(data.minimized, false) end
    task.wait(1)
    for _, m in ipairs(Config.Order) do
        if not m.Momentary and data.enabled and data.enabled[m.Name] and (activated or not m.Paid) then
            local ok2, res = pcall(m.Start)
            if ok2 and res ~= false then setVisual(m) end
        end
    end
end)

local sessionStart = os.clock()
task.spawn(function()
    while gui.Parent do
        local s = math.floor(os.clock() - sessionStart)
        local text = ("%02d:%02d:%02d"):format(s // 3600, s // 60 % 60, s % 60)
        timerVal.Text, miniTimer.Text = text, text
        task.wait(1)
    end
end)

task.spawn(function()
    while gui.Parent do
        local t0 = os.clock()
        local ok = pcall(function() return game:HttpGet("https://www.roblox.com/robots.txt") end)
        local ms = ok and (os.clock() - t0) * 1000
        if not ms then
            local ok2, p = pcall(function() return LP:GetNetworkPing() end)
            ms = ok2 and p and p * 1000
            ok = ms ~= nil
        end
        pingVal.Text = ms and ("%d ms"):format(math.floor(ms + 0.5)) or "-- ms"
        statusVal.Text = ok and "Connected" or "Offline"
        local c = ok and T.green or T.amber
        statusDot.BackgroundColor3, miniDot.BackgroundColor3 = c, c
        task.wait(5)
    end
end)

activateBtn.MouseEnter:Connect(function()
    tween(activateBtn, 0.12, { BackgroundColor3 = Config.Accent:Lerp(WHITE, 0.12) })
end)
activateBtn.MouseLeave:Connect(function() tween(activateBtn, 0.12, { BackgroundColor3 = Config.Accent }) end)
activateBtn.MouseButton1Click:Connect(tryActivate)
keyBox.Focused:Connect(function()
    if not activated then tween(keyStroke, 0.15, { Color = Config.Accent }) end
end)
keyBox.FocusLost:Connect(function(enter)
    if not activated then tween(keyStroke, 0.15, { Color = T.lineStrong }) end
    if enter then tryActivate() end
end)

getKeyBtn.MouseEnter:Connect(function() tween(getKeyBtn, 0.12, { TextColor3 = accentHot }) end)
getKeyBtn.MouseLeave:Connect(function() tween(getKeyBtn, 0.12, { TextColor3 = Config.Accent }) end)
getKeyBtn.MouseButton1Click:Connect(function()
    Toast(clip(URLS.getKey) and "key link copied" or URLS.getKey)
end)

discordBtn.MouseButton1Click:Connect(function()
    Toast(clip(URLS.discord) and "discord invite copied" or URLS.discord)
end)
hwidBtn.MouseButton1Click:Connect(function()
    Toast(clip(HWID) and "hwid copied" or "clipboard unavailable")
end)
settingsBtn.MouseButton1Click:Connect(function()
    Toast("settings: coming soon")
end)
plansBtn.MouseButton1Click:Connect(function()
    Toast(clip(URLS.plans) and "plans link copied" or URLS.plans)
end)

UIS.InputBegan:Connect(function(input, gp)
    -- drop expired synthetic markers so a stale one can't eat a real press
    local now = os.clock()
    for kc, expiry in pairs(Config.Synthetic) do
        if expiry < now then Config.Synthetic[kc] = nil end
    end
    if Config.Synthetic[input.KeyCode] then
        Config.Synthetic[input.KeyCode] = nil
        return
    end
    if awaiting then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelBind()
            else
                applyBind(awaiting, input.KeyCode)
            end
        end
        return
    end
    if gp then return end
    if input.KeyCode == Config.ToggleKey then
        if not frame.Visible then applyViewportScale() end
        frame.Visible = not frame.Visible
        return
    end
    if typing() then return end
    if frame.Visible and not minimized then
        if input.KeyCode == Enum.KeyCode.Down then moveFocus(1) return end
        if input.KeyCode == Enum.KeyCode.Up then moveFocus(-1) return end
        if (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter)
            and focusedModule then
            toggle(focusedModule)
            return
        end
    end
    for _, m in ipairs(Config.Order) do
        if m.Bind == input.KeyCode then toggle(m) end
    end
end)

local MARGIN_X, MARGIN_Y = 40, 70
local userMoved = false

local function applyViewportScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local s = math.max(0.1, math.min(1, (vp.X - 2 * MARGIN_X) / PANEL_W, (vp.Y - 2 * MARGIN_Y) / PANEL_H))
    uiScale.Scale = s
    if userMoved then
        clampFrame()
        return
    end
    local w = (minimized and MINI_W or PANEL_W) * s
    local h = (minimized and COLLAPSED_H or PANEL_H) * s
    frame.Position = px(math.floor((vp.X - w) / 2), math.floor((vp.Y - h) / 2))
end

local viewportConn
local function watchCamera()
    if viewportConn then viewportConn:Disconnect() end
    local cam = workspace.CurrentCamera
    if cam then
        viewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyViewportScale)
    end
    applyViewportScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

local sidebarGrip = New("Frame", { Size = px(SIDEBAR_W, 86), BackgroundTransparency = 1 }, body)
local dragging, dragStart, startPos
local function beginDrag(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, frame.Position
    end
end
header.InputBegan:Connect(beginDrag)
sidebarGrip.InputBegan:Connect(beginDrag)
miniBar.InputBegan:Connect(beginDrag)
UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        userMoved = true
        frame.Position = px(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

closeBtn.MouseButton1Click:Connect(function() frame.Visible = false end)
miniCloseBtn.MouseButton1Click:Connect(function() frame.Visible = false end)
local function flipMinimized()
    setMinimized(not minimized, true)
    save()
end
minBtn.MouseButton1Click:Connect(flipMinimized)
expandBtn.MouseButton1Click:Connect(flipMinimized)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    for _, m in ipairs(Config.Order) do
        if m.Enabled and not m.Momentary then
            m:Stop()
            task.wait()
            pcall(m.Start)
            setVisual(m)
        end
    end
end)

do
    local STEP = 0.45
    local DIM  = 0.4
    local BLUR = 14
    local GLOW = 0.06

    local function fadeHalo(list, time, on)
        for _, h in ipairs(list) do tween(h[1], time, { Transparency = on and h[2] or 1 }) end
    end

    local function glint(lbl, period)
        local tint = Config.Accent:Lerp(WHITE, 0.15)
        local g = New("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.4, WHITE),
            ColorSequenceKeypoint.new(0.5, tint), ColorSequenceKeypoint.new(0.6, WHITE),
            ColorSequenceKeypoint.new(1, WHITE) }), Rotation = 20,
            Offset = Vector2.new(-1, 0) }, lbl)
        task.spawn(function()
            while lbl.Parent do
                g.Offset = Vector2.new(-1, 0)
                tween(g, 1.1, { Offset = Vector2.new(1, 0) }, Style.Sine, Dir.InOut)
                task.wait(period)
            end
        end)
    end

    local function polishPanel()
        local glow = New("Frame", { BackgroundTransparency = 1, ZIndex = 0, Visible = false }, gui)
        local shadow = New("Frame", { Position = px(0, 6), Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, ZIndex = 0 }, glow)
        halo(shadow, Color3.new(0, 0, 0), 12, 0.045, 6, 2)
        halo(glow, Config.Accent, 8, 0.03, 6, 1.5)
        local function sync()
            glow.Visible = frame.Visible
            glow.Position = frame.Position
            glow.Size = px(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
        end
        for _, prop in ipairs({ "Visible", "Position", "AbsoluteSize" }) do
            frame:GetPropertyChangedSignal(prop):Connect(sync)
        end
        sync()

        local hair = rect(body, 0, 0, PANEL_W, 1, WHITE)
        hair.ZIndex = 5
        local hairGrad = gradient(hair, Config.Accent, ns(0, 1, 0.5, 0, 1, 1))
        hairGrad.Offset = Vector2.new(-0.6, 0)
        tween(hairGrad, 4, { Offset = Vector2.new(0.6, 0) }, Style.Sine, Dir.InOut, -1, true)

        wash(header, 0, 0, 280, HEADER_H - 1, Config.Accent, 0.9, 1, 0)
        wash(sidebar, 2, 256, 90, 104, Config.Accent, 0.88, 1, 0)
        corner(wash(card, 0, 0, COL_W, CARD_H, Config.Accent, 0.9, 1, 0), 6)

        local cardStroke = card:FindFirstChildOfClass("UIStroke")
        if cardStroke then
            cardStroke.Color = WHITE
            tween(gradient(cardStroke, band(accentEdge, Config.Accent)), 6, { Rotation = 360 },
                Style.Linear, Dir.InOut, -1)
        end

        local function pulse(dot)
            local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), Size = px(6, 6),
                BackgroundColor3 = dot.BackgroundColor3, BackgroundTransparency = 0.4,
                BorderSizePixel = 0 }, dot)
            New("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
            dot:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
                ring.BackgroundColor3 = dot.BackgroundColor3
            end)
            tween(ring, 1.8, { Size = px(18, 18), BackgroundTransparency = 1 }, Style.Quad, Dir.Out, -1)
        end
        pulse(statusDot)
        pulse(miniDot)

        tween(verified, 1.8, { BackgroundTransparency = 0.86 }, Style.Sine, Dir.InOut, -1, true)
        glint(wordmark, 5)

        gradient(activateBtn, ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 228)), nil, 90)
        local sheen = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BorderSizePixel = 0, ZIndex = 0 }, activateBtn)
        corner(sheen, 6)
        local sheenGrad = gradient(sheen, WHITE, ns(0, 1, 0.38, 1, 0.5, 0.68, 0.62, 1, 1, 1), 20)
        sheenGrad.Offset = Vector2.new(-1, 0)
        task.spawn(function()
            while gui.Parent do
                task.wait(3.5)
                if not activated and frame.Visible then
                    sheenGrad.Offset = Vector2.new(-1, 0)
                    tween(sheenGrad, 0.9, { Offset = Vector2.new(1, 0) }, Style.Sine, Dir.InOut)
                end
            end
        end)

        local GW, GH, SPAN = PANEL_W - SIDEBAR_W, PANEL_H - HEADER_H, 240
        local vline = rect(grid, 0, 0, 1, SPAN, WHITE)
        gradient(vline, Config.Accent, ns(0, 1, 0.5, 0.35, 1, 1), 90)
        local hline = rect(grid, 0, 0, SPAN, 1, WHITE)
        gradient(hline, Config.Accent, ns(0, 1, 0.5, 0.35, 1, 1), 0)
        vline.Visible, hline.Visible = false, false
        local function snap(v, max)
            local n = math.max(1, math.floor((v + 1) / 32 + 0.5))
            while n > 1 and n * 32 - 1 > max - 1 do n -= 1 end
            return n * 32 - 1
        end
        UIS.InputChanged:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            if not frame.Visible or minimized then
                vline.Visible, hline.Visible = false, false
                return
            end
            local k = uiScale.Scale
            local m = UIS:GetMouseLocation()
            local x = (m.X - grid.AbsolutePosition.X) / k
            local y = (m.Y - grid.AbsolutePosition.Y) / k
            local inside = x >= 0 and x <= GW and y >= 0 and y <= GH
            vline.Visible, hline.Visible = inside, inside
            if not inside then return end
            vline.Position = px(snap(x, GW), math.floor(y - SPAN / 2))
            hline.Position = px(math.floor(x - SPAN / 2), snap(y, GH))
        end)
    end

    local function revealPanel()
        applyViewportScale()
        local target, home = uiScale.Scale, frame.Position
        local w = minimized and MINI_W or PANEL_W
        local h = minimized and COLLAPSED_H or PANEL_H
        frame.Visible = true
        uiScale.Scale = target * 0.94
        frame.Position = home + px(w * target * 0.03, h * target * 0.03)
        tween(frame, 0.45, { Position = home }, Style.Back)
        tween(uiScale, 0.45, { Scale = target }, Style.Back).Completed:Connect(applyViewportScale)

        local function cascade(x, w, ys, t0)
            for i = 1, #ys - 1 do
                local c = rect(body, x, ys[i], w, ys[i + 1] - ys[i], T.bg)
                c.ZIndex = 8
                task.delay(t0 + (i - 1) * 0.07, function()
                    tween(c, 0.4, { BackgroundTransparency = 1 }).Completed:Connect(function()
                        c:Destroy()
                    end)
                end)
            end
        end
        cascade(0, SIDEBAR_W, { 0, 86, 244, 372, PANEL_H }, 0.05)
        cascade(SIDEBAR_W, PANEL_W - SIDEBAR_W, { 0, HEADER_H, 124, 214, 306, 466, PANEL_H }, 0.12)

        local sweep = wash(body, 0, -80, PANEL_W, 80, Config.Accent, 1, 0.8, 90)
        sweep.ZIndex = 9
        tween(sweep, 0.8, { Position = px(0, PANEL_H) }, Style.Sine)
            .Completed:Connect(function() sweep:Destroy() end)

        Toast(("%s v%s — %d modules"):format(Config.Name, Config.Version, #Config.Order))
    end

    local function runLoader(onDone)
        local W, H, PAD = 420, 316, 32
        local TRACK = W - PAD * 2
        local CY = 76

        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local k = math.max(0.4, math.min(1, (vp.X - 32) / W, (vp.Y - 32) / H))

        local blur
        if BLUR > 0 then
            pcall(function()
                blur = New("BlurEffect", { Name = Config.Name .. "Blur", Size = 0 }, Lighting)
            end)
        end

        local root = New("Frame", { Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ZIndex = 30 }, gui)
        local stage = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = px(W, H),
            BackgroundTransparency = 1 }, root)
        local scale = New("UIScale", { Scale = k * 0.9 }, stage)

        local glow = halo(stage, Config.Accent, 12, GLOW, 8, 1.5)
        for _, h in ipairs(glow) do h[1].Transparency = 1 end

        local plate = New("CanvasGroup", { Size = px(W, H), BackgroundColor3 = T.bg,
            BorderSizePixel = 0, GroupTransparency = 1 }, stage)
        corner(plate, 8)
        local edge = New("UIStroke", { Color = WHITE, Thickness = 1, Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
        local spin = tween(gradient(edge, band(T.lineStrong, Config.Accent)), 3,
            { Rotation = 360 }, Style.Linear, Dir.InOut, -1)

        for gx = 31, W - 1, 32 do rect(plate, gx, 0, 1, H, T.grid, ALPHA.grid) end
        for gy = 31, H - 1, 32 do rect(plate, 0, gy, W, 1, T.grid, ALPHA.grid) end
        wash(plate, 0, 0, W, 160, Config.Accent, 0.84, 1, 90)

        local alive = true
        for i = 1, 14 do
            task.spawn(function()
                local rng = Random.new(i * 97)
                task.wait(rng:NextNumber(0, 1.4))
                while alive do
                    local x, y = rng:NextInteger(12, W - 12), rng:NextInteger(50, H - 16)
                    local sz = rng:NextInteger(1, 2)
                    local p = rect(plate, x, y, sz, sz,
                        Config.Accent:Lerp(WHITE, rng:NextNumber(0, 0.5)), 1)
                    p.ZIndex = 0
                    local t = rng:NextNumber(1.6, 3.2)
                    tween(p, t * 0.3, { BackgroundTransparency = rng:NextNumber(0.3, 0.65) })
                    tween(p, t, { Position = px(x + rng:NextInteger(-10, 10),
                        y - rng:NextInteger(30, 70)) }, Style.Linear)
                    task.wait(t * 0.7)
                    tween(p, t * 0.3, { BackgroundTransparency = 1 })
                    task.wait(t * 0.3)
                    p:Destroy()
                end
            end)
        end

        local function orbit(d, period, dir, thickness, peak)
            local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(W / 2, CY),
                Size = px(d, d), BackgroundTransparency = 1 }, plate)
            New("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
            local s = New("UIStroke", { Color = WHITE, Thickness = thickness,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
            tween(gradient(s, Config.Accent, ns(0, 1, 0.5, 1, 1, peak)), period,
                { Rotation = 360 * dir }, Style.Linear, Dir.InOut, -1)
        end
        orbit(92, 1.6, 1, 1.5, 0)
        orbit(110, 2.6, -1, 1, 0.45)

        local LOGO = 52
        local mark = logo(plate, (W - LOGO) / 2, CY - LOGO / 2 + 2, LOGO)
        if mark:IsA("ImageLabel") then
            mark.ImageTransparency = 1
            tween(mark, 0.6, { ImageTransparency = 0 })
        else
            for _, seg in ipairs(mark:GetChildren()) do
                seg.BackgroundTransparency = 1
                seg.BackgroundColor3 = WHITE
                task.delay(0.15 + seg.Position.Y.Offset / LOGO * 0.5, function()
                    tween(seg, 0.35, { BackgroundTransparency = 0, BackgroundColor3 = Config.Accent })
                end)
            end
        end

        local function rise(o, delay)
            local home = o.Position
            o.Position, o.TextTransparency = home + px(0, 8), 1
            task.delay(delay, function()
                tween(o, 0.35, { Position = home, TextTransparency = 0 })
            end)
            return o
        end
        glint(rise(label(plate, Config.Name, 0, 150, W, 24, T.text, SANS_SEMI, CENTER), 0.35), 2.2)
        rise(label(plate, "Your session, under control.", 0, 174, W, 12, T.dim, SANS, CENTER), 0.5)

        local steps = {
            { "Identifying executor", EXECUTOR },
            { "Linking device", HWID_OK and "HWID linked" or "session only" },
            { "Resolving game", listedName or "not listed" },
            { "Mounting modules", ("%d ready"):format(#Config.Order) },
        }
        local lines = {}
        for i, step in ipairs(steps) do
            local cy = 182 + i * 20
            local pip = rect(plate, PAD, cy - 3 - LIFT, 6, 6, Config.Accent, 1)
            corner(pip, 3)
            local name = label(plate, step[1], PAD + 16, cy, 220, 12, T.text)
            name.TextTransparency = 1
            local val = label(plate, step[2], W - PAD - 150, cy, 150, 11, T.dim, MONO, RIGHT)
            val.TextTransparency = 1
            lines[i] = { pip = pip, name = name, val = val }
        end

        local track = rect(plate, PAD, 280, TRACK, 4, T.line)
        track.ClipsDescendants = true
        corner(track, 2)
        local fill = rect(track, 0, 0, 0, 4, WHITE)
        corner(fill, 2)
        gradient(fill, ColorSequence.new(accentDeep, Config.Accent:Lerp(WHITE, 0.25)))
        local spark = New("Frame", { AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0), Size = px(16, 4),
            BackgroundColor3 = WHITE, BorderSizePixel = 0 }, fill)
        gradient(spark, WHITE, ns(0, 1, 1, 0.1))

        label(plate, ("v%s / STABLE"):format(Config.Version), PAD, 300, 160, 10, T.label, MONO)
        local pct = label(plate, "0%", W - PAD - 80, 300, 80, 10, T.dim, MONO, RIGHT)
        local ready = false
        fill:GetPropertyChangedSignal("Size"):Connect(function()
            if ready then return end
            pct.Text = ("%d%%"):format(math.floor(fill.Size.X.Offset / TRACK * 100 + 0.5))
        end)

        local function typeIn(lbl)
            lbl.MaxVisibleGraphemes = 0
            lbl.TextTransparency = 0
            task.spawn(function()
                for i = 2, #lbl.Text + 1, 2 do
                    lbl.MaxVisibleGraphemes = i
                    task.wait()
                end
                lbl.MaxVisibleGraphemes = -1
            end)
        end

        local function burst(delay)
            task.delay(delay, function()
                local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = px(W / 2, CY), Size = px(64, 64), BackgroundTransparency = 1 }, plate)
                New("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
                local s = New("UIStroke", { Color = Config.Accent, Thickness = 1.5,
                    Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
                tween(ring, 0.7, { Size = px(260, 260) })
                tween(s, 0.7, { Transparency = 1 })
            end)
        end

        local function finish()
            alive = false
            spin:Cancel()
            root:Destroy()
            if blur then blur:Destroy() end
        end

        local function sequence()
            tween(root, 0.3, { BackgroundTransparency = DIM })
            tween(plate, 0.3, { GroupTransparency = 0 })
            tween(edge, 0.3, { Transparency = 0 })
            tween(scale, 0.45, { Scale = k }, Style.Back)
            fadeHalo(glow, 0.5, true)
            if blur then tween(blur, 0.4, { Size = BLUR }) end
            task.wait(0.45)

            for i, line in ipairs(lines) do
                tween(line.pip, 0.15, { BackgroundTransparency = 0 })
                typeIn(line.name)
                tween(fill, STEP * 0.9, { Size = px(math.floor(TRACK * i / #lines), 4) },
                    Style.Sine, Dir.InOut)
                task.wait(STEP * 0.65)
                tween(line.pip, 0.2, { BackgroundColor3 = T.green })
                tween(line.val, 0.2, { TextTransparency = 0 })
                tween(line.name, 0.3, { TextColor3 = T.dim })
                task.wait(STEP * 0.35)
            end

            ready = true
            pct.Text, pct.TextColor3 = "READY", T.green
            burst(0)
            burst(0.12)
            task.wait(0.45)

            tween(plate, 0.3, { GroupTransparency = 1 })
            tween(edge, 0.3, { Transparency = 1 })
            tween(scale, 0.3, { Scale = k * 1.06 }, Style.Quad, Dir.In)
            tween(root, 0.35, { BackgroundTransparency = 1 })
            fadeHalo(glow, 0.25, false)
            if blur then tween(blur, 0.45, { Size = 0 }) end
            onDone()
            task.wait(0.5)
            finish()
        end

        task.spawn(function()
            local ok, err = pcall(sequence)
            if not ok then
                warn("[Vanta] loader: " .. tostring(err))
                finish()
                frame.Visible = true
            end
        end)
    end

    local ok, err = pcall(polishPanel)
    if not ok then warn("[Vanta] polish: " .. tostring(err)) end
    ok, err = pcall(runLoader, revealPanel)
    if not ok then
        warn("[Vanta] loader: " .. tostring(err))
        frame.Visible = true
    end
end