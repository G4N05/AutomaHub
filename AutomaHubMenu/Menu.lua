--!strict

local Players  = game:GetService("Players")
local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback
local Theme = (function()
    if script and script.Parent then
        local success, module = pcall(function()
            return require(script.Parent:WaitForChild("Theme") :: ModuleScript)
        end)
        if success then return module end
    end
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubMenu/Theme.lua")
    if ok then return loadstring(fileContent)() end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua"))()
end)()

local getsynasset = getcustomasset or (getgenv and getgenv().getcustomasset) or (getgenv and getgenv().getsynasset)

local function getParentGui(): Instance
    local ok, hui = pcall(function() return (getgenv().gethui or gethui)() end)
    if ok and hui then return hui end
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if okc and core then return core end
    local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
    return lp:WaitForChild("PlayerGui")
end

local function loadCustomFont(name: string, path: string): Font?
    if not getsynasset or not writefile then return nil end
    local success, err = pcall(function()
        local ttfAsset = getsynasset(path)
        local fontData = {
            name = name,
            faces = {{
                name = "Regular",
                weight = 400,
                style = "normal",
                assetId = ttfAsset
            }}
        }
        local fontFileName = "AutomaHub_" .. name .. ".font"
        writefile(fontFileName, game:GetService("HttpService"):JSONEncode(fontData))
        local fontAsset = getsynasset(fontFileName)
        return Font.new(fontAsset)
    end)
    if success then
        return err :: Font
    end
    return nil
end

local function customizeHeader()
    local titleLabel = nil
    for i = 1, 30 do
        for _, descendant in ipairs(getParentGui():GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text == "GUI" then
                titleLabel = descendant
                break
            end
        end
        if titleLabel then break end
        task.wait(0.1)
    end

    if not titleLabel then return end
    local parent = titleLabel.Parent
    if not parent then return end

    titleLabel.Visible = false

    local container = Instance.new("Frame")
    container.Name = "CustomHeader"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = container

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.fromOffset(20, 20)
    logo.BackgroundTransparency = 1
    logo.Parent = container

    if getsynasset then
        local ok, asset = pcall(getsynasset, "Icon/logo.jpg")
        if ok then
            logo.Image = asset
        end
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "TitleText"
    nameLabel.Size = UDim2.new(0, 200, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "AutomaHub"
    nameLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = container

    local customFont = loadCustomFont("HelloChristmas", "hello-christmas-font/HelloChristmas-1Ge70.ttf")
    if customFont then
        nameLabel.FontFace = customFont
    else
        nameLabel.Font = Enum.Font.GothamBold
    end
end

local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

task.spawn(customizeHeader)

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Theme.Init(Fluent, Tabs.Main)
Window:SelectTab(1)
