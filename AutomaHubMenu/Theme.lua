--!strict

export type DropdownConfig = {
    Title: string,
    Values: { string },
    Default: string?,
    Callback: (value: string) -> ()
}

export type Dropdown = {
    [string]: any
}

export type Tab = {
    AddDropdown: (self: Tab, id: string, config: DropdownConfig) -> Dropdown,
    [string]: any
}

export type FluentAPI = {
    SetTheme: (self: FluentAPI, themeName: string) -> (),
    [string]: any
}

local Theme = {}

function Theme.Init(Fluent: FluentAPI, Tab: Tab): Dropdown
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
