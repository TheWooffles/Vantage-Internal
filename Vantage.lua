--// Services & Variables
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera 
local Mouse = LocalPlayer:GetMouse()

--// Configuration
local Config = {
    Whitelist = {
        Enabled = true,
        Players = {"ggtm"}, -- Add display names here (case-sensitive)
    },
    MouseLock = {
        Enabled = false,
        Keybind = Enum.KeyCode.RightBracket,
        Smoothness = 0,
        Prediction = 0,
        AutoPrediction = false,
        TeamCheck = false,
        WallCheck = false,
        TargetPart = "Head", -- "Head", "HumanoidRootPart", "UpperTorso"
    },
    
    TriggerBot = {
        Enabled = false,
        Keybind = Enum.KeyCode.T,
        Delay = 0,
        HitChance = 100,
        AutoShoot = true,
        TeamCheck = true,
        WallCheck = true,
        UsePrediction = true, -- Aim at predicted position
    },
    
    -- Visual Settings
    Visuals = {
        CustomCursor = false,
        CursorSize = 5,
        CursorColor = Color3.fromRGB(255, 255, 255),
        CursorTransparency = 0.5,
        
        -- Target Highlight
        ShowHighlight = true,
        HighlightColor = Color3.fromRGB(255, 50, 50),
        HighlightTransparency = 0.5,
    },
    
    -- ESP Settings
    ESP = {
        Enabled = true,
        Keybind = Enum.KeyCode.E,
        ShowName = true,
        ShowHealth = true,
        ShowDistance = true,
        MaxDistance = 500, -- Max render distance for performance
        TeamCheck = false,
        ShowTeammates = false,
        
        -- Colors
        NameColor = Color3.fromRGB(255, 255, 255),
        HealthBarOutline = Color3.fromRGB(0, 0, 0),
        DistanceColor = Color3.fromRGB(200, 200, 200),
        
        -- Fonts & Sizes
        TextSize = 14,
        HealthBarWidth = 100,
        HealthBarHeight = 6,
    },
}

--// Variables
local targetPlayer = nil
local drawings = {}
local connections = {}
local triggerBotActive = false
local lastShootTime = 0
local MousePos = Vector2.new(0, 0)
local targetHighlight = nil
local lastTargetNotification = nil
local espCache = {}
local espUpdateRate = 0.1 -- Update ESP every 0.1 seconds for performance
local lastEspUpdate = 0

--// Notification System
local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "VantageNotifications"
NotificationGui.ResetOnSpawn = false
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "Container"
NotificationContainer.Size = UDim2.new(0, 300, 1, -50)
NotificationContainer.Position = UDim2.new(0.5, -150, 0, 10)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = NotificationGui

local activeNotifications = {}

local function CreateNotification(message, duration)
    duration = duration or 3
    
    local notifFrame = Instance.new("Frame")
    notifFrame.Size = UDim2.new(1, 0, 0, 35)
    notifFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    notifFrame.BorderSizePixel = 0
    notifFrame.ClipsDescendants = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notifFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 2
    stroke.Parent = notifFrame
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.RichText = true
    textLabel.Text = '<font color="rgb(255, 50, 50)">[Vantage]</font> : ' .. message
    textLabel.Parent = notifFrame
    
    -- Insert notification at the top
    table.insert(activeNotifications, 1, notifFrame)
    notifFrame.Parent = NotificationContainer
    
    -- Reposition all notifications
    for i, notif in ipairs(activeNotifications) do
        notif.Position = UDim2.new(0, 0, 0, -50)
        notif.Size = UDim2.new(1, 0, 0, 0)
        
        local slideIn = TweenService:Create(
            notif,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 0, 0, (i - 1) * 40), Size = UDim2.new(1, 0, 0, 35)}
        )
        slideIn:Play()
    end
    
    -- Auto remove after duration
    task.delay(duration, function()
        local index = table.find(activeNotifications, notifFrame)
        if index then
            table.remove(activeNotifications, index)
            
            -- Fade out
            local fadeOut = TweenService:Create(
                notifFrame,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.new(0, 0, 0, notifFrame.Position.Y.Offset), Size = UDim2.new(1, 0, 0, 0)}
            )
            
            local fadeStroke = TweenService:Create(
                stroke,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Transparency = 1}
            )
            
            local fadeText = TweenService:Create(
                textLabel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 1}
            )
            
            fadeOut:Play()
            fadeStroke:Play()
            fadeText:Play()
            
            fadeOut.Completed:Connect(function()
                notifFrame:Destroy()
                
                -- Reposition remaining notifications
                for i, notif in ipairs(activeNotifications) do
                    local reposition = TweenService:Create(
                        notif,
                        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        {Position = UDim2.new(0, 0, 0, (i - 1) * 40)}
                    )
                    reposition:Play()
                end
            end)
        end
    end)
