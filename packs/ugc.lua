-- Vanta pack · Engine (PlaceId 73814454293317)
-- Pedal pressing and upgrading. No vehicles.
local CAT = "Engine"

local PEDAL = { "pedal", "throttle", "gas", "rev", "push", "step", "press", "accelerate" }
local UPGRADE = { "upgrade", "buy", "purchase", "improve", "level" }

local function hrp()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function nearest(names, radius)
    local h = hrp()
    if not h then return nil end
    local best, bestD = nil, radius or 60
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name:lower()
            for _, p in ipairs(names) do
                if n:find(p, 1, true) then
                    local dist = (d.Position - h.Position).Magnitude
                    if dist < bestD then best, bestD = d, dist end
                    break
                end
            end
        end
    end
    return best
end

local function promptsNear(patterns, radius)
    local out = {}
    local h = hrp()
    if not h then return out end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local part = d.Parent
            if part and part:IsA("BasePart") and (part.Position - h.Position).Magnitude <= radius then
                local hay = (tostring(d.ActionText) .. " " .. tostring(d.ObjectText) .. " " .. part.Name):lower()
                for _, p in ipairs(patterns) do
                    if hay:find(p, 1, true) then
                        out[#out + 1] = d
                        break
                    end
                end
            end
        end
    end
    return out
end

local function clicksNear(patterns, radius)
    local out = {}
    local h = hrp()
    if not h then return out end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ClickDetector") then
            local part = d.Parent
            if part and part:IsA("BasePart") and (part.Position - h.Position).Magnitude <= radius then
                local n = part.Name:lower()
                for _, p in ipairs(patterns) do
                    if n:find(p, 1, true) then
                        out[#out + 1] = d
                        break
                    end
                end
            end
        end
    end
    return out
end

local function firePrompt(p)
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, p)
    else
        pcall(function() p:InputHoldBegin() end)
        task.delay(0.1, function() pcall(function() p:InputHoldEnd() end) end)
    end
end

local function fireClick(cd)
    if type(fireclickdetector) == "function" then
        pcall(fireclickdetector, cd)
    else
        pcall(function() cd:FireClickDetector() end)
    end
end

-- ── pedals ───────────────────────────────────────
do
    local Pedal = Module("Auto Pedal", CAT, "fires every pedal in range", nil, false)
    function Pedal.Start()
        Pedal:On(task.spawn(function()
            while Pedal.Enabled do
                for _, p in ipairs(promptsNear(PEDAL, 40)) do firePrompt(p) end
                for _, c in ipairs(clicksNear(PEDAL, 40)) do fireClick(c) end
                task.wait(0.15)
            end
        end))
    end
end

do
    local Stand = Module("Stand on Pedal", CAT, "holds you on the pedal", nil, false)
    function Stand.Start()
        Stand:On(task.spawn(function()
            while Stand.Enabled do
                local part = nearest(PEDAL, 80)
                local h = hrp()
                if part and h then h.CFrame = part.CFrame + Vector3.new(0, 3, 0) end
                task.wait(0.4)
            end
        end))
    end
end

do
    local Tap = Module("Fast Pedal", CAT, "10 pedal taps per second", nil, false)
    function Tap.Start()
        Tap:On(task.spawn(function()
            while Tap.Enabled do
                local part = nearest(PEDAL, 80)
                if part then
                    local h = hrp()
                    if h then h.CFrame = part.CFrame + Vector3.new(0, 3, 0) end
                    for _, c in ipairs(clicksNear(PEDAL, 40)) do fireClick(c) end
                    for _, p in ipairs(promptsNear(PEDAL, 40)) do firePrompt(p) end
                end
                task.wait(0.1)
            end
        end))
    end
end

-- ── upgrades ─────────────────────────────────────
do
    local Upgrade = Module("Auto Upgrade", CAT, "buys upgrades when affordable", nil, false)
    function Upgrade.Start()
        Upgrade:On(task.spawn(function()
            while Upgrade.Enabled do
                for _, p in ipairs(promptsNear(UPGRADE, 60)) do firePrompt(p) end
                for _, c in ipairs(clicksNear(UPGRADE, 60)) do fireClick(c) end
                task.wait(0.5)
            end
        end))
    end
end

do
    local BuyAll = Module("Buy All", CAT, "one pass over every upgrade", nil, true, true)
    function BuyAll.Start()
        for _, p in ipairs(promptsNear(UPGRADE, 120)) do firePrompt(p) end
        for _, c in ipairs(clicksNear(UPGRADE, 120)) do fireClick(c) end
        Toast("fired every upgrade in range")
        BuyAll:Stop()
        task.delay(0.1, function() setVisual(BuyAll) end)
    end
end

do
    local Claim = Module("Auto Claim", CAT, "claim and reward prompts", nil, false)
    function Claim.Start()
        Claim:On(task.spawn(function()
            while Claim.Enabled do
                for _, p in ipairs(promptsNear({ "claim", "collect", "reward", "pickup", "take" }, 60)) do
                    firePrompt(p)
                end
                task.wait(0.6)
            end
        end))
    end
end

do
    local Spam = Module("Prompt Spam", CAT, "fires every nearby prompt", nil, false)
    function Spam.Start()
        Spam:On(task.spawn(function()
            while Spam.Enabled do
                for _, p in ipairs(promptsNear({ "" }, 30)) do firePrompt(p) end
                task.wait(0.3)
            end
        end))
    end
end

-- ── visuals ──────────────────────────────────────
makeItemESP({
    name = "Pedal ESP", cat = CAT, desc = "outlines pedals and stations", paid = true,
    roots = { "workspace" }, cap = 150, interval = 1,
    patterns = PEDAL,
    color = Color3.fromRGB(126, 92, 255),
})

makeItemESP({
    name = "Upgrade ESP", cat = CAT, desc = "outlines upgrade stations", paid = true,
    roots = { "workspace" }, cap = 150, interval = 1,
    patterns = UPGRADE,
    color = Color3.fromRGB(74, 222, 128),
})

do
    local HUD = Module("Money HUD", CAT, "cash, speed and RPM", nil, false)
    function HUD.Start()
        local box = Instance.new("TextLabel")
        box.Size = UDim2.fromOffset(180, 50)
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
            local money, speed = 0, 0
            local ls = LP:FindFirstChild("leaderstats")
            if ls then
                for _, v in ipairs(ls:GetChildren()) do
                    if v:IsA("IntValue") or v:IsA("NumberValue") then
                        money = math.max(money, v.Value)
                    end
                end
            end
            local h = hrp()
            if h then speed = math.floor(h.AssemblyLinearVelocity.Magnitude + 0.5) end
            box.Text = ("cash   %d\nspeed  %d"):format(math.floor(money), speed)
        end))
    end
end

do
    local Go = Module("TP to Pedal", CAT, "jumps you onto the nearest pedal", nil, true, true)
    function Go.Start()
        local part = nearest(PEDAL, 300)
        local h = hrp()
        if part and h then
            h.CFrame = part.CFrame + Vector3.new(0, 3, 0)
            Toast("moved to " .. part.Name:sub(1, 20))
        else
            Toast("no pedal found")
        end
        Go:Stop()
        task.delay(0.1, function() setVisual(Go) end)
    end
end