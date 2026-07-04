--!strict

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))() :: any
getgenv().WindUI = WindUI

-- Get logo asset ID (works on all platforms)
local LOGO_ASSET_ID = "rbxassetid://89249705975584"
local asset = LOGO_ASSET_ID
if (getcustomasset or getsynasset) and writefile then
    local logoPath = "AutomaHub/Icon/logo.jpg"
    if isfile and not isfile(logoPath) then
        pcall(makefolder, "AutomaHub")
        pcall(makefolder, "AutomaHub/Icon")
        local ok, content = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/Icon/logo.jpg")
        if ok and content then pcall(writefile, logoPath, content) end
    end
    if isfile and isfile(logoPath) then
        local ok, res = pcall((getcustomasset or getsynasset), logoPath)
        if ok and res then asset = res end
    end
end

local Window = WindUI:CreateWindow({
    Title = "AutomaHub",
    Author = "by G4N05",
    Folder = "AutomaHub",
    Icon = asset,
    Theme = "Dark",
    Size = UDim2.fromOffset(580, 460),
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Enabled = false, -- Disable WindUI's default floating button
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
})
getgenv().Window = Window

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- 1. PC Keybind (Alt Kanan / RightAlt) to toggle GUI visibility
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightAlt then
        Window:Toggle()
    end
end)

-- 2. Mobile Button at Top Center of Screen
local isMobile = UserInputService.TouchEnabled
if isMobile then
    local parentGui = (function()
        local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
        if ok and hui then return hui end
        local okc, core = pcall(function() return game:GetService("CoreGui") end)
        if okc and core then return core end
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end)()

    local oldToggle = parentGui:FindFirstChild("AutomaHubMobileToggle")
    if oldToggle then pcall(function() oldToggle:Destroy() end) end

    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name = "AutomaHubMobileToggle"
    toggleGui.ResetOnSpawn = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleGui.Parent = parentGui

    local btn = Instance.new("TextButton")
    btn.Name = "ToggleButton"
    btn.Size = UDim2.fromOffset(110, 30)
    btn.Position = UDim2.new(0.5, 0, 0, 10)
    btn.AnchorPoint = Vector2.new(0.5, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.Text = "Toggle Menu"
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(240, 240, 245)
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = toggleGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(55, 55, 60)
    stroke.Parent = btn

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(
        Color3.fromRGB(45, 45, 50),
        Color3.fromRGB(20, 20, 25)
    )
    gradient.Rotation = 90
    gradient.Parent = btn

    -- Micro-animations
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(70, 70, 75)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(55, 55, 60)}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        btn:TweenSize(UDim2.fromOffset(102, 27), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
    end)
    btn.MouseButton1Up:Connect(function()
        btn:TweenSize(UDim2.fromOffset(110, 30), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
    end)

    btn.MouseButton1Click:Connect(function()
        Window:Toggle()
    end)
end