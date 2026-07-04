local WindUI = getgenv().WindUI
local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

local Tabs = {
    Theme = Window:Tab({ Title = "Theme", Icon = "palette" })
}

-- Populate and initialize Theme dropdown directly
local themes = {}
for themeName, _ in pairs(WindUI:GetThemes()) do
    table.insert(themes, themeName)
end
table.sort(themes)

Tabs.Theme:Dropdown({
    Title = "Theme",
    Values = themes,
    Value = WindUI:GetCurrentTheme(),
    Callback = function(Value: string)
        WindUI:SetTheme(Value)
    end
})
