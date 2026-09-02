local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local Stats = cloneref(game:GetService("Stats"))
local Players = cloneref(game:GetService("Players"))
local Workspace = cloneref(game:GetService("Workspace"))
local ProximityPromptService = cloneref(game:GetService("ProximityPromptService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))

local LocalPlayer = Players.LocalPlayer

-- WindUI Loader
local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)

    if ok then
        WindUI = result
    else
        if RunService:IsStudio() then
            WindUI = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init"))
        else
            WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        end
    end
end

local ThemeName = "Dark"

local Window = WindUI:CreateWindow({
    Title = "Bytee Hub (PC)",
    Author = "by Bytecode & Levis",
    Icon = "swords",
    Theme = ThemeName,
    ToggleKey = Enum.KeyCode.F,
    Size = UDim2.fromOffset(900, 600),
    Transparent = true,
    OpenButton = {
        Title = "Open Bytee Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.9,
        Size = UDim2.fromOffset(160, 38),
        Color = ColorSequence.new(
            Color3.fromHex("#83889E"),
            Color3.fromHex("#5A5F73")
        ),
    },
})

Window:Tag({
    Title = "Premium PC V1",
    Color = "ElementBackground",
})

-----------------------------------------------------------------------
-- HOURLY EARNINGS TRACKER
-----------------------------------------------------------------------
local StartTime = os.time()
local StartMoney = LocalPlayer:GetAttribute("Money") or 0
local CurrentHourlyRate = 0

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local currentMoney = LocalPlayer:GetAttribute("Money") or 0
            local earned = currentMoney - StartMoney
            local elapsed = os.time() - StartTime
            if elapsed > 0 then
                CurrentHourlyRate = math.floor((earned / elapsed) * 3600)
            end
        end)
    end
end)

-----------------------------------------------------------------------
-- AUTO EAT & DRINK SYSTEM
-----------------------------------------------------------------------
local ToolEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tool"):WaitForChild("Event")
local FOOD_TOOLS = { CerealBar = true, FoodPlate = true, Popcorn = true }
local DRINK_TOOLS = { WaterCup = true, Soda = true, BloxyCola = true }

local AutoHungerState = { Enabled = false, EatBelow = 50, DrinkBelow = 50 }
local RunningAutoHunger = true
local vendingMachines = {}
local AutoEatStatusLabel = "Idle"

local function getCharacterHunger()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil, nil end
    return char, char:FindFirstChildOfClass("Humanoid")
end

local function findAutoEatTool(names)
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and names[t.Name] then return t end
        end
    end
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and names[t.Name] then return t end
    end
    return nil
end

local function stowLeftover(names)
    local char, humanoid = getCharacterHunger()
    if not humanoid then return end
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped and names[equipped.Name] then
        pcall(function() humanoid:UnequipTools() end)
    end
end

local function collectVendingMachines()
    local list = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("RemoteEvent") and inst.Parent and inst.Parent:IsA("Configuration") then
            local text = inst.Parent:GetAttribute("Text") or ""
            if text:find("Buy Food") or text:find("Buy Drink") then
                local machine = inst:FindFirstAncestorOfClass("Model")
                if machine then
                    table.insert(list, { event = inst, kind = text:find("Food") and "Food" or "Drink", model = machine, price = tonumber(text:match("%$(%d+)")) or 3 })
                end
            end
        end
    end
    return list
end

local function getNearestMachine(kind)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local best, bestDist = nil, math.huge
    for _, m in ipairs(vendingMachines) do
        if m.kind == kind and m.event.Parent then
            local ok, pos = pcall(function() return m.model:GetPivot().Position end)
            if ok and pos then
                local d = root and (pos - root.Position).Magnitude or 0
                if d < bestDist then best, bestDist = m, d end
            end
        end
    end
    return best, bestDist
end

