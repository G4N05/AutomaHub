--!strict

local Theme = {}

function Theme.Init(WindUI: any, Tab: any): any
    return Tab:AddDropdown("ThemeDropdown", {
        Title = "Theme",
        Description = "Change the UI color scheme",
        Values = { "Dark", "Light", "Amethyst", "Rose", "Mocha" },
        Default = "Dark",
        Callback = function(Value: string)
            if WindUI and WindUI.SetTheme then
                WindUI:SetTheme(Value)
            end
        end
    })
end

return Theme
