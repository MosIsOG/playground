-- Animation Fetcher & Player Tool
print("Loading Animation Tool...")

-- Load LinoriaLib
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Create window
local Window = Library:CreateWindow({
    Title = "Animation Tool",
    Center = true,
    AutoShow = true
})

-- Create tabs
local Tabs = {
    Fetcher = Window:AddTab("Animation Fetcher"),
    Player = Window:AddTab("Animation Player"),
    Misc = Window:AddTab("Misc"),
    Settings = Window:AddTab("Settings")
}

-- ==================== ANIMATION FETCHER ====================
local AnimFetcher = {
    Enabled = false,
    MobEnabled = false,
    MaxDistance = 50,
    Connections = {},
    MobConnections = {},
    NotificationCooldowns = {}, -- Prevent spam: key = player/model name, value = last notif time
    CooldownTime = 0.5, -- seconds between notifications per entity
}

local function GetDistanceToPlayer(player)
    local localChar = LocalPlayer.Character
    local targetChar = player.Character
    if not localChar or not targetChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
    if not localRoot or not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function GetDistanceToModel(model)
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return nil end
    local targetRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function MonitorPlayerAnim(player, character)
    if not character or player == LocalPlayer then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AnimFetcher.Enabled then return end
        
        -- Cooldown check to prevent spam
        local now = tick()
        local lastNotif = AnimFetcher.NotificationCooldowns[player.Name]
        if lastNotif and (now - lastNotif) < AnimFetcher.CooldownTime then
            return -- Skip this notification
        end
        
        local distance = GetDistanceToPlayer(player)
        if not distance or distance > AnimFetcher.MaxDistance then return end
        
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        
        AnimFetcher.NotificationCooldowns[player.Name] = now
        Library:Notify(string.format("[%d studs] %s: %s", math.floor(distance), player.Name, assetId), 5)
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    if not AnimFetcher.Connections[player] then AnimFetcher.Connections[player] = {} end
    table.insert(AnimFetcher.Connections[player], conn)
end

-- Monitor a mob/NPC model for animations
local function MonitorMobAnim(model)
    if not model or not model.Parent then return end
    if AnimFetcher.MobConnections[model] then return end -- already monitoring
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AnimFetcher.MobEnabled then return end
        
        -- Cooldown check
        local now = tick()
        local key = tostring(model)
        local lastNotif = AnimFetcher.NotificationCooldowns[key]
        if lastNotif and (now - lastNotif) < AnimFetcher.CooldownTime then
            return
        end
        
        local distance = GetDistanceToModel(model)
        if not distance or distance > AnimFetcher.MaxDistance then return end
        
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        
        AnimFetcher.NotificationCooldowns[key] = now
        Library:Notify(string.format("[MOB %d studs] %s: %s", math.floor(distance), model.Name, assetId), 5)
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    AnimFetcher.MobConnections[model] = {conn}
end

-- Event-based mob detection (much more efficient than polling)
local MobDetectionConnection = nil

local function StartMobDetection()
    if MobDetectionConnection then return end
    
    -- Monitor new descendants being added to workspace
    MobDetectionConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if not AnimFetcher.MobEnabled then return end
        
        -- Check if it's a humanoid
        if descendant:IsA("Humanoid") and descendant.Parent then
            local model = descendant.Parent
            
            -- Skip if it's a player character
            local player = Players:GetPlayerFromCharacter(model)
            if player then return end
            
            -- Wait for animator to load
            task.wait(0.1)
            MonitorMobAnim(model)
        end
    end)
    
    -- Also scan existing mobs once (optimized)
    task.spawn(function()
        local localChar = LocalPlayer.Character
        if not localChar then return end
        
        for _, model in pairs(Workspace:GetChildren()) do
            if AnimFetcher.MobEnabled and model:FindFirstChildOfClass("Humanoid") then
                local player = Players:GetPlayerFromCharacter(model)
                if not player then
                    local dist = GetDistanceToModel(model)
                    if dist and dist <= AnimFetcher.MaxDistance * 2 then -- Scan wider initially
                        MonitorMobAnim(model)
                    end
                end
            end
        end
    end)
end

local function StopMobDetection()
    if MobDetectionConnection then
        MobDetectionConnection:Disconnect()
        MobDetectionConnection = nil
    end
    
    -- Clean up all mob connections
    for model, conns in pairs(AnimFetcher.MobConnections) do
        for _, c in ipairs(conns) do
            pcall(function() c:Disconnect() end)
        end
    end
    AnimFetcher.MobConnections = {}
end

-- Periodic cleanup of dead mob connections (every 30 seconds)
task.spawn(function()
    while true do
        task.wait(30)
        for model, conns in pairs(AnimFetcher.MobConnections) do
            if not model or not model.Parent then
                for _, c in ipairs(conns) do
                    pcall(function() c:Disconnect() end)
                end
                AnimFetcher.MobConnections[model] = nil
            end
        end
    end
end)

-- Initialize existing players (optimized)
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(char)
            task.wait(0.3)
            MonitorPlayerAnim(player, char)
        end)
        if player.Character then
            task.spawn(function()
                MonitorPlayerAnim(player, player.Character)
            end)
        end
    end