local function consumeAutoHunger(kind, toolNames, statName, thresholdOf)
    local actions, misses = 0, 0
    while RunningAutoHunger and AutoHungerState.Enabled and actions < 50 and misses < 3 do
        local threshold = thresholdOf()
        local stat = LocalPlayer:GetAttribute(statName)
        if not stat or stat >= threshold then break end
        local tool = findAutoEatTool(toolNames)
        if not tool then
            local machineKind = (kind == "Eat") and "Food" or "Drink"
            local nearest = getNearestMachine(machineKind)
            if not nearest then vendingMachines = collectVendingMachines() nearest = getNearestMachine(machineKind) end
            if not nearest then AutoEatStatusLabel = "No vending machine found" break end
            if (LocalPlayer:GetAttribute("Money") or 0) < nearest.price then AutoEatStatusLabel = "Not enough money" break end
            AutoEatStatusLabel = "Buying..."
            nearest.event:FireServer()
            local t0 = os.clock()
            repeat task.wait(0.15) tool = findAutoEatTool(toolNames) until tool or os.clock() - t0 > 3
            if not tool then misses += 1 task.wait(1) continue end
        end
        local _, humanoid = getCharacterHunger()
        if not humanoid then break end
        if tool.Parent == LocalPlayer.Backpack then
            humanoid:EquipTool(tool)
            local t0 = os.clock()
            while RunningAutoHunger and AutoHungerState.Enabled and tool.Parent == LocalPlayer.Backpack and os.clock() - t0 < 2 do task.wait(0.1) end
            task.wait(0.3)
        end
        if not tool.Parent then actions += 1 continue end
        local t0 = os.clock()
        while RunningAutoHunger and AutoHungerState.Enabled and tool.Parent and tool:GetAttribute("OnCooldown") and os.clock() - t0 < 6 do task.wait(0.15) end
        if not RunningAutoHunger or not AutoHungerState.Enabled or not tool.Parent then actions += 1 continue end
        local before = LocalPlayer:GetAttribute(statName) or 0
        ToolEvent:FireServer(kind, tool)
        AutoEatStatusLabel = kind == "Eat" and "Eating..." or "Drinking..."
        actions += 1
        local t1 = os.clock()
        while RunningAutoHunger and AutoHungerState.Enabled and os.clock() - t1 < 4 do
            if not tool.Parent then break end
            if (LocalPlayer:GetAttribute(statName) or 0) ~= before then break end
            task.wait(0.1)
        end
        if (LocalPlayer:GetAttribute(statName) or 0) ~= before then misses = 0 else misses += 1 end
        task.wait(0.5)
    end
    stowLeftover(toolNames)
    if AutoHungerState.Enabled then AutoEatStatusLabel = "Idle" end
end

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            if not RunningAutoHunger or not AutoHungerState.Enabled then return end
            local hunger = LocalPlayer:GetAttribute("Hunger")
            local thirst = LocalPlayer:GetAttribute("Thirst")
            if hunger and hunger < AutoHungerState.EatBelow then
                consumeAutoHunger("Eat", FOOD_TOOLS, "Hunger", function() return AutoHungerState.EatBelow end)
            end
            if thirst and thirst < AutoHungerState.DrinkBelow then
                consumeAutoHunger("Drink", DRINK_TOOLS, "Thirst", function() return AutoHungerState.DrinkBelow end)
            end
        end)
    end
end)
-----------------------------------------------------------------------
-- FARM SYSTEMS
-----------------------------------------------------------------------
local RocksFolder = Workspace:WaitForChild("Tasks"):WaitForChild("Prisoner"):WaitForChild("Rocks")
local TrashesFolder = Workspace:WaitForChild("Tasks"):WaitForChild("Prisoner"):WaitForChild("Trashes")
local MineRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tool"):WaitForChild("Event")
local JanitorTasks = Workspace:WaitForChild("Tasks"):WaitForChild("Janitor")

local farming = false
local cleanedCount = 0

local function getCharacterParts()
    local char = LocalPlayer.Character
    if not char or char.Parent == nil then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil, nil end
    return char, hrp
end

local function getMop()
    local char = LocalPlayer.Character
    if char then
        local equipped = char:FindFirstChild("Mop")
        if equipped and equipped:IsA("Tool") then return equipped, true end
    end
    local bagMop = LocalPlayer.Backpack:FindFirstChild("Mop")
    if bagMop and bagMop:IsA("Tool") then return bagMop, false end
    return nil, false
end

local function getPuddles()
    local list = {}
    for _, child in ipairs(JanitorTasks:GetChildren()) do
        if child:IsA("BasePart") and child.Size.Y < 0.5 then table.insert(list, child) end
    end
    return list
end

