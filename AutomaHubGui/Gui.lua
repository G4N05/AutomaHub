--!strict

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))() :: any
getgenv().WindUI = WindUI

-- Clean up old WindUI screens to prevent duplicate windows when re-executing
local parentGui = (function()
    local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
    if ok and hui then return hui end
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if okc and core then return core end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end)()

for _, child in ipairs(parentGui:GetChildren()) do
    if child:IsA("ScreenGui") and (child.Name == "WindUI" or child.Name:find("WindUI") or child:FindFirstChild("AutomaHub") or child:FindFirstChild("Window")) then
        pcall(function() child:Destroy() end)
    end
end


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
    Theme = "Crimson",
    Size = UDim2.fromOffset(580, 460),
    NewElements = true,
    HideSearchBar = false,
    ToggleKey = Enum.KeyCode.RightAlt,
    OpenButton = {
        Title = "Open AutomaHub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = true,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            -- profile click callback
        end
    },
})
getgenv().Window = Window

-- Mouse unlock/restore logic for desktop players
local UserInputService = game:GetService("UserInputService")
if not UserInputService.TouchEnabled then
    local savedMouseBehavior = UserInputService.MouseBehavior
    local savedMouseIconEnabled = UserInputService.MouseIconEnabled
    local behaviorConn, iconConn
    
    local function unlockMouse()
        savedMouseBehavior = UserInputService.MouseBehavior
        savedMouseIconEnabled = UserInputService.MouseIconEnabled
        
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        UserInputService.ModalEnabled = true
        
        if behaviorConn then behaviorConn:Disconnect() end
        if iconConn then iconConn:Disconnect() end
        
        behaviorConn = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
        
        iconConn = UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
            if not UserInputService.MouseIconEnabled then
                UserInputService.MouseIconEnabled = true
            end
        end)
    end
    
    local function restoreMouse()
        if behaviorConn then behaviorConn:Disconnect() behaviorConn = nil end
        if iconConn then iconConn:Disconnect() iconConn = nil end
        
        UserInputService.ModalEnabled = false
        UserInputService.MouseBehavior = savedMouseBehavior
        UserInputService.MouseIconEnabled = savedMouseIconEnabled
    end
    
    -- Force unlock on startup since GUI starts open
    unlockMouse()
    
    Window:OnOpen(unlockMouse)
    Window:OnClose(restoreMouse)
end