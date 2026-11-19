-- Vanta pack · Engine (PlaceId 73814454293317)
-- All PlayerGui buttons. Clicks route through PlayerGui and hold properly.
local CAT = "Engine"
local okVim, VIM = pcall(game.GetService, game, "VirtualInputManager")
if not okVim then VIM = nil end
local GuiService = game:GetService("GuiService")

local function pgui()
    return LP:FindFirstChild("PlayerGui")
end

local function guiRoot()
    local p = pgui()
    return p and p:FindFirstChild("ScreenGui")
end

local function main()
    local g = guiRoot()
    return g and g:FindFirstChild("Main")
end

local function panel(name)
    local g = guiRoot()
    local frames = g and g:FindFirstChild("Frames")
    return frames and frames:FindFirstChild(name)
end

local function childByPrefix(parent, prefix)
    if not parent then return nil end
    for _, c in ipairs(parent:GetChildren()) do
        if c.Name:sub(1, #prefix) == prefix then return c end
    end
    return nil
end

local function shown(o)
    local p = o
    while p and p ~= game do
        if p:IsA("LayerCollector") then return p.Enabled end
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return false
end

-- "$1,250" -> 1250. The parentheses keep gsub's second return value (the
-- replacement count) out of tonumber, where it would be read as the base.
local function money(text)
    return tonumber((text:gsub("[^%d]", "")))
end

local function centre(btn)
    local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
    local sg = btn:FindFirstAncestorOfClass("ScreenGui")
    if sg and not sg.IgnoreGuiInset then
        local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
        if ok and inset then c += inset end
    end
    return c
end

-- hide the hub if it covers the point, press for `hold` seconds, restore.
-- returns ok plus the object that was actually under the cursor.
local function click(btn, hold)
    if not VIM then return false end
    if not btn or not btn:IsDescendantOf(game) or not shown(btn) then return false end
    local p = pgui()
    if not p then return false end
    local c = centre(btn)

    local fp, fs = frame.AbsolutePosition, frame.AbsoluteSize
    local covered = frame.Visible and c.X >= fp.X and c.X <= fp.X + fs.X
        and c.Y >= fp.Y and c.Y <= fp.Y + fs.Y
    if covered then
        frame.Visible = false
        task.wait(0.06)
    end

    local target = btn
    local ok, objs = pcall(function() return p:GetGuiObjectsAtPosition(c.X, c.Y) end)
    if ok and type(objs) == "table" then
        for _, o in ipairs(objs) do
            if not o:IsDescendantOf(gui) then
                local b = o:IsA("TextButton") and o or o:FindFirstAncestorOfClass("TextButton")
                if b then target = b end
                break
            end
        end
    end

    pcall(function() VIM:SendMouseMoveEvent(c.X, c.Y, p) end)
    task.wait(0.02)
    pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, p, 0) end)
    task.wait(hold or 0.12)
    pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, p, 0) end)

    if covered then
        task.wait(0.05)
        frame.Visible = true
    end
    return true, target
end

local function cash()
    local ls = LP:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild("Cash")
    return v and tonumber(v.Value) or 0
end

-- opens a left-bar tab, unless its panel is already on screen: clicking a tab
-- that is already open can close it again
local function openPanel(prefix, name)
    local p = name and panel(name)
    if p and shown(p) then return end
    local left = main() and main():FindFirstChild("Left")
    local b = childByPrefix(left, prefix)
    if b then click(b) end
end

-- repeats step every `every` seconds while the module is on. task.defer, not
-- task.spawn: a spawned loop runs before Start returns, while Enabled can still
-- be false, and would exit on its first check. Errors in one pass don't end it.
local function loop(m, every, step)
    task.defer(function()
        while m.Enabled do
            local ok, err = pcall(step)
            if not ok then warn(("[Vanta] %s: %s"):format(m.Name, tostring(err))) end
            task.wait(every)
        end
    end)
end

-- one-shot modules: switch off once the hub has finished switching them on,
-- then repaint the row
local function done(m)
    task.defer(function()
        if m.Enabled then m:Stop() end
        if setVisual then pcall(setVisual, m) end
    end)
end

do
    local Test = Module("Click Test", CAT, "reports what a click hits", nil, false, true)
    function Test.Start()
        done(Test)
        local m = main()
        local right = m and m:FindFirstChild("Right")
        local b = childByPrefix(right, "Engine")
        if not b then
            Toast("engine button not found")
            return
        end
        local ok, target = click(b, 0.2)
        Toast(ok and ("hit " .. target.Name) or "click failed")
    end
end

-- ── engine ───────────────────────────────────────
do
    local Start = Module("Auto Start Engine", CAT, "presses Start Engine", nil, false)
    function Start.Start()
        loop(Start, 2.5, function()
            local right = main() and main():FindFirstChild("Right")
            local b = childByPrefix(right, "Engine")
            if b then click(b, 0.2) end
        end)
    end
end

do
    local Dyno = Module("Auto Dyno", CAT, "presses Run Dyno", nil, false)
    function Dyno.Start()
        loop(Dyno, 4, function()
            local right = main() and main():FindFirstChild("Right")
            local b = childByPrefix(right, "Dyno")
            if b then click(b, 0.2) end
        end)
    end
