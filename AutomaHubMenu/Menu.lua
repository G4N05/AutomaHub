--!strict

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

local Window = Fluent:CreateWindow({
    Title = "GUI",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Charcoal",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

local ThemeDropdown = Tabs.Main:AddDropdown("ThemeDropdown", {
    Title = "Theme",
    Values = { "AMOLED", "Charcoal", "Midnight Blue", "Blood Red", "Pearl White" },
    Default = "Charcoal",
    Callback = function(Value: string)
        Fluent:SetTheme(Value)
    end
})

Window:SelectTab(1)