local function nearestPuddle(origin)
    local best, bestDist = nil, math.huge
    for _, puddle in ipairs(getPuddles()) do
        local dist = (puddle.Position - origin).Magnitude
        if dist < bestDist then best, bestDist = puddle, dist end
    end
    return best
end

local function mopPuddle(puddle)
    while farming do
        local char = LocalPlayer.Character
        if not char then return false end
        local mop, equipped = getMop()
        if not mop then return false end
        if not equipped then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return false end
            hum:EquipTool(mop) task.wait(0.4) continue
        end
        if puddle.Parent ~= JanitorTasks then return true end
        if mop:GetAttribute("OnCooldown") then task.wait(0.25) continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        if (hrp.Position - puddle.Position).Magnitude > 8 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(puddle.Position + Vector3.new(0, 3.2, 0))
            task.wait(0.2) continue
        end
        ToolEvent:FireServer("Mop", mop, puddle)
        task.wait(0.5)
    end
    return false
end

local function farmLoop()
    while farming do
        local char, hrp = getCharacterParts()
        if not char or not hrp then task.wait(1) continue end
        local mop = getMop()
        if not mop then task.wait(1) continue end
        local puddle = nearestPuddle(hrp.Position)
        if not puddle then task.wait(1) continue end
        local wasCleaned = mopPuddle(puddle)
        if wasCleaned then cleanedCount += 1 end
        task.wait(0.15)
    end
end

-- Mining
local AutoMine = { IsActive = false, NoclipConnection = nil, LockConnection = nil, OriginalCollisions = {}, RunningThread = nil }
local function clearFarmTable(t) for key in pairs(t) do t[key] = nil end end

function AutoMine.FindClosestRock()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    local closest, minDistance = nil, math.huge
    for _, rock in ipairs(RocksFolder:GetChildren()) do
        if rock:IsA("BasePart") then
            local health = rock:GetAttribute("Health")
            local destroyed = rock:GetAttribute("Destroyed")
            if health and health > 0 and not destroyed then
                local distance = (rock.Position - rootPart.Position).Magnitude
                if distance < minDistance then minDistance = distance closest = rock end
            end
        end
    end
    return closest
end

function AutoMine.IsRockDead(rock)
    if not rock or not rock.Parent then return true end
    local health = rock:GetAttribute("Health")
    local destroyed = rock:GetAttribute("Destroyed")
    return (health and health <= 0) or destroyed == true
end

function AutoMine.Start()
    if AutoMine.IsActive then return end
    AutoMine.IsActive = true
    clearFarmTable(AutoMine.OriginalCollisions)
    AutoMine.NoclipConnection = RunService.Stepped:Connect(function()
        if not AutoMine.IsActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if AutoMine.OriginalCollisions[part] == nil then AutoMine.OriginalCollisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end)
    AutoMine.RunningThread = task.spawn(function()
        while AutoMine.IsActive do
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if not humanoid or not rootPart or not backpack then task.wait(0.5) continue end
            local targetRock = AutoMine.FindClosestRock()
            if targetRock then
                AutoMine.LockConnection = RunService.Heartbeat:Connect(function()
                    if targetRock and targetRock.Parent and rootPart and rootPart.Parent then
                        rootPart.CFrame = targetRock.CFrame * CFrame.new(0, 3, 0)
                        rootPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end)
                while AutoMine.IsActive and not AutoMine.IsRockDead(targetRock) do
                    pcall(function()
                        local tool = char:FindFirstChild("Pickaxe") or backpack:FindFirstChild("Pickaxe") or char:FindFirstChild("PremiumPickaxe") or backpack:FindFirstChild("PremiumPickaxe")
                        if tool then
                            if tool.Parent == backpack then tool.Parent = char end
                            MineRemote:FireServer("MineOres", tool, targetRock)
                        end
                    end)
                    task.wait(0.05)
                end
                if AutoMine.LockConnection then AutoMine.LockConnection:Disconnect() AutoMine.LockConnection = nil end
            else task.wait(0.5) end
            task.wait(0.05)
        end
    end)
end

