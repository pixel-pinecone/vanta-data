-- Engine / dyno pack
local VIM = game:GetService("VirtualInputManager")

local function path(...)
    local node = LP:FindFirstChildOfClass("PlayerGui")
    for _, name in ipairs({ ... }) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local function fire(btn)
    if not btn or not btn:IsA("GuiButton") then return end
    if firesignal then
        local ok = pcall(firesignal, btn.MouseButton1Click)
        if ok then return end
    end
    local p = btn.AbsolutePosition + btn.AbsoluteSize / 2
    pcall(function() VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0) end)
    task.wait(0.02)
    pcall(function() VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0) end)
end

-- claims completed upgrade quests. Each quest is fired once per completion and
-- re-armed if it resets, so nothing spams and nothing is missed.
local Claim = Module("Auto Claim", "Ugc", "claims finished upgrade quests", nil, true)
function Claim.Start()
    local list = path("Frames", "Upgrades", "Content", "List")
    if not list then
        Toast("upgrades panel not found")
        return false
    end
    local quests = #list:GetChildren()
    Toast(("watching %d quests"):format(quests))

    local armed, on = {}, true
    task.spawn(function()
        while on do
            local holder = path("Frames", "Upgrades", "Content", "List")
            if holder then
                for _, quest in ipairs(holder:GetChildren()) do
                    local claim = quest:FindFirstChild("Claim")
                    local prog = quest:FindFirstChild("ProgressText")
                    local done, total = (prog and prog.Text or ""):match("(%d+)%s*/%s*(%d+)")
                    local complete = done and total and done == total
                    if complete and not armed[quest] then
                        armed[quest] = true
                        fire(claim)
                        Toast("claimed · " .. quest.Name)
                        task.wait(0.12)
                    elseif not complete then
                        armed[quest] = nil
                    end
                end
            end
            task.wait(1.2)
        end
    end)
    Claim:Cleanup(function() on = false end)
end

local Dyno = Module("Auto Dyno", "Ugc", "repeats dyno runs", nil, true)
function Dyno.Start()
    local engine = path("ScreenGui", "Main", "Right", "EngineButton")
    local dyno = path("ScreenGui", "Main", "Right", "DynoButton")
    if not dyno then
        Toast("dyno button not found")
        return false
    end
    Toast(engine and "dyno ready" or "dyno ready · no engine button")

    local on = true
    task.spawn(function()
        while on do
            local lbl = engine and engine:FindFirstChild("Content")
            lbl = lbl and lbl:FindFirstChild("Label")
            if lbl and lbl.Text:find("Start") then
                fire(engine)
                task.wait(0.7)
            end
            fire(dyno)
            task.wait(4)
        end
    end)
    Dyno:Cleanup(function() on = false end)
end

local HUD = Module("Stat HUD", "Ugc", "speed, gear, power, temp overlay", nil, true)
function HUD.Start()
    if not Drawing then return false end
    local stats = path("ScreenGui", "Main", "Right", "Stats")
    if not stats then
        Toast("stats panel not found")
        return false
    end
    Toast("hud attached")

    local lines = {}
    for i = 1, 4 do
        lines[i] = espDraw("Text", { Size = 14, Outline = true, Center = false,
            Color = Color3.fromRGB(240, 240, 246),
            Position = Vector2.new(24, 118 + (i - 1) * 18) })
    end

    local function readStat(stat)
        local holder = stats:FindFirstChild(stat)
        if not holder then return "—" end
        for _, l in ipairs(holder:GetChildren()) do
            if l:IsA("TextLabel") and l.Text ~= "" and l.Text ~= stat then
                if l.Text:match("%d") or l.Text:match("^[NRD]$") then return l.Text end
            end
        end
        return "—"
    end

    local acc = 0
    HUD:On(RunService.RenderStepped:Connect(function(dt)
        acc += dt
        if acc < 0.1 then return end
        acc = 0
        local shown = workspace.CurrentCamera ~= nil
        for i, l in ipairs(lines) do l.Visible = shown end
        if not shown then return end
        lines[1].Text = "SPEED   " .. readStat("Speed")
        lines[2].Text = "GEAR    " .. readStat("Gear")
        lines[3].Text = "POWER   " .. readStat("Horsepower")
        lines[4].Text = "TEMP    " .. readStat("Temperature")
    end))
    HUD:Cleanup(function()
        for _, l in ipairs(lines) do pcall(function() l:Remove() end) end
    end)
end