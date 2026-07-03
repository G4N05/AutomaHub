--!strict

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


local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local frame = Window.Frame
local titleBar = frame and frame:FindFirstChild("TitleBar")
if titleBar then
    local titleLabel = titleBar:FindFirstChild("Title") :: TextLabel?
    if titleLabel then titleLabel.Visible = false end
    local subTitleLabel = titleBar:FindFirstChild("SubTitle") :: TextLabel?
    if subTitleLabel then subTitleLabel.Visible = false end

    local container = Instance.new("Frame")
    container.Name = "CustomHeader"
    container.Size = UDim2.new(1, -100, 1, 0)
    container.Position = UDim2.new(0, 15, 0, 0)
    container.BackgroundTransparency = 1
    container.Parent = titleBar

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.fromOffset(24, 24)
    logo.Position = UDim2.new(0, 0, 0.5, -12)
    logo.BackgroundTransparency = 1
    logo.Image = isfile and isfile("AutomaHub/Icon/logo.jpg") and getcustomasset("AutomaHub/Icon/logo.jpg") or "rbxassetid://10842426365"
    logo.Parent = container

    local customFont = (function()
        local paths = {
            "Hello-chrismast/Hello-chrismast.ttf",
            "Hello-chrismast/Hello-chrismast.otf",
            "Hello-chrismast/font.ttf",
            "Hello-chrismast/font.otf",
            "AutomaHub/Hello-chrismast/Hello-chrismast.ttf",
            "AutomaHub/Hello-chrismast/font.ttf"
        }
        if isfile and getcustomasset then
            for _, path in paths do
                if isfile(path) then
                    return Font.new(getcustomasset(path))
                end
            end
        end
        return Font.fromEnum(Enum.Font.GothamBold)
    end)()

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -30, 1, 0)
    nameLabel.Position = UDim2.new(0, 32, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "AutomaHub"
    nameLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    nameLabel.TextSize = 20
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = customFont
    nameLabel.Parent = container
end

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Theme.Init(Fluent, Tabs.Main)
Window:SelectTab(1)