end

do
    local Throttle = Module("Hold Throttle", CAT, "holds W while on", nil, false)
    function Throttle.Start()
        if not VIM then return false end
        local function send(down)
            pcall(function() VIM:SendKeyEvent(down, Enum.KeyCode.W, false, game) end)
        end
        task.delay(0.2, function()
            if Throttle.Enabled then send(true) end
        end)
        Throttle:Cleanup(function() send(false) end)
    end
end

-- ── gearbox ──────────────────────────────────────
do
    local Up = Module("Shift Up", CAT, "presses + repeatedly", nil, false)
    function Up.Start()
        loop(Up, 1.2, function()
            local pedals = main() and main():FindFirstChild("Pedals")
            local b = pedals and childByPrefix(pedals, "Shift")
            if b then click(b, 0.4) end
        end)
    end
end

do
    local Down = Module("Shift Down", CAT, "presses - repeatedly", nil, false)
    function Down.Start()
        loop(Down, 1.2, function()
            local pedals = main() and main():FindFirstChild("Pedals")
            local b = pedals and childByPrefix(pedals, "DownShift")
            if b then click(b, 0.4) end
        end)
    end
end

-- ── buying ───────────────────────────────────────
do
    local Equip = Module("Equip Best Engine", CAT, "buys the best one you can afford", nil, true, true)
    function Equip.Start()
        done(Equip)
        task.spawn(function()
            openPanel("03", "Engines")
            task.wait(0.6)
            local box = panel("Engines")
            local list = box and box:FindFirstChild("Content")
            list = list and list:FindFirstChild("List")
            if not list then Toast("engines panel not found") return end

            local budget, best, bestPrice = cash(), nil, -1
            for _, row in ipairs(list:GetChildren()) do
                if row:IsA("GuiObject") then
                    local equipBtn, price = nil, nil
                    for _, d in ipairs(row:GetDescendants()) do
                        if d:IsA("TextLabel") then
                            if d.Text == "Equip" then
                                equipBtn = d:FindFirstAncestorOfClass("TextButton")
                            elseif d.Text:sub(1, 1) == "$" then
                                price = money(d.Text)
                            end
                        end
                    end
                    if equipBtn and price and price <= budget and price > bestPrice then
                        best, bestPrice = equipBtn, price
                    end
                end
            end
            if not best then Toast("nothing affordable") return end
            click(best, 0.15)
            Toast(("equipped · $%d"):format(bestPrice))
        end)
    end
end

do
    local Buy = Module("Auto Upgrade", CAT, "buys upgrades you can afford", nil, false)
    function Buy.Start()
        loop(Buy, 1.5, function()
            openPanel("04", "Upgrades")
            task.wait(0.5)
            local box = panel("Upgrades")
            if not box then return end
            for _, d in ipairs(box:GetDescendants()) do
                if not Buy.Enabled then return end
                if d:IsA("TextLabel") and shown(d) and d.Text:sub(1, 1) == "$" then
                    local price = money(d.Text)
                    if price and price <= cash() then
                        local b = d:FindFirstAncestorOfClass("TextButton")
                        if b then click(b, 0.12) end
                    end
                end
            end
        end)
    end
end

do
    local Nitro = Module("Auto Nitro", CAT, "presses Nitrous", nil, false)
    function Nitro.Start()
        loop(Nitro, 2, function()
            openPanel("06", "Nitro")
            task.wait(0.8)
            local box = panel("Nitro")
            if not box then return end
            for _, d in ipairs(box:GetDescendants()) do
                if d:IsA("TextLabel") and shown(d) and d.Text ~= "X" then
                    local b = d:FindFirstAncestorOfClass("TextButton")
                    if b then click(b, 0.15) break end
                end
            end
        end)
    end
end

-- ── readouts ─────────────────────────────────────
do
    local HUD = Module("Cash HUD", CAT, "cash and speed", nil, false)
    function HUD.Start()
        local box = Instance.new("TextLabel")
        box.Size = UDim2.fromOffset(180, 46)
        box.Position = UDim2.fromOffset(18, 66)
        box.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
        box.BackgroundTransparency = 0.2
        box.BorderSizePixel = 0
        box.Text = ""
        box.TextColor3 = Color3.fromRGB(240, 240, 246)
        box.TextSize = 11
        box.Font = Enum.Font.RobotoMono
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Top
        box.ZIndex = 15
        box.Parent = gui
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingTop = UDim.new(0, 6)
        pad.Parent = box
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = box
        HUD:Keep(box)

        HUD:On(RunService.Heartbeat:Connect(function()
            local speed = 0
            local right = main() and main():FindFirstChild("Right")
            local stats = right and right:FindFirstChild("Stats")
            if stats then
                for _, d in ipairs(stats:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local v = tonumber(d.Text)
                        if v and v > speed then speed = v end
                    end
                end
            end
            box.Text = ("cash   $%d\nspeed  %d km/h"):format(cash(), math.floor(speed))
        end))
    end
end

do
    local Menu = Module("Open Upgrades", CAT, "jumps straight to the shop tab", nil, false, true)
    function Menu.Start()
        done(Menu)
        task.spawn(openPanel, "04", "Upgrades")
    end
end