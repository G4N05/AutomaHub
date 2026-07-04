--!strict

local Theme = {}

function Theme.Init(WindUI: any, Tab: any): any
    local themes = {}
    for themeName, _ in pairs(WindUI:GetThemes()) do
        table.insert(themes, themeName)
    end
    table.sort(themes)

    return Tab:Dropdown({
        Title = "Theme",
        Values = themes,
        Value = WindUI:GetCurrentTheme(),
        Callback = function(Value: string)
            WindUI:SetTheme(Value)
        end
    })
end

return Theme
