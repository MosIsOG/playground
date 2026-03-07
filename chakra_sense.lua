-- ==================== LEADERBOARD CLICK DETECTOR + SPECTATE ====================
-- Detects clicks on player names in the leaderboard and spectates them
-- Standalone script

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Store original camera settings
local originalCameraSubject = nil
local isSpectating = false
local spectatedCharacter = nil
local spectatedCharacterName = nil
local healthConnection = nil
local lastHealth = nil

-- Forward declarations
local stopSpectating

-- Function to monitor LocalPlayer health for damage
local function setupHealthMonitor()
    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    lastHealth = humanoid.Health
    
    healthConnection = humanoid.HealthChanged:Connect(function(newHealth)
        if isSpectating and newHealth < lastHealth then
            stopSpectating()
        end
        lastHealth = newHealth
    end)
end

-- Function to spectate a character
local function spectateCharacter(characterName)
    local character = Workspace:FindFirstChild(characterName)
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not humanoidRootPart then return false end
    
    if not isSpectating then
        originalCameraSubject = Camera.CameraSubject
    end
    
    Camera.CameraSubject = humanoid
    isSpectating = true
    spectatedCharacter = character
    spectatedCharacterName = characterName
    
    setupHealthMonitor()
    
    return true
end

-- Function to stop spectating and return to own character
stopSpectating = function()
    if isSpectating and originalCameraSubject then
        Camera.CameraSubject = originalCameraSubject
        isSpectating = false
        spectatedCharacter = nil
        spectatedCharacterName = nil
        
        if healthConnection then
            healthConnection:Disconnect()
            healthConnection = nil
        end
    end
end

-- Main function to setup leaderboard click detection
local function setupLeaderboardClickDetector()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local clientGui = playerGui:WaitForChild("ClientGui", 10)
    if not clientGui then return end
    
    local mainframe = clientGui:WaitForChild("Mainframe", 10)
    if not mainframe then return end
    
    local playerList = mainframe:WaitForChild("PlayerList", 10)
    if not playerList then return end
    
    local list = playerList:WaitForChild("List", 10)
    if not list then return end
    
    -- Function to setup click detection for a PlayerTemplate
    local function setupPlayerTemplate(template)
        if template:IsA("GuiObject") and template.Name == "PlayerTemplate" then
            -- Check if already set up (prevent duplicates)
            if template:FindFirstChild("SpectateClickSetup") then return end
            
            local playerName = template:FindFirstChild("PlayerName")
            if playerName and playerName:IsA("TextLabel") then
                -- Mark as set up
                local marker = Instance.new("BoolValue")
                marker.Name = "SpectateClickSetup"
                marker.Parent = template
                
                template.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local characterName = playerName.Text
                        
                        if isSpectating and spectatedCharacterName == characterName then
                            stopSpectating()
                        else
                            spectateCharacter(characterName)
                        end
                    end
                end)
            end
        end
    end
    
    -- Setup existing templates
    for _, child in pairs(list:GetChildren()) do
        setupPlayerTemplate(child)
    end
    
    -- Setup new templates as they're added
    list.ChildAdded:Connect(setupPlayerTemplate)
end

-- Monitor if spectated character is removed/dies
task.spawn(function()
    while true do
        if isSpectating and spectatedCharacter and not spectatedCharacter.Parent then
            stopSpectating()
        end
        task.wait(1)
    end
end)

-- Setup health monitor when character spawns
LocalPlayer.CharacterAdded:Connect(function()
    if isSpectating then
        task.wait(0.5)
        setupHealthMonitor()
    end
    
    -- Re-setup leaderboard click detector after respawn
    task.wait(1) -- Wait for GUI to fully load
    setupLeaderboardClickDetector()
end)

-- Initialize the detector
task.spawn(setupLeaderboardClickDetector)

-- ==================== SERVER NAME DISPLAY WITH CONFIGURATION GUI ====================
task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local clientGui = playerGui:WaitForChild("ClientGui", 10)
    if not clientGui then return end
    
    local mainframe = clientGui:WaitForChild("Mainframe", 10)
    if not mainframe then return end
    
    local rest = mainframe:WaitForChild("Rest", 10)
    if not rest then return end
    
    local mainMenuFrame = rest:WaitForChild("MainMenuFrame", 10)
    if not mainMenuFrame then return end
    
    local serverNameLabel = mainMenuFrame:WaitForChild("ServerName", 10)
    if not serverNameLabel then return end
    
    -- Create ScreenGui for display
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerNameDisplay"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create black shadow/outline TextLabel
    local shadowLabel = Instance.new("TextLabel")
    shadowLabel.Name = "ShadowLabel"
    shadowLabel.Size = UDim2.new(0, 300, 0, 30)
    shadowLabel.Position = UDim2.new(0, 352, 0, -31)
    shadowLabel.BackgroundTransparency = 1
    shadowLabel.BorderSizePixel = 0
    shadowLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    shadowLabel.TextSize = 16
    shadowLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    shadowLabel.TextXAlignment = Enum.TextXAlignment.Left
    shadowLabel.TextYAlignment = Enum.TextYAlignment.Top
    shadowLabel.Text = serverNameLabel.Text
    shadowLabel.ZIndex = 1
    shadowLabel.Parent = screenGui
    
    -- Create white main TextLabel
    local displayLabel = Instance.new("TextLabel")
    displayLabel.Name = "ServerLabel"
    displayLabel.Size = UDim2.new(0, 300, 0, 30)
    displayLabel.Position = UDim2.new(0, 351, 0, -32)
    displayLabel.BackgroundTransparency = 1
    displayLabel.BorderSizePixel = 0
    displayLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    displayLabel.TextSize = 16
    displayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    displayLabel.TextXAlignment = Enum.TextXAlignment.Left
    displayLabel.TextYAlignment = Enum.TextYAlignment.Top
    displayLabel.Text = serverNameLabel.Text
    displayLabel.ZIndex = 2
    displayLabel.Parent = screenGui
    
    -- Update if server name changes
    serverNameLabel:GetPropertyChangedSignal("Text"):Connect(function()
        displayLabel.Text = serverNameLabel.Text
        shadowLabel.Text = serverNameLabel.Text
    end)
end)