function AutoMine.Stop()
    AutoMine.IsActive = false
    AutoMine.RunningThread = nil
    if AutoMine.LockConnection then AutoMine.LockConnection:Disconnect() AutoMine.LockConnection = nil end
    if AutoMine.NoclipConnection then AutoMine.NoclipConnection:Disconnect() AutoMine.NoclipConnection = nil end
    pcall(function()
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:UnequipTools() end
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and AutoMine.OriginalCollisions[part] ~= nil then part.CanCollide = AutoMine.OriginalCollisions[part] end
            end
        end
        clearFarmTable(AutoMine.OriginalCollisions)
    end)
end

-- Auto Trash
local AutoTrash = { IsActive = false, RunningThread = nil }

function AutoTrash.Start()
    if AutoTrash.IsActive then return end
    AutoTrash.IsActive = true
    AutoTrash.RunningThread = task.spawn(function()
        while AutoTrash.IsActive do
            local char = LocalPlayer.Character
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if char and backpack then
                pcall(function()
                    local trashTool = char:FindFirstChild("SmallTrash") or backpack:FindFirstChild("SmallTrash") or char:FindFirstChild("BigTrash") or backpack:FindFirstChild("BigTrash")
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if trashTool and rootPart and humanoid then
                        local dumpster = Workspace.Map.Cells.Basement["Recyclement Room"].Props["Opened Trash"].Trash
                        rootPart.CFrame = dumpster.CFrame * CFrame.new(0, 2, 0)
                        if not AutoTrash.IsActive then return end
                        task.wait(0.3)
                        if not AutoTrash.IsActive then return end
                        if trashTool.Parent == backpack then humanoid:EquipTool(trashTool) end
                        dumpster.Prompt.Interact.Event:FireServer()
                        if not AutoTrash.IsActive then return end
                        task.wait(0.3)
                    else
                        local activeBin
                        for _, bin in ipairs(TrashesFolder:GetChildren()) do
                            local prompt = bin:FindFirstChild("Prompt")
                            if prompt and prompt:GetAttribute("Enabled") == true then activeBin = bin break end
                        end
                        if activeBin and activeBin.Prompt and rootPart then
                            rootPart.CFrame = activeBin.Prompt.Parent.CFrame * CFrame.new(0, 2, 0)
                            if not AutoTrash.IsActive then return end
                            task.wait(0.3)
                            if not AutoTrash.IsActive then return end
                            activeBin.Prompt.Interact.Event:FireServer()
                            if not AutoTrash.IsActive then return end
                            task.wait(0.5)
                        else task.wait(1) end
                    end
                end)
            end
            if not AutoTrash.IsActive then break end
            task.wait(0.1)
        end
    end)
end

function AutoTrash.Stop()
    AutoTrash.IsActive = false
    AutoTrash.RunningThread = nil
end

local function unlockFists()
    pcall(function()
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quests"):WaitForChild("Pushups"):WaitForChild("Function"):InvokeServer("Submit", 300)
    end)
end

-- Cook & Fishing
local FarmState = { AutoCook = false, AutoFish = false, AutoSell = false, SellInterval = 20 }
local function getRootPart()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 5)
end

local farmSteps = {
    {name = "Cut", cframe = CFrame.new(43.00, 7.54, -298.80), path = "Cut"},
    {name = "Cook", cframe = CFrame.new(37.12, 7.54, -297.77), path = "Cook"},
    {name = "Boil", cframe = CFrame.new(32.07, 7.54, -296.28), path = "Simmer"},
    {name = "Combine", cframe = CFrame.new(41.81, 7.54, -294.10), path = "Assemble"},
    {name = "To take", cframe = CFrame.new(48.75, 7.54, -296.25), path = "Take"},
    {name = "Deposit", cframe = CFrame.new(16.09, 7.54, -314.13), path = "Deposit"}
}

local function checkStep(step)
    local tasks = workspace:FindFirstChild("Tasks")
    if not tasks then return nil end
    local cook = tasks:FindFirstChild("Cook")
    if not cook then return nil end
    local taskObj = cook:FindFirstChild(step.path)
    if not taskObj then return nil end
    local root = taskObj:FindFirstChild("RootPart")
    if not root then return nil end
    local prompt = root:FindFirstChild("Prompt")
    if not prompt then return nil end
    local interact = prompt:FindFirstChild("Interact")
    if not interact then return nil end
    local event = interact:FindFirstChild("Event")
    if not event or not event:IsA("RemoteEvent") then return nil end
    return event
end