end

-- Parent to CoreGui or PlayerGui
pcall(function()
    NotificationGui.Parent = game:GetService("CoreGui")
end)
if not NotificationGui.Parent then
    NotificationGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

--// Custom Cursor
if Config.Visuals.CustomCursor then
    drawings.Cursor = Drawing.new("Circle")
    drawings.Cursor.Position = Vector2.new(0, 0)
    drawings.Cursor.Visible = true
    drawings.Cursor.Radius = Config.Visuals.CursorSize
    drawings.Cursor.Transparency = Config.Visuals.CursorTransparency
    drawings.Cursor.Filled = true
    drawings.Cursor.Color = Config.Visuals.CursorColor
    
    UserInputService.MouseIcon = 'http://www.roblox.com/asset?id=4882930015'
end

--// Highlight System
local function createHighlight(character)
    if targetHighlight then
        targetHighlight:Destroy()
        targetHighlight = nil
    end
    
    if not Config.Visuals.ShowHighlight then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "VantageTargetHighlight"
    highlight.Adornee = character
    highlight.FillColor = Config.Visuals.HighlightColor
    highlight.FillTransparency = Config.Visuals.HighlightTransparency
    highlight.OutlineColor = Config.Visuals.HighlightColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    pcall(function()
        highlight.Parent = game:GetService("CoreGui")
    end)
    if not highlight.Parent then
        highlight.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    targetHighlight = highlight
end

local function removeHighlight()
    if targetHighlight then
        targetHighlight:Destroy()
        targetHighlight = nil
    end
end

--// ESP System
local function createESP(player)
    if espCache[player] then return end
    
    local espData = {
        player = player,
        drawings = {},
        lastUpdate = 0,
        isVisible = false
    }
    
    -- Name text
    if Config.ESP.ShowName then
        local nameText = Drawing.new("Text")
        nameText.Visible = false
        nameText.Center = true
        nameText.Outline = true
        nameText.Size = Config.ESP.TextSize
        nameText.Color = Config.ESP.NameColor
        nameText.Font = 2
        espData.drawings.nameText = nameText
    end
    
    -- Distance text
    if Config.ESP.ShowDistance then
        local distText = Drawing.new("Text")
        distText.Visible = false
        distText.Center = true
        distText.Outline = true
        distText.Size = Config.ESP.TextSize - 2
        distText.Color = Config.ESP.DistanceColor
        distText.Font = 2
        espData.drawings.distText = distText
    end
    
    -- Health bar
    if Config.ESP.ShowHealth then
        -- Background/Outline
        local healthBg = Drawing.new("Square")
        healthBg.Visible = false
        healthBg.Filled = false
        healthBg.Thickness = 2
        healthBg.Color = Config.ESP.HealthBarOutline
        espData.drawings.healthBg = healthBg
        
        -- Health fill
        local healthFill = Drawing.new("Square")
        healthFill.Visible = false
        healthFill.Filled = true
        healthFill.Thickness = 1
        espData.drawings.healthFill = healthFill
    end
    
    espCache[player] = espData
end

