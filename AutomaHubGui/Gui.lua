--!strict

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))() :: any
getgenv().WindUI = WindUI

local Window = WindUI:CreateWindow({
    Title = "AutomaHub",
    Author = "by G4N05",
    Folder = "AutomaHub",
    Icon = "rbxassetid://89249705975584",
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