task.spawn(function()
    while true do
        if FarmState.AutoCook then
            for index, step in ipairs(farmSteps) do
                if not FarmState.AutoCook then break end
                local rootPart = getRootPart()
                if rootPart then
                    rootPart.CFrame = step.cframe
                    task.wait(0.3)
                    local event = checkStep(step)
                    if event then pcall(function() event:FireServer() end) end
                end
                if index <= 3 then task.wait(10.0) else task.wait(2.0) end
            end
        end
        task.wait(0.5)
    end
end)
-----------------------------------------------------------------------
-- FISHING SYSTEM
-----------------------------------------------------------------------
local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local FishingModules = FishingSystem:WaitForChild("FishingModules")
local MinigameSystem = require(FishingModules:WaitForChild("MinigameSystem"))
local PowerBarSystem = require(FishingModules:WaitForChild("PowerBarSystem"))
local SoundManager = require(FishingModules:WaitForChild("SoundManager"))
local GUIManager = require(FishingModules:WaitForChild("GUIManager"))

local function getRod()
   local character = LocalPlayer.Character
   if character then
       for _, child in ipairs(character:GetChildren()) do
           if child:IsA("Tool") and string.find(string.lower(child.Name), "rod") then return child end
       end
   end
   local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
   if backpack then
       for _, child in ipairs(backpack:GetChildren()) do
           if child:IsA("Tool") and string.find(string.lower(child.Name), "rod") then return child end
       end
   end
   return nil
end

local function getElements()
   local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
   local fishingGui = playerGui and playerGui:FindFirstChild("FishingGui")
   local fishing = fishingGui and fishingGui:FindFirstChild("Fishing")
   local bar = fishing and fishing:FindFirstChild("Bar")
   return bar and bar:FindFirstChild("PlayerZone"), bar and bar:FindFirstChild("FishMarker")
end

local function mouseDown() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0) end
local function mouseUp() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end

local function castRod()
   if PowerBarSystem:IsCharging() then mouseUp() task.wait(0.15) end
   mouseDown()
   local start = os.clock()
   while os.clock() - start < 1.0 do
       RunService.Heartbeat:Wait()
       if PowerBarSystem:IsCharging() then break end
   end
   while os.clock() - start < 5 do
       RunService.Heartbeat:Wait()
       if PowerBarSystem:GetCurrentPower() >= 99.5 then break end
       if not PowerBarSystem:IsCharging() and os.clock() - start > 0.5 then break end
   end
   mouseUp()
end

local lastClick = 0
RunService.Heartbeat:Connect(function()
   if not FarmState.AutoFish then return end
   if not MinigameSystem:IsActive() then return end
   pcall(function()
       local phase = MinigameSystem:GetPhase()
       if phase == "shake" then
           if os.clock() - lastClick > 0.04 then
               MinigameSystem:HandleClick(SoundManager, GUIManager)
               lastClick = os.clock()
           end
       elseif phase == "reel" then
           local zone, marker = getElements()
           if zone and marker then
               local zonePos = zone.Position.X.Scale
               local fishPos = marker.Position.X.Scale
               if fishPos > zonePos + 0.01 then MinigameSystem:SetHolding(true)
               elseif fishPos < zonePos - 0.01 then MinigameSystem:SetHolding(false)
               else MinigameSystem:SetHolding(false) end
           end
       end
   end)
end)

task.spawn(function()
   while true do
       task.wait(0.1)
       if not FarmState.AutoFish then continue end
       local success, err = pcall(function()
           if MinigameSystem:IsActive() then
               while MinigameSystem:IsActive() and FarmState.AutoFish do task.wait(0.1) end
               task.wait(0.5)
           end
           if not FarmState.AutoFish then return end
           local character = LocalPlayer.Character
           local humanoid = character and character:FindFirstChildOfClass("Humanoid")
           if not character or not humanoid or humanoid.Health <= 0 then task.wait(1) return end

           humanoid.WalkSpeed = 0
           pcall(function() humanoid.JumpPower = 0 end)
           pcall(function() humanoid.JumpHeight = 0 end)

           local rod = getRod()
           if not rod then task.wait(1) return end
           if rod.Parent ~= character then humanoid:EquipTool(rod) task.wait(0.8) end
           castRod()
       end)
       if not success then task.wait(1) end
   end
end)

