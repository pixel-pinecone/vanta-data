-- Vanta pack · Engine (PlaceId 73814454293317)
-- The game is all PlayerGui buttons: no prompts, no click detectors.
local CAT = "Engine"
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local function guiRoot()
    local pg = LP:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("ScreenGui")
end

local function main()
    local g = guiRoot()
    return g and g:FindFirstChild("Main")
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

local function buttonFor(text, root)
    for _, d in ipairs((root or guiRoot()):GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == text and shown(d) then
            if d:IsA("TextButton") then return d end
            local b = d:FindFirstAncestorOfClass("TextButton")
            if b then return b end
        end
    end
    return nil
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

local function click(btn)
    if not btn or not btn:IsDescendantOf(game) or not shown(btn) then return false end
    local c = centre(btn)
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    local covered = frame.Visible and c.X >= p.X and c.X <= p.X + s.X
        and c.Y >= p.Y and c.Y <= p.Y + s.Y
    if covered then frame.Visible = false end
    task.wait(covered and 0.04 or 0)
    pcall(function() VIM:SendMouseMoveEvent(c.X, c.Y, game) end)
    pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0) end)
    task.wait(0.02)
    pcall(function() VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0) end)
    if covered then
        task.wait(0.05)
        frame.Visible = true
    end
    return true
end

local function cash()
    local ls = LP:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild("Cash")
    return v and v.Value or 0
end

local function openPanel(prefix)
    local left = main() and main():FindFirstChild("Left")
    local b = childByPrefix(left, prefix)
    if b then click(b) end
end

-- ── engine ───────────────────────────────────────
do
    local Start = Module("Auto Start Engine", CAT, "presses Start Engine", nil, false)
    function Start.Start()
        Start:On(task.spawn(function()
            while Start.Enabled do
                local right = main() and main():FindFirstChild("Right")
                local b = childByPrefix(right, "Engine")
                if b then click(b) end
                task.wait(2.5)
            end
        end))
    end
end

do
    local Dyno = Module("Auto Dyno", CAT, "presses Run Dyno", nil, false)
    function Dyno.Start()
        Dyno:On(task.spawn(function()
            while Dyno.Enabled do
                local right = main() and main():FindFirstChild("Right")
                local b = childByPrefix(right, "Dyno")
                if b then click(b) end
                task.wait(4)
            end
        end))
    end
end

do
    local Throttle = Module("Hold Throttle", CAT, "holds W while on", nil, false)
    function Throttle.Start()
        local function send(down)
            if not VIM then return end
            pcall(function() VIM:SendKeyEvent(down, Enum.KeyCode.W, false, game) end)
        end
        task.wait(0.2)
        send(true)
        Throttle:Cleanup(function() send(false) end)
    end
end

-- ── gearbox ──────────────────────────────────────
do
    local Up = Module("Shift Up", CAT, "presses + repeatedly", nil, false)
    function Up.Start()
        Up:On(task.spawn(function()
            while Up.Enabled do
                local pedals = main() and main():FindFirstChild("Pedals")
                local b = pedals and childByPrefix(pedals, "Shift")
                if b then click(b) end
                task.wait(1.2)
            end
        end))
    end
end

do
    local Down = Module("Shift Down", CAT, "presses - repeatedly", nil, false)
    function Down.Start()
        Down:On(task.spawn(function()
            while Down.Enabled do
                local pedals = main() and main():FindFirstChild("Pedals")
                local b = pedals and childByPrefix(pedals, "DownShift")
                if b then click(b) end
                task.wait(1.2)
            end
        end))
    end
end

-- ── buying ───────────────────────────────────────
do
    local Equip = Module("Equip Best Engine", CAT, "buys the best one you can afford", nil, true)
    function Equip.Start()
        Equip:Stop()
        task.delay(0.1, function() setVisual(Equip) end)
        task.spawn(function()
            openPanel("03")
            task.wait(0.6)
            local g = guiRoot()
            local frames = g and g:FindFirstChild("Frames")
            local box = frames and frames:FindFirstChild("Engines")
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
                                price = tonumber(d.Text:gsub("[^%d]", ""))
                            end
                        end
                    end
                    if equipBtn and price and price <= budget and price > bestPrice then
                        best, bestPrice = equipBtn, price
                    end
                end
            end
            if not best then Toast("nothing affordable") return end
            click(best)
            Toast(("equipped · $%d"):format(bestPrice))
        end)
    end
end

do
    local Buy = Module("Auto Upgrade", CAT, "buys upgrades you can afford", nil, false)
    function Buy.Start()
        Buy:On(task.spawn(function()
            while Buy.Enabled do
                openPanel("04")
                task.wait(0.5)
                local g = guiRoot()
                local frames = g and g:FindFirstChild("Frames")
                local box = frames and frames:FindFirstChild("Upgrades")
                if box then
                    for _, d in ipairs(box:GetDescendants()) do
                        if d:IsA("TextLabel") and shown(d) then
                            local t = d.Text
                            if t:sub(1, 1) == "$" then
                                local price = tonumber(t:gsub("[^%d]", ""))
                                if price and price <= cash() then
                                    local b = d:FindFirstAncestorOfClass("TextButton")
                                    if b then click(b) end
                                end
                            end
                        end
                    end
                end
                task.wait(1.5)
            end
        end))
    end
end

do
    local Nitro = Module("Auto Nitro", CAT, "presses Nitrous", nil, false)
    function Nitro.Start()
        Nitro:On(task.spawn(function()
            while Nitro.Enabled do
                openPanel("06")
                task.wait(0.8)
                local g = guiRoot()
                local frames = g and g:FindFirstChild("Frames")
                local box = frames and frames:FindFirstChild("Nitro")
                if box then
                    for _, d in ipairs(box:GetDescendants()) do
                        if d:IsA("TextLabel") and shown(d) and d.Text ~= "X" then
                            local b = d:FindFirstAncestorOfClass("TextButton")
                            if b then click(b) break end
                        end
                    end
                end
                task.wait(2)
            end
        end))
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
                    if d:IsA("TextLabel") and tonumber(d.Text) then
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
        openPanel("04")
        Menu:Stop()
        task.delay(0.1, function() setVisual(Menu) end)
    end
end