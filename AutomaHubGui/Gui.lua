--!strict

-- Clean up previous instance if running again (Script Refresh)
if getgenv().AutomaHub_WindUI_Root then
    pcall(function()
        getgenv().AutomaHub_WindUI_Root:Destroy()
    end)
    getgenv().AutomaHub_WindUI_Root = nil
end
if getgenv().Window then
    -- Some libraries might still have a cleanup method
    pcall(function()
        if getgenv().Window.Destroy then
            getgenv().Window:Destroy()
        end
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

local LOGO_ASSET_ID = "rbxassetid://89249705975584"
local asset = LOGO_ASSET_ID
if (getcustomasset or getsynasset) and writefile then
    local logoPath = "AutomaHub/Icon/logo.jpg"
    
    local isLogoFolder = false
    if isfolder then
        pcall(function() isLogoFolder = isfolder(logoPath) end)
    end
    if isLogoFolder and delfolder then
        pcall(delfolder, logoPath)
    end

    local isLogoFile = false
    if isfile then
        pcall(function() isLogoFile = isfile(logoPath) end)
    end

    if not isLogoFile then
        pcall(makefolder, "AutomaHub")
        pcall(makefolder, "AutomaHub/Icon")
        local ok, content = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/Icon/logo.jpg")
        if ok and content then 
            pcall(writefile, logoPath, content) 
            pcall(function() isLogoFile = isfile(logoPath) end)
        end
    end
    
    if isLogoFile then
        local ok, res = pcall((getcustomasset or getsynasset), logoPath)
        if ok and res then asset = res end
    end
end

-- Capture CoreGui children before creating window
local CoreGui = game:GetService("CoreGui")
local guisBefore = {}
for _, v in ipairs(CoreGui:GetChildren()) do
    guisBefore[v] = true
end

local Window = WindUI:CreateWindow({
    Title = "AutomaHub",
    Author = "by G4N05",
    Folder = "AutomaHub",
    Icon = asset,
    Theme = "Dark", -- WindUI doesn't support custom theme dictionaries via AddTheme
    Accent = Color3.fromHex("#DC2626"), -- Try to set Crimson accent if supported
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
            Color3.fromHex("#DC2626"),
            Color3.fromHex("#8B0000")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
})
getgenv().Window = Window

-- Find the new GUI created by WindUI and store it for script refresh
for _, v in ipairs(CoreGui:GetChildren()) do
    if not guisBefore[v] then
        getgenv().AutomaHub_WindUI_Root = v
        break
    end
end

-- PC shortcut: Alt + Right Arrow to toggle UI visibility
local UserInputService = game:GetService("UserInputService")
getgenv().AutomaHubConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    -- PC: Alt + Right Arrow
    if input.KeyCode == Enum.KeyCode.Right and input:IsModifierPressed(Enum.ModifierKey.Alt) then
        local win = getgenv().Window
        if win and win.Visible ~= nil then
            win.Visible = not win.Visible
        end
    end
end)