local function updateESP(player, espData)
    if not Config.ESP.Enabled then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    local char = player.Character
    if not char then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    -- Whitelist check
    if isWhitelisted(player) then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    -- Team check
    if Config.ESP.TeamCheck and not Config.ESP.ShowTeammates then
        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            for _, drawing in pairs(espData.drawings) do
                drawing.Visible = false
            end
            espData.isVisible = false
            return
        end
    end
    
    -- Distance check
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > Config.ESP.MaxDistance then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    -- Get head position for ESP
    local head = char:FindFirstChild("Head")
    if not head then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    local headPos = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.5, 0)
    local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
    
    if not onScreen then
        for _, drawing in pairs(espData.drawings) do
            drawing.Visible = false
        end
        espData.isVisible = false
        return
    end
    
    espData.isVisible = true
    local yOffset = 0
    
    -- Update name
    if Config.ESP.ShowName and espData.drawings.nameText then
        espData.drawings.nameText.Position = Vector2.new(screenPos.X, screenPos.Y + yOffset)
        espData.drawings.nameText.Text = player.DisplayName
        espData.drawings.nameText.Visible = true
        yOffset = yOffset + Config.ESP.TextSize + 2
    end
    
    -- Update distance
    if Config.ESP.ShowDistance and espData.drawings.distText then
        espData.drawings.distText.Position = Vector2.new(screenPos.X, screenPos.Y + yOffset)
        espData.drawings.distText.Text = string.format("[%dm]", math.floor(distance))
        espData.drawings.distText.Visible = true
        yOffset = yOffset + (Config.ESP.TextSize - 2) + 2
    end
    
    -- Update health bar
    if Config.ESP.ShowHealth and espData.drawings.healthBg and espData.drawings.healthFill then
        local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        
        -- Calculate health color (green -> yellow -> red)
        local healthColor
        if healthPercent > 0.5 then
            healthColor = Color3.new(1 - (healthPercent - 0.5) * 2, 1, 0)
        else
            healthColor = Color3.new(1, healthPercent * 2, 0)
        end
        
        local barX = screenPos.X - Config.ESP.HealthBarWidth / 2
        local barY = screenPos.Y + yOffset
        
        -- Background
        espData.drawings.healthBg.Size = Vector2.new(Config.ESP.HealthBarWidth, Config.ESP.HealthBarHeight)
        espData.drawings.healthBg.Position = Vector2.new(barX, barY)
        espData.drawings.healthBg.Visible = true
        
        -- Fill
        local fillWidth = (Config.ESP.HealthBarWidth - 4) * healthPercent
        espData.drawings.healthFill.Size = Vector2.new(math.max(fillWidth, 1), Config.ESP.HealthBarHeight - 4)
        espData.drawings.healthFill.Position = Vector2.new(barX + 2, barY + 2)
        espData.drawings.healthFill.Color = healthColor
        espData.drawings.healthFill.Visible = true
    end
end

local function removeESP(player)
    local espData = espCache[player]
    if espData then
        for _, drawing in pairs(espData.drawings) do
            drawing:Remove()
        end
        espCache[player] = nil
    end
end

local function cleanupESP()
    for player, espData in pairs(espCache) do
        if not player or not player.Parent or not Players:FindFirstChild(player.Name) then
            removeESP(player)
        end
    end
end

--// Helper Functions
local function isWhitelisted(player)
    if not Config.Whitelist.Enabled then return false end
    
    for _, whitelistedName in ipairs(Config.Whitelist.Players) do
        if player.DisplayName == whitelistedName or player.Name == whitelistedName then
            return true
        end
    end
    
    return false
end

local function isPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function predictPosition(pos, vel, dist)
    if Config.MouseLock.AutoPrediction and dist then
        return pos + (vel * (dist / 500))
    elseif Config.MouseLock.Prediction and Config.MouseLock.Prediction > 0 then
        return pos + (vel * Config.MouseLock.Prediction)
    end
    return pos
end

local function isTargetVisible(targetPart, targetCharacter)
    if not Config.MouseLock.WallCheck then
        return true
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    local filterList = {LocalPlayer.Character, targetCharacter}
    
    -- Ignore all player characters in wall check
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    return rayResult == nil
end

