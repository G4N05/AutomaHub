-- Clean up previous instance if running again (Script Refresh)
if getgenv().Window then
    pcall(function()
        getgenv().Window:Destroy()
    end)
    getgenv().Window = nil
end

if getgenv().AutomaHubConnection then
    pcall(function()
        getgenv().AutomaHubConnection:Disconnect()
    end)
    getgenv().AutomaHubConnection = nil
end

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

WindUI:AddTheme({
    Name = "Crimson",
    Accent = Color3.fromHex("#DC2626"),
    Background = Color3.fromHex("#1A0B0B"),
    Dialog = Color3.fromHex("#261010"),
    Outline = Color3.fromHex("#3D1C1C"),
    Text = Color3.fromHex("#FFF1F1"),
    Placeholder = Color3.fromHex("#997A7A"),
    Button = Color3.fromHex("#2C1212"),
    Icon = Color3.fromHex("#FCA5A5")
})

local Window = WindUI:CreateWindow({
    Title = "AutomaHub",
    Author = "by G4N05",
    Folder = "AutomaHub",
    Icon = asset,
    Theme = "Crimson",
    Size = UDim2.fromOffset(580, 460),
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open AutomaHub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
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
})
getgenv().Window = Window

-- PC shortcut: Alt + Right Arrow to toggle UI visibility
local UserInputService = game:GetService("UserInputService")
getgenv().AutomaHubConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    -- PC: Alt + Right Arrow
    if input.KeyCode == Enum.KeyCode.Right and input:IsModifierPressed(Enum.ModifierKey.Alt) then
        local win = getgenv().Window
        if win then
            win.Visible = not win.Visible
        end
    end
    -- Mobile: Single tap anywhere to toggle UI
    if input.UserInputType == Enum.UserInputType.Touch then
        local win = getgenv().Window
        if win then
            win.Visible = not win.Visible
        end
    end
end)