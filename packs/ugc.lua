-- Vanta pack · Engine (PlaceId 73814454293317)
-- Every module registers through Module(); the hub builds the rows.
local CAT = "Engine"

local function hrp()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function seat()
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    return h and h.SeatPart
end

local function vehicle()
    local s = seat()
    if s then
        local m = s:FindFirstAncestorOfClass("Model")
        if m then return m end
    end
    local h = hrp()
    if not h then return nil end
    local best, bestD = nil, 45
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("VehicleSeat") then
            local dist = (d.Position - h.Position).Magnitude
            if dist < bestD then best, bestD = d:FindFirstAncestorOfClass("Model"), dist end
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

local function fire(prompt)
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    else
        pcall(function() prompt:InputHoldBegin() end)
        task.delay(0.12, function() pcall(function() prompt:InputHoldEnd() end) end)
    end
end

-- ── prompts ──────────────────────────────────────
do
    local AutoClaim = Module("Auto Claim", CAT, "grabs claim and reward prompts", nil, false)
    function AutoClaim.Start()
        AutoClaim:On(task.spawn(function()
            while AutoClaim.Enabled do
                for _, p in ipairs(promptsNear({ "claim", "collect", "reward", "pickup", "take" }, 45)) do
                    fire(p)
                end
                task.wait(0.5)
            end
        end))
    end
end

do
    local AutoDyno = Module("Auto Dyno", CAT, "starts dyno runs for you", nil, false)
    function AutoDyno.Start()
        AutoDyno:On(task.spawn(function()
            while AutoDyno.Enabled do
                local found = promptsNear({ "dyno", "test", "run", "start" }, 30)
                if #found > 0 then fire(found[1]) end
                task.wait(2)
            end
        end))
    end
end

do
    local AutoSell = Module("Auto Sell", CAT, "fires sell and bank prompts", nil, false)
    function AutoSell.Start()
        AutoSell:On(task.spawn(function()
            while AutoSell.Enabled do
                for _, p in ipairs(promptsNear({ "sell", "cash out", "bank", "deposit" }, 45)) do
                    fire(p)
                end
                task.wait(1)
            end
        end))
    end
end

do
    local Spam = Module("Prompt Spam", CAT, "fires every nearby prompt", nil, false)
    function Spam.Start()
        Spam:On(task.spawn(function()
            while Spam.Enabled do
                for _, p in ipairs(promptsNear({ "" }, 25)) do
                    fire(p)
                end
                task.wait(0.35)
            end
        end))
    end
end

-- ── visuals ──────────────────────────────────────
makeItemESP({
    name = "Car ESP", cat = CAT, desc = "outlines nearby vehicles", paid = true,
    roots = { "workspace" }, cap = 120, interval = 1,
    patterns = { "car", "vehicle", "chassis", "body" },
    color = Color3.fromRGB(126, 92, 255),
})

makeItemESP({
    name = "Cash ESP", cat = CAT, desc = "dropped cash and pickups", paid = true,
    roots = { "workspace" }, cap = 200, interval = 0.6,
    patterns = { "cash", "money", "coin", "drop", "gem" },
    color = Color3.fromRGB(74, 222, 128),
})

do
    local DynoHUD = Module("Dyno HUD", CAT, "car speed, health and gear", nil, false)
    function DynoHUD.Start()
        local box = Instance.new("TextLabel")
        box.Size = UDim2.fromOffset(180, 52)
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
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = box
        DynoHUD:Keep(box)

        DynoHUD:On(RunService.Heartbeat:Connect(function()
            local v = vehicle()
            local part = v and v.PrimaryPart
            local speed = 0
            if part then speed = math.floor(part.AssemblyLinearVelocity.Magnitude + 0.5) end
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            box.Text = ("speed  %d\nhealth %d\ncar    %s"):format(
                speed, h and math.floor(h.Health) or 0, v and v.Name:sub(1, 18) or "none")
        end))
    end
end

-- ── vehicle ──────────────────────────────────────
do
    local Tune = Module("Max Tune", CAT, "pushes tune values to max", nil, false)
    local SKIP = { "ratio", "gear", "weight", "mass" }
    local HIT = { "speed", "torque", "power", "boost", "rpm", "hp", "accel" }
    function Tune.Start()
        Tune:On(task.spawn(function()
            while Tune.Enabled do
                local v = vehicle()
                if v then
                    for _, d in ipairs(v:GetDescendants()) do
                        if d:IsA("NumberValue") or d:IsA("IntValue") then
                            local n = d.Name:lower()
                            local skip = false
                            for _, s in ipairs(SKIP) do
                                if n:find(s, 1, true) then skip = true break end
                            end
                            if not skip then
                                for _, s in ipairs(HIT) do
                                    if n:find(s, 1, true) then
                                        pcall(function() d.Value = 9999 end)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(1)
            end
        end))
    end
end

do
    local Turbo = Module("Turbo", CAT, "raises the seat speed cap", nil, false)
    function Turbo.Start()
        local s = seat()
        if not s then return false end
        local old = s.MaxSpeed
        pcall(function() s.MaxSpeed = 500 end)
        Turbo:Cleanup(function()
            if s.Parent then pcall(function() s.MaxSpeed = old end) end
        end)
    end
end

do
    local AntiFlip = Module("Anti Flip", CAT, "keeps the car level", nil, false)
    function AntiFlip.Start()
        AntiFlip:On(RunService.Heartbeat:Connect(function()
            local v = vehicle()
            local p = v and v.PrimaryPart
            if not p then return end
            local _, yaw = p.CFrame:ToEulerAnglesYXZ()
            p.CFrame = CFrame.new(p.CFrame.Position) * CFrame.Angles(0, yaw, 0)
        end))
    end
end

do
    local TPDealer = Module("TP to Dealer", CAT, "jumps you to the showroom", nil, true, true)
    function TPDealer.Start()
        local h = hrp()
        if not h then return false end
        local best, bestD = nil, math.huge
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if n:find("dealer", 1, true) or n:find("showroom", 1, true) or n:find("shop", 1, true) then
                    local dist = (d.Position - h.Position).Magnitude
                    if dist < bestD then best, bestD = d, dist end
                end
            end
        end
        if not best then
            Toast("no dealer found")
        else
            h.CFrame = best.CFrame + Vector3.new(0, 6, 0)
            Toast("moved to " .. best.Name:sub(1, 20))
        end
        TPDealer:Stop()
        task.delay(0.1, function() setVisual(TPDealer) end)
    end
end

do
    local Exit = Module("Eject", CAT, "hops you out of the car", nil, false, true)
    function Exit.Start()
        local s = seat()
        if s then pcall(function() s:Sit(nil) end) end
        Exit:Stop()
        task.delay(0.1, function() setVisual(Exit) end)
    end
end