end

-- New players
Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        MonitorPlayerAnim(player, char)
    end)
    if player.Character then
        task.spawn(function()
            MonitorPlayerAnim(player, player.Character)
        end)
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if AnimFetcher.Connections[player] then
        for _, conn in pairs(AnimFetcher.Connections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        AnimFetcher.Connections[player] = nil
    end
    AnimFetcher.NotificationCooldowns[player.Name] = nil
end)

-- ==================== FETCHER UI ====================
local FetcherGroup = Tabs.Fetcher:AddLeftGroupbox("Player Animation Fetcher")

FetcherGroup:AddToggle("AnimFetcherToggle", {
    Text = "Enable Animation Logging",
    Default = false,
    Callback = function(value)
        AnimFetcher.Enabled = value
        if value then
            Library:Notify("Animation Fetcher enabled", 2)
        else
            Library:Notify("Animation Fetcher disabled", 2)
        end
    end
}):AddKeyPicker("AnimFetcherKey", {
    Default = "F1",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Animation Fetcher"
})

FetcherGroup:AddSlider("AnimFetcherDistance", {
    Text = "Max Detection Distance",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(value)
        AnimFetcher.MaxDistance = value
    end
})

FetcherGroup:AddLabel("Logs animations from players within range.")
FetcherGroup:AddLabel("Animation IDs appear in notifications.")

local MobGroup = Tabs.Fetcher:AddRightGroupbox("NPC/Mob Animation Fetcher")

MobGroup:AddToggle("AnimFetcherMobToggle", {
    Text = "Enable Mob Logging",
    Default = false,
    Callback = function(value)
        AnimFetcher.MobEnabled = value
        if value then
            StartMobDetection()
            Library:Notify("Mob Animation Fetcher enabled", 2)
        else
            StopMobDetection()
            Library:Notify("Mob Animation Fetcher disabled", 2)
        end
    end
}):AddKeyPicker("AnimFetcherMobKey", {
    Default = "F2",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Mob Fetcher"
})

MobGroup:AddSlider("NotificationCooldown", {
    Text = "Notification Cooldown",
    Default = 0.5,
    Min = 0.1,
    Max = 3,
    Rounding = 1,
    Suffix = " seconds",
    Callback = function(value)
        AnimFetcher.CooldownTime = value
    end
})

MobGroup:AddLabel("Scans for NPCs/Mobs and logs their animations.")
MobGroup:AddLabel("Shown as [MOB] in notifications.")
MobGroup:AddLabel("Event-based detection (optimized).")

-- ==================== ANIMATION PLAYER ====================
local AnimPlayer = {
    CurrentTrack = nil,
    AnimId = "",
    Looping = false,
    Speed = 1
}

local AnimPlayerGroup = Tabs.Player:AddLeftGroupbox("Animation Player")

AnimPlayerGroup:AddInput("AnimPlayerId", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Animation ID",
    Tooltip = "Enter animation asset ID (numbers or rbxassetid://...)",
    Placeholder = "e.g. 12345678 or rbxassetid://12345678",
    Callback = function(value)
        AnimPlayer.AnimId = value
    end
})

AnimPlayerGroup:AddToggle("AnimPlayerLoop", {
    Text = "Loop Animation",
    Default = false,
    Callback = function(value)
        AnimPlayer.Looping = value
        if AnimPlayer.CurrentTrack then
            AnimPlayer.CurrentTrack.Looped = value
        end
    end
})

AnimPlayerGroup:AddSlider("AnimPlayerSpeed", {
    Text = "Playback Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Suffix = "x",
    Callback = function(value)
        AnimPlayer.Speed = value
        if AnimPlayer.CurrentTrack and AnimPlayer.CurrentTrack.IsPlaying then
            AnimPlayer.CurrentTrack:AdjustSpeed(value)
        end
    end
})

AnimPlayerGroup:AddButton({
    Text = "Play Animation",
    Func = function()
        local id = AnimPlayer.AnimId
        if not id or id == "" then
            Library:Notify("Enter an animation ID first!", 3)
            return
        end

        -- Normalize the ID
        if not id:match("rbxassetid://") then
            local numId = id:match("%d+")
            if not numId then
                Library:Notify("Invalid animation ID format", 3)
                return
            end
            id = "rbxassetid://" .. numId
        end

        local char = LocalPlayer.Character
        if not char then
            Library:Notify("No character found!", 3)
            return
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            Library:Notify("No humanoid found!", 3)
            return
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end

        -- Stop previous animation
        if AnimPlayer.CurrentTrack then
            pcall(function() AnimPlayer.CurrentTrack:Stop() end)
            pcall(function() AnimPlayer.CurrentTrack:Destroy() end)
            AnimPlayer.CurrentTrack = nil
        end

        local anim = Instance.new("Animation")
        anim.AnimationId = id

        local ok, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)

        if not ok or not track then
            Library:Notify("Failed to load animation: " .. tostring(id), 3)
            anim:Destroy()
            return
        end

        track.Looped = AnimPlayer.Looping
        track:Play()
        track:AdjustSpeed(AnimPlayer.Speed)
        AnimPlayer.CurrentTrack = track

        Library:Notify("Playing animation: " .. id, 3)
    end,
    DoubleClick = false,
    Tooltip = "Play the animation on your character"
})

