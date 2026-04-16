-- Jitler Hub Loader v1.0
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/MosIsOG/playground/refs/heads/main/loader.lua"))()

local HUB_URL = "https://raw.githubusercontent.com/MosIsOG/JitlerHub/refs/heads/master/bloodlines_jitler.lua"

-- ================================================================
-- UNLOAD FUNCTION
-- ================================================================
local function UnloadHub()
    -- Destroy UI
    pcall(function()
        for _, p in ipairs({game:GetService("CoreGui"), game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")}) do
            if p then
                local old = p:FindFirstChild("JitlerHubUI")
                if old then old:Destroy() end
            end
        end
        if typeof(gethui) == "function" then
            local old = gethui():FindFirstChild("JitlerHubUI")
            if old then old:Destroy() end
        end
    end)

    -- Clean up ESP Drawing objects
    pcall(function()
        if shared.InstanceData then
            for _, v in pairs(shared.InstanceData) do
                if v.Instances then
                    for _, obj in pairs(v.Instances) do
                        pcall(function()
                            if typeof(obj) == "table" and obj.SetVisible then obj:SetVisible(false); obj:Remove()
                            elseif typeof(obj) == "userdata" or (typeof(obj) == "table" and obj.Remove) then
                                pcall(function() obj.Visible = false end); pcall(function() obj:Remove() end)
                            end
                        end)
                    end
                end
            end
            shared.InstanceData = nil
        end
    end)

    pcall(function()
        if shared.MenuDrawingData and shared.MenuDrawingData.Instances then
            for _, inst in pairs(shared.MenuDrawingData.Instances) do
                pcall(function() inst.Visible = false; inst:Remove() end)
            end
            shared.MenuDrawingData = nil
        end
    end)

    -- Disconnect Hub connections
    pcall(function()
        if shared.JitlerHub then
            local Hub = shared.JitlerHub
            if Hub.FlySystem and Hub.FlySystem.Connection then Hub.FlySystem.Connection:Disconnect() end
            if Hub.WalkspeedMultiplier and Hub.WalkspeedMultiplier.Connection then Hub.WalkspeedMultiplier.Connection:Disconnect() end
            if Hub.PlayerHighlight then
                if Hub.StopPlayerHighlight then Hub.StopPlayerHighlight() end
            end
            if Hub.MobESP then
                if Hub.StopMobESP then Hub.StopMobESP() end
            end
            if Hub.NPCESP then
                if Hub.StopNPCESP then Hub.StopNPCESP() end
            end
            if Hub.BossESP then
                if Hub.StopBossESP then Hub.StopBossESP() end
            end
            if Hub.CorruptedPointESP then
                if Hub.StopCorruptedPointESP then Hub.StopCorruptedPointESP() end
            end
        end
    end)

    -- Unbind render steps
    pcall(function()
        if shared.RSName then
            game:GetService("RunService"):UnbindFromRenderStep(shared.RSName .. "-GetData")
            game:GetService("RunService"):UnbindFromRenderStep(shared.RSName .. "-Update")
        end
    end)

    -- Reset globals
    _G.Noclip = false
    _G.InfiniteJump = false
    shared.JitlerHub = nil
    shared.JitlerLoaded = nil
    shared.RSName = nil
end

-- ================================================================
-- ALREADY-LOADED POPUP (native Roblox GUI)
-- ================================================================
local function ShowAlreadyLoadedPopup()
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer

    -- Create ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "JitlerLoaderPopup"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.ResetOnSpawn = false
    if typeof(syn) == "table" and syn.protect_gui then
        syn.protect_gui(sg); sg.Parent = game:GetService("CoreGui")
    elseif typeof(gethui) == "function" then
        sg.Parent = gethui()
    else
        sg.Parent = game:GetService("CoreGui")
    end

    -- Remove old popup if exists
    pcall(function()
        for _, p in ipairs({game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui")}) do
            if p then
                for _, c in ipairs(p:GetChildren()) do
                    if c.Name == "JitlerLoaderPopup" and c ~= sg then c:Destroy() end
                end
            end
        end
        if typeof(gethui) == "function" then
            for _, c in ipairs(gethui():GetChildren()) do
                if c.Name == "JitlerLoaderPopup" and c ~= sg then c:Destroy() end
            end
        end
    end)

    local tw = function(obj, props, dur)
        local t = TweenService:Create(obj, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end

    -- Colors matching the dark theme from the screenshot
    local bgColor = Color3.fromRGB(18, 18, 22)
    local borderColor = Color3.fromRGB(40, 40, 50)
    local textColor = Color3.fromRGB(230, 230, 240)
    local dimColor = Color3.fromRGB(150, 150, 165)
    local accentColor = Color3.fromRGB(60, 120, 255)
    local accentHover = Color3.fromRGB(80, 140, 255)
    local btnBgColor = Color3.fromRGB(28, 28, 36)
    local btnHoverColor = Color3.fromRGB(40, 40, 50)

    -- Main card - positioned bottom right
    local card = Instance.new("Frame")
    card.Name = "PopupCard"
    card.BackgroundColor3 = bgColor
    card.Size = UDim2.fromOffset(360, 120)
    card.Position = UDim2.new(1, -375, 1, -10) -- starts offscreen below
    card.AnchorPoint = Vector2.new(0, 1)
    card.BorderSizePixel = 0
    card.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = borderColor
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = card

    -- Warning icon circle
    local iconCircle = Instance.new("Frame")
    iconCircle.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
    iconCircle.Size = UDim2.fromOffset(28, 28)
    iconCircle.Position = UDim2.fromOffset(16, 16)
    iconCircle.BorderSizePixel = 0
    iconCircle.Parent = card
    Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1, 0)

    local iconText = Instance.new("TextLabel")
    iconText.Text = "!"
    iconText.TextColor3 = Color3.fromRGB(20, 20, 20)
    iconText.Font = Enum.Font.GothamBold
    iconText.TextSize = 18
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.BackgroundTransparency = 1
    iconText.Parent = iconCircle

    -- Title
    local title = Instance.new("TextLabel")
    title.Text = "Jitler Hub is already launched"
    title.TextColor3 = textColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, -60, 0, 20)
    title.Position = UDim2.fromOffset(52, 16)
    title.BackgroundTransparency = 1
    title.Parent = card

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Text = "What do you want to do?"
    subtitle.TextColor3 = dimColor
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 13
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Size = UDim2.new(1, -60, 0, 18)
    subtitle.Position = UDim2.fromOffset(52, 38)
    subtitle.BackgroundTransparency = 1
    subtitle.Parent = card

    -- Button container
    local btnContainer = Instance.new("Frame")
    btnContainer.BackgroundTransparency = 1
    btnContainer.Size = UDim2.new(1, -24, 0, 34)
    btnContainer.Position = UDim2.fromOffset(12, 70)
    btnContainer.Parent = card

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    btnLayout.Padding = UDim.new(0, 8)
    btnLayout.Parent = btnContainer

    local function createButton(text, fillColor, textCol, hoverFill, order)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.TextColor3 = textCol
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.BackgroundColor3 = fillColor
        btn.Size = UDim2.fromOffset(105, 34)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.LayoutOrder = order
        btn.Parent = btnContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseEnter:Connect(function()
            tw(btn, {BackgroundColor3 = hoverFill}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tw(btn, {BackgroundColor3 = fillColor}, 0.15)
        end)

        return btn
    end

    local unloadBtn = createButton("Unload Script", accentColor, Color3.new(1, 1, 1), accentHover, 1)
    local reloadBtn = createButton("Reload Script", accentColor, Color3.new(1, 1, 1), accentHover, 2)
    local nothingBtn = createButton("Nothing", btnBgColor, dimColor, btnHoverColor, 3)

    -- Unload outline style (stroke instead of fill)
    unloadBtn.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
    local unloadStroke = Instance.new("UIStroke")
    unloadStroke.Color = accentColor
    unloadStroke.Thickness = 1.5
    unloadStroke.Parent = unloadBtn

    unloadBtn.MouseEnter:Connect(function()
        tw(unloadBtn, {BackgroundColor3 = Color3.fromRGB(35, 50, 80)}, 0.15)
    end)
    unloadBtn.MouseLeave:Connect(function()
        tw(unloadBtn, {BackgroundColor3 = Color3.fromRGB(25, 35, 60)}, 0.15)
    end)

    -- Slide-in animation
    card.Position = UDim2.new(1, -375, 1, 130)
    tw(card, {Position = UDim2.new(1, -375, 1, -15)}, 0.35)

    local function dismiss()
        tw(card, {Position = UDim2.new(1, -375, 1, 130)}, 0.25)
        task.wait(0.3)
        sg:Destroy()
    end

    -- Button callbacks
    unloadBtn.MouseButton1Click:Connect(function()
        dismiss()
        UnloadHub()
    end)

    reloadBtn.MouseButton1Click:Connect(function()
        dismiss()
        UnloadHub()
        task.wait(0.3)
        shared.JitlerLoaded = true
        loadstring(game:HttpGet(HUB_URL))()
    end)

    nothingBtn.MouseButton1Click:Connect(function()
        dismiss()
    end)

    -- Auto-dismiss after 15 seconds
    task.delay(15, function()
        if sg and sg.Parent then dismiss() end
    end)
end

-- ================================================================
-- MAIN LOADER LOGIC
-- ================================================================
if shared.JitlerLoaded then
    ShowAlreadyLoadedPopup()
    return
end

shared.JitlerLoaded = true
loadstring(game:HttpGet(HUB_URL))()