local function getClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerAlive(player) then
            -- Whitelist check
            if isWhitelisted(player) then
                continue
            end
            
            -- Team check
            if Config.MouseLock.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end
            
            local targetPart = player.Character:FindFirstChild(Config.MouseLock.TargetPart) or player.Character:FindFirstChild("Head")
            
            if targetPart then
                local partPos = targetPart.Position
                local screenPos, onScreen = Camera:WorldToScreenPoint(partPos)
                
                if onScreen then
                    local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
                    local distanceFromMouse = (MousePos - screenPosVec).Magnitude
                    
                    if isTargetVisible(targetPart, player.Character) then
                        if distanceFromMouse < shortestDistance then
                            shortestDistance = distanceFromMouse
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function isPlayerInCrosshair()
    if not LocalPlayer.Character or not isPlayerAlive(LocalPlayer) then return false, nil end
    
    local ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if result and result.Instance then
        local hitPart = result.Instance
        local targetChar = hitPart:FindFirstAncestorOfClass("Model")

        if targetChar then
            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)

            if targetPlayer and targetPlayer ~= LocalPlayer and isPlayerAlive(targetPlayer) then
                -- Whitelist check
                if isWhitelisted(targetPlayer) then
                    return false, nil
                end
                
                -- Team check
                if Config.TriggerBot.TeamCheck and targetPlayer.Team and LocalPlayer.Team and targetPlayer.Team == LocalPlayer.Team then
                    return false, nil
                end

                -- Wall check (ignore players)
                if Config.TriggerBot.WallCheck then
                    local directRayParams = RaycastParams.new()
                    local filterList = {LocalPlayer.Character}
                    
                    -- Ignore all player characters
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Character then
                            table.insert(filterList, player.Character)
                        end
                    end
                    
                    directRayParams.FilterDescendantsInstances = filterList
                    directRayParams.FilterType = Enum.RaycastFilterType.Exclude
                    
                    local origin = Camera.CFrame.Position
                    local direction = (hitPart.Position - origin).Unit * (hitPart.Position - origin).Magnitude
                    local directResult = workspace:Raycast(origin, direction, directRayParams)
                    
                    if directResult then
                        return false, nil
                    end
                end
                
                -- Hit chance check
                if math.random(1, 100) <= Config.TriggerBot.HitChance then
                    return true, targetPlayer
                end
            end
        end
    end
    
    return false, nil
end

local function TriggerShoot()
    if not Config.TriggerBot.AutoShoot then return end
    local currentTime = tick()
    if currentTime - lastShootTime < Config.TriggerBot.Delay then
        return
    end
    lastShootTime = currentTime
    
    pcall(function()
        mouse1click()
    end)
    
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
            end
        end
    end)
end

--// Main Loops
connections.RenderMouse = RunService.RenderStepped:Connect(function()
    MousePos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    
    if Config.Visuals.CustomCursor and drawings.Cursor then
        drawings.Cursor.Position = MousePos
    end
end)

connections.ESPUpdate = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    
    -- Rate limit ESP updates for performance
    if currentTime - lastEspUpdate < espUpdateRate then
        return
    end
    lastEspUpdate = currentTime
    
    -- Create ESP for new players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not espCache[player] then
                createESP(player)
            end
        end
    end
    
    -- Update existing ESP
    for player, espData in pairs(espCache) do
        updateESP(player, espData)
    end
    
    -- Cleanup invalid ESP
    cleanupESP()
end)