task.spawn(function()
   while true do
       task.wait(FarmState.SellInterval)
       if FarmState.AutoSell then pcall(function() FishingSystem.InventoryEvents.Inventory_SellAll:InvokeServer() end) end
   end
end)

-----------------------------------------------------------------------
-- HELPER FUNCTIONS & UI BUILDING
-----------------------------------------------------------------------
local function safeSetDesc(element, text)
    pcall(function()
        if element and element.SetDesc then
            element:SetDesc(text)
        elseif element and element.SetDescription then
            element:SetDescription(text)
        end
    end)
end

-- TABS
local DashboardTab = Window:Tab({ Title = "Dashboard", Icon = "layout-dashboard" })
local AutoFarmTab  = Window:Tab({ Title = "Auto Farm", Icon = "warehouse" })
local AutoEatTab   = Window:Tab({ Title = "Auto Eat", Icon = "utensils" })
local CombatTab    = Window:Tab({ Title = "Combat", Icon = "swords" })
local ExtraTab     = Window:Tab({ Title = "Extra", Icon = "package-plus" })
local SettingsTab  = Window:Tab({ Title = "Settings", Icon = "settings" })

-- DASHBOARD
local DashSection = DashboardTab:Section({ Title = "Performance & Stats", Icon = "activity", Box = true })

local FpsLabel      = DashSection:Button({ Title = "FPS Rate", Desc = "calculating...", Icon = "gauge" })
local PingLabel     = DashSection:Button({ Title = "MS (Ping)", Desc = "calculating...", Icon = "wifi" })
local HourlyRateBtn = DashSection:Button({ Title = "Hourly Earnings", Desc = "$0 / Hour", Icon = "coins" })
local PlayerLabel   = DashSection:Button({ Title = "Server Players", Desc = "0 / 0", Icon = "users" })
local FriendLabel   = DashSection:Button({ Title = "Active Friends", Desc = "0", Icon = "heart" })

local frameCount, lastTime = 0, os.clock()
RunService.RenderStepped:Connect(function()
    frameCount += 1
    local currentTime = os.clock()
    if currentTime - lastTime >= 1 then
        safeSetDesc(FpsLabel, tostring(frameCount) .. " FPS")
        frameCount = 0
        lastTime = currentTime
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        safeSetDesc(PingLabel, tostring(ping) .. " ms")

        safeSetDesc(HourlyRateBtn, "$" .. tostring(CurrentHourlyRate) .. " / Hour")

        local currentPlayers = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        safeSetDesc(PlayerLabel, currentPlayers .. " / " .. maxPlayers)

        local friendsInServer = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and LocalPlayer:IsFriendsWith(p.UserId) then friendsInServer += 1 end
        end
        safeSetDesc(FriendLabel, tostring(friendsInServer))
    end
end)

DashboardTab:Button({
    Title = "RESET SCRIPT",
    Desc = "Restarts Bytee Hub safely",
    Icon = "refresh-ccw",
    Color = Color3.fromHex("#F44732"),
    Callback = function() print("Reloading UI...") end,
})

DashboardTab:Paragraph({
    Title = "Bytee Hub",
    Desc = "Script is currently in PC optimization. Enjoy full efficiency without lags.",
    Buttons = {
        { Title = "YouTube", Callback = function() if setclipboard then setclipboard("https://youtube.com/@thesyntezys?si=MxwEA0EzAhKy_mQh") end end },
        { Title = "Discord", Variant = "Secondary", Callback = function() if setclipboard then setclipboard("https://discord.gg/rVFTeNfyxC") end end },
    },
})

local DevSection = DashboardTab:Section({ Title = "Development Team", Icon = "users", Box = true })
DevSection:Button({ Title = "Owner", Desc = "Bytecode" })
DevSection:Button({ Title = "Scripters", Desc = "Bytecode, Levis" })
DevSection:Button({ Title = "UI Designer", Desc = "Levis" })
-- AUTO EAT
local EatSection = AutoEatTab:Section({ Title = "Auto Hunger System", Icon = "utensils-crossed", Box = true })
local StatusBtn = EatSection:Button({ Title = "Status", Desc = "Idle", Icon = "info" })

local function setAutoEatStatus(msg)
    AutoEatStatusLabel = msg
    safeSetDesc(StatusBtn, msg)
end

