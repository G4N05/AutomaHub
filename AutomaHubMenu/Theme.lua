--!strict

local Theme = {}

function Theme.Init(Fluent: any, Tab: any): any
    return Tab:AddDropdown("ThemeDropdown", {
        Title = "Theme",
        Values = { "AMOLED", "Charcoal", "Midnight Blue", "Blood Red", "Pearl White" },
        Default = "Charcoal",
        Callback = function(Value: string)
            Fluent:SetTheme(Value)
        end
    })
end

return Theme
