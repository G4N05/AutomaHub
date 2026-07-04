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
        Enabled = false, -- Disable WindUI's default text button to use our custom logo button
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
})
getgenv().Window = Window

-- Safe Toggle Function
local function toggleUI()
    if typeof(Window) == "table" then
        if typeof(Window.SetVisibility) == "function" and typeof(Window.IsVisible) == "function" then
            Window:SetVisibility(not Window:IsVisible())
        elseif typeof(Window.SetVisible) == "function" and typeof(Window.IsVisible) == "function" then
            Window:SetVisible(not Window:IsVisible())
        else
            local root = Window.Root or Window.Frame
            if root then
                root.Visible = not root.Visible
            end
        end
    end
end

-- PC Shortcut: RightAlt to toggle visibility
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightAlt then
        toggleUI()
    end
end)

-- Mobile Floating Button (Round logo button, draggable)
local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
if isMobile then
    local parentGui = (function()
        local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
        if ok and hui then return hui end
        local okc, core = pcall(function() return game:GetService("CoreGui") end)
        if okc and core then return core end
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end)()

    local oldToggle = parentGui:FindFirstChild("AutomaHubToggle")
    if oldToggle then pcall(function() oldToggle:Destroy() end) end

    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name = "AutomaHubToggle"
    toggleGui.ResetOnSpawn = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleGui.Parent = parentGui

    local btn = Instance.new("ImageButton")
    btn.Name = "ToggleButton"
    btn.Size = UDim2.fromOffset(44, 44)
    btn.Position = UDim2.new(0.02, 0, 0.4, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Image = asset
    btn.Parent = toggleGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(60, 60, 65)
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(toggleUI)

    -- Draggable support for the floating button
    local dragging = false
    local dragInput, dragStart, startPos

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end