EatSection:Toggle({
    Title = "Enable Auto Eat / Drink",
    Desc = "Watches Hunger/Thirst and auto buys from machines if depleted.",
    Icon = "utensils-crossed",
    Default = false,
    Callback = function(state)
        AutoHungerState.Enabled = state
        if not state then setAutoEatStatus("Idle") end
    end,
})

EatSection:Slider({
    Title = "Eat When Hunger Below",
    Min = 5, Max = 95, Default = 50, Step = 1,
    Callback = function(val) AutoHungerState.EatBelow = val end,
})

EatSection:Slider({
    Title = "Drink When Thirst Below",
    Min = 5, Max = 95, Default = 50, Step = 1,
    Callback = function(val) AutoHungerState.DrinkBelow = val end,
})

-- AUTO FARM
local FarmSection = AutoFarmTab:Section({ Title = "Auto Farm & Cooking", Icon = "chef-hat", Box = true })
FarmSection:Toggle({
    Title = "Auto Cook",
    Default = false,
    Callback = function(state) FarmState.AutoCook = state end,
})

local FishSection = AutoFarmTab:Section({ Title = "Fishing System", Icon = "fish", Box = true })
FishSection:Toggle({
    Title = "Auto Fish",
    Default = false,
    Callback = function(state)
        FarmState.AutoFish = state
        if not state then
            pcall(function() MinigameSystem:SetHolding(false) end)
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
                pcall(function() humanoid.JumpPower = 50 end)
                pcall(function() humanoid.JumpHeight = 7.2 end)
            end
        end
    end,
})

FishSection:Toggle({
    Title = "Auto Sell Fish",
    Default = false,
    Callback = function(state) FarmState.AutoSell = state end,
})

FishSection:Button({
    Title = "Sell All Fish Now",
    Callback = function() pcall(function() FishingSystem.InventoryEvents.Inventory_SellAll:InvokeServer() end) end,
})

FishSection:Button({
    Title = "Teleport to Fishing Area",
    Callback = function()
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local fz = workspace:FindFirstChild("FishingZone")
        if hrp and fz then hrp.CFrame = fz.CFrame + Vector3.new(0, 5, 0) end
    end,
})

local MineSection = AutoFarmTab:Section({ Title = "Mining & Trash", Icon = "pickaxe", Box = true })
MineSection:Toggle({
    Title = "Auto Mine",
    Default = false,
    Callback = function(state) if state then AutoMine.Start() else AutoMine.Stop() end end,
})

MineSection:Toggle({
    Title = "Auto Trash (EXP)",
    Default = false,
    Callback = function(state) if state then AutoTrash.Start() else AutoTrash.Stop() end end,
})

MineSection:Button({
    Title = "Unlock Fists",
    Callback = function() unlockFists() end,
})

local JanitorSection = AutoFarmTab:Section({ Title = "Janitor Farm", Icon = "droplets", Box = true })
local JanitorStatusBtn = JanitorSection:Button({ Title = "Janitor Status", Desc = "idle | Cleaned: 0", Icon = "info" })

local function setJanitorStatus(text) safeSetDesc(JanitorStatusBtn, text) end

JanitorSection:Toggle({
    Title = "Auto Clean Puddles",
    Default = false,
    Callback = function(state)
        farming = state
        if state then
            setJanitorStatus("farming | Cleaned: " .. cleanedCount)
            task.spawn(farmLoop)
        else
            setJanitorStatus("idle | Cleaned: " .. cleanedCount)
        end
    end,
})

-- COMBAT
local CombatSection = CombatTab:Section({ Title = "Aimbot", Icon = "crosshair", Box = true })
CombatSection:Button({
    Title = "LOAD AIMBOT SCRIPT",
    Color = Color3.fromHex("#F44732"),
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Aimbot-Mobile-34677"))()
    end,
})

-- EXTRA
local ESPSection = ExtraTab:Section({ Title = "ESP System", Icon = "eye", Box = true })
local ESPEnabled = false
local ESPConnections = {}

local RoleColors = {
   Murderer = Color3.fromRGB(255, 30, 30),
   Sheriff = Color3.fromRGB(0, 162, 255),
   Civilian = Color3.fromRGB(0, 255, 136),
   Default = Color3.fromRGB(200, 200, 200)
}