connections.MouseLock = RunService.RenderStepped:Connect(function()
    if not isPlayerAlive(LocalPlayer) then
        targetPlayer = nil
        removeHighlight()
        return
    end
    
    if Config.MouseLock.Enabled then
        local newTarget = getClosestPlayerToMouse()
        
        if newTarget and newTarget ~= targetPlayer then
            targetPlayer = newTarget
            
            -- Show notification for new target
            if lastTargetNotification ~= targetPlayer.DisplayName then
                CreateNotification('Locked: ' .. targetPlayer.DisplayName, 2)
                lastTargetNotification = targetPlayer.DisplayName
            end
            
            -- Create highlight
            if targetPlayer.Character then
                createHighlight(targetPlayer.Character)
            end
        elseif not newTarget and targetPlayer then
            targetPlayer = nil
            lastTargetNotification = nil
            removeHighlight()
            CreateNotification('Target Lost', 1.5)
        end
        
        if targetPlayer and targetPlayer.Character then
            local targetPart = targetPlayer.Character:FindFirstChild(Config.MouseLock.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
            
            if targetPart then
                local partPos = targetPart.Position
                local velocity = Vector3.new(0, 0, 0)
                
                if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = targetPlayer.Character.HumanoidRootPart
                    velocity = hrp.Velocity or hrp.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
                end
                
                local distance = (partPos - Camera.CFrame.Position).Magnitude
                local predictedPos = predictPosition(partPos, velocity, distance)
                
                local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)

                if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                    
                    local smoothPos = mousePos:Lerp(targetPos, math.clamp(Config.MouseLock.Smoothness, 0, 1))
                    local delta = smoothPos - mousePos
                    
                    mousemoverel(delta.X, delta.Y)
                end
            end
        end
    else
        if targetPlayer then
            targetPlayer = nil
            lastTargetNotification = nil
            removeHighlight()
        end
    end
end)

connections.TriggerBot = RunService.RenderStepped:Connect(function()
    if triggerBotActive and Config.TriggerBot.Enabled then
        local hasTarget, target = isPlayerInCrosshair()
        if hasTarget then
            TriggerShoot()
        end
    end
end)

--// Input Handler
connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Config.MouseLock.Keybind then
        Config.MouseLock.Enabled = not Config.MouseLock.Enabled
        local status = Config.MouseLock.Enabled and 'Enabled' or 'Disabled'
        CreateNotification('Mouse Lock ' .. status, 2)
        
        if not Config.MouseLock.Enabled then
            targetPlayer = nil
            lastTargetNotification = nil
            removeHighlight()
        end
    end
    
    if input.KeyCode == Config.TriggerBot.Keybind then
        triggerBotActive = not triggerBotActive
        Config.TriggerBot.Enabled = triggerBotActive
        local status = triggerBotActive and 'Active' or 'Inactive'
        CreateNotification('Trigger Bot ' .. status, 2)
    end
    
    if input.KeyCode == Config.ESP.Keybind then
        Config.ESP.Enabled = not Config.ESP.Enabled
        local status = Config.ESP.Enabled and 'Enabled' or 'Disabled'
        CreateNotification('ESP ' .. status, 2)
        
        if not Config.ESP.Enabled then
            for _, espData in pairs(espCache) do
                for _, drawing in pairs(espData.drawings) do
                    drawing.Visible = false
                end
            end
        end
    end
end)

--// Player event handlers
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        task.wait(0.5) -- Small delay to ensure character loads
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

--// Cleanup on character death
LocalPlayer.CharacterAdded:Connect(function()
    targetPlayer = nil
    lastTargetNotification = nil
    removeHighlight()
end)

--// Unload Function
_G.UnloadVantage = function()
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    for _, drawing in pairs(drawings) do
        drawing:Destroy()
    end
    for player, _ in pairs(espCache) do
        removeESP(player)
    end
    if NotificationGui then
        NotificationGui:Destroy()
    end
    removeHighlight()
    UserInputService.MouseIcon = ''
    print("[Vantage] :: Unloaded!")
end

_G.VantageConfig = Config

--// Initialization
CreateNotification('Loaded Successfully', 3)
CreateNotification('Press ' .. Config.MouseLock.Keybind.Name .. ' to Toggle Aim Lock', 3)
CreateNotification('Press ' .. Config.TriggerBot.Keybind.Name .. ' to Toggle Trigger Bot', 3)
CreateNotification('Press ' .. Config.ESP.Keybind.Name .. ' to Toggle ESP', 3)

if Config.Whitelist.Enabled and #Config.Whitelist.Players > 0 then
    CreateNotification('Whitelist Active: ' .. #Config.Whitelist.Players .. ' player(s)', 3)
end

-- Initialize ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

print("[Vantage] :: Loaded Successfully!")