AnimPlayerGroup:AddButton({
    Text = "Stop Animation",
    Func = function()
        if AnimPlayer.CurrentTrack then
            pcall(function() AnimPlayer.CurrentTrack:Stop() end)
            pcall(function() AnimPlayer.CurrentTrack:Destroy() end)
            AnimPlayer.CurrentTrack = nil
            Library:Notify("Animation stopped", 2)
        else
            Library:Notify("No animation is playing", 2)
        end
    end,
    DoubleClick = false,
    Tooltip = "Stop the currently playing animation"
})

AnimPlayerGroup:AddDivider()

AnimPlayerGroup:AddLabel("Paste animation IDs from the fetcher")
AnimPlayerGroup:AddLabel("to preview them on your character.")

-- Quick copy buttons for common actions
local QuickGroup = Tabs.Player:AddRightGroupbox("Quick Actions")

QuickGroup:AddButton({
    Text = "Stop All Animations",
    Func = function()
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        
        local tracks = animator:GetPlayingAnimationTracks()
        for _, track in pairs(tracks) do
            pcall(function() track:Stop() end)
        end
        
        if AnimPlayer.CurrentTrack then
            AnimPlayer.CurrentTrack = nil
        end
        
        Library:Notify("Stopped all animations", 2)
    end,
    Tooltip = "Stop ALL animations on your character"
})

QuickGroup:AddButton({
    Text = "List Playing Animations",
    Func = function()
        local char = LocalPlayer.Character
        if not char then 
            Library:Notify("No character", 3)
            return 
        end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then 
            Library:Notify("No humanoid", 3)
            return 
        end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then 
            Library:Notify("No animator", 3)
            return 
        end
        
        local tracks = animator:GetPlayingAnimationTracks()
        if #tracks == 0 then
            Library:Notify("No animations playing", 2)
        else
            Library:Notify("Playing " .. #tracks .. " animation(s):", 5)
            for i, track in pairs(tracks) do
                local animId = track.Animation.AnimationId
                local assetId = animId:match("rbxassetid://(%d+)") or animId
                Library:Notify(tostring(i) .. ". " .. assetId, 5)
            end
        end
    end,
    Tooltip = "Show all currently playing animations"
})

-- ==================== SERVER HOPPER ====================
local ServerHop = {
    Cooldown = false,
    CooldownTime = 10,
}

local function ServerHopRandom()
    if ServerHop.Cooldown then
        Library:Notify("Wait " .. ServerHop.CooldownTime .. "s between hops", 3)
        return
    end

    ServerHop.Cooldown = true
    Library:Notify("Fetching servers...", 2)

    task.spawn(function()
        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local placeId = game.PlaceId
        local currentJobId = game.JobId
        local targetJobId = nil

        -- Try multiple pages to find a valid server
        local cursor = nil
        for _ = 1, 5 do
            local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"
            if cursor then url = url .. "&cursor=" .. cursor end

            local ok, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)

            if not ok or not result or not result.data then break end

            for _, server in ipairs(result.data) do
                if server.id ~= currentJobId
                    and type(server.playing) == "number"
                    and type(server.maxPlayers) == "number"
                    and server.playing < server.maxPlayers then
                    targetJobId = server.id
                    break
                end
            end

            if targetJobId then break end
            cursor = result.nextPageCursor
            if not cursor then break end
        end

        if not targetJobId then
            Library:Notify("No available servers found", 3)
            task.delay(3, function() ServerHop.Cooldown = false end)
            return
        end

        Library:Notify("Hopping server...", 2)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, targetJobId)
        end)

        task.delay(ServerHop.CooldownTime, function()
            ServerHop.Cooldown = false
        end)
    end)
end

-- UI in Misc tab
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Server Hopper")
MiscGroup:AddButton({
    Text = "Hop to Random Server",
    Func = ServerHopRandom,
    Tooltip = "Teleports you to a different server of the same game"
})

MiscGroup:AddLabel("Cooldown: " .. ServerHop.CooldownTime .. " seconds between hops")

QuickGroup:AddDivider()
QuickGroup:AddLabel("Copy IDs from notifications")
QuickGroup:AddLabel("then paste into the field above.")

-- Theme Manager
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Settings)

-- Save Manager
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("AnimationTool")
SaveManager:BuildConfigSection(Tabs.Settings)

-- Watermark
Library:SetWatermark("Animation Tool | Press RightControl to toggle")
Library:SetWatermarkVisibility(true)

-- Load config
SaveManager:LoadAutoloadConfig()

print("=== Animation Tool Loaded (Optimized) ===")
print("Animation Fetcher: Logs animation IDs from nearby players/mobs")
print("Animation Player: Play any animation on your character")
print("Press RightControl to toggle the menu")
print("Optimizations: Event-based mob detection, notification cooldowns")