local function GetPlayerRoleAndColor(plr)
   if not plr then return "Civilian", RoleColors.Civilian end
   local char = plr.Character
   if char then
      local bp = plr:FindFirstChild("Backpack")
      if bp then
         if bp:FindFirstChild("Knife") or char:FindFirstChild("Knife") then return "Murderer", RoleColors.Murderer end
         if bp:FindFirstChild("Gun") or char:FindFirstChild("Gun") then return "Sheriff", RoleColors.Sheriff end
      end
   end
   return "Civilian", RoleColors.Civilian
end

local function RemoveESPForPlayer(plr)
   if ESPConnections[plr] then ESPConnections[plr]:Disconnect() ESPConnections[plr] = nil end
   if plr.Character then
      if plr.Character:FindFirstChild("ESPGlow") then plr.Character.ESPGlow:Destroy() end
      if plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character.HumanoidRootPart:FindFirstChild("ESPBillboard") then
         plr.Character.HumanoidRootPart.ESPBillboard:Destroy()
      end
   end
end

local function ApplyESP(plr)
   if plr == LocalPlayer then return end
   RemoveESPForPlayer(plr)

   local function CreateGlowAndTag()
      local char = plr.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      local hrp = char and char:FindFirstChild("HumanoidRootPart")

      if char and hum and hrp then
         local roleName, roleColor = GetPlayerRoleAndColor(plr)

         local highlight = Instance.new("Highlight")
         highlight.Name = "ESPGlow"
         highlight.FillTransparency = 0.8
         highlight.FillColor = roleColor
         highlight.OutlineColor = roleColor
         highlight.Parent = char

         local bb = Instance.new("BillboardGui")
         bb.Name = "ESPBillboard"
         bb.Size = UDim2.new(0, 160, 0, 50)
         bb.StudsOffset = Vector3.new(0, 3.5, 0)
         bb.AlwaysOnTop = true
         bb.Adornee = hrp

         local txt = Instance.new("TextLabel")
         txt.Size = UDim2.new(1, 0, 0, 25)
         txt.BackgroundTransparency = 1
         txt.TextColor3 = roleColor
         txt.TextSize = 11
         txt.Font = Enum.Font.SourceSansBold
         txt.Parent = bb
         bb.Parent = hrp

         local renderConn = RunService.RenderStepped:Connect(function()
            if ESPEnabled and LocalPlayer.Character and hrp and hrp.Parent and hum and hum.Health > 0 then
               local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
               txt.Text = plr.Name .. " (" .. dist .. "m)"
            else
               RemoveESPForPlayer(plr)
            end
         end)
         ESPConnections[plr] = renderConn
      end
   end

   if plr.Character then CreateGlowAndTag() end
end

ESPSection:Toggle({
   Title = "Role + Glow ESP",
   Default = false,
   Callback = function(Value)
      ESPEnabled = Value
      if ESPEnabled then
         for _, plr in pairs(Players:GetPlayers()) do ApplyESP(plr) end
      else
         for plr, conn in pairs(ESPConnections) do if conn then conn:Disconnect() end end
         ESPConnections = {}
         for _, plr in pairs(Players:GetPlayers()) do RemoveESPForPlayer(plr) end
      end
   end,
})

-- SETTINGS
local SetSection = SettingsTab:Section({ Title = "Exploit & Utility Settings", Icon = "settings", Box = true })
local AntiAfkConn = nil
SetSection:Toggle({
    Title = "Anti AFK (Prevent Kick)",
    Default = false,
    Callback = function(state)
        if state then
            if not AntiAfkConn then
                AntiAfkConn = LocalPlayer.Idled:Connect(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        else
            if AntiAfkConn then AntiAfkConn:Disconnect() AntiAfkConn = nil end
        end
    end,
})

local ScaleSection = SettingsTab:Section({ Title = "UI Scale Size", Icon = "maximize", Box = true })
ScaleSection:Dropdown({
    Title = "Select UI Scale",
    Values = {"Small", "Normal", "Large"},
    Default = "Large",
    Callback = function(Value)
        if Value == "Small" then Window:Size(UDim2.fromOffset(700, 500), true)
        elseif Value == "Large" then Window:Size(UDim2.fromOffset(1000, 700), true)
        else Window:Size(UDim2.fromOffset(900, 600), true) end
    end,
})
