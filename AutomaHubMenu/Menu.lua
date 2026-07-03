--!strict

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: FluentAPI

export type WindowConfig = {
    Title: string,
    SubTitle: string?,
    TabWidth: number?,
    Size: UDim2?,
    Acrylic: boolean?,
    Theme: string?,
    MinimizeKey: Enum.KeyCode?
}

export type TabConfig = {
    Title: string,
    Icon: string?
}

export type DropdownConfig = {
    Title: string,
    Values: { string },
    Default: string?,
    Callback: (value: string) -> ()
}

export type Dropdown = {
    [string]: any
}

export type ToggleConfig = {
    Title: string,
    Default: boolean?,
    Callback: ((value: boolean) -> ())?
}

export type Toggle = {
    [string]: any
}

export type ButtonConfig = {
    Title: string,
    Description: string?,
    Callback: (() -> ())?
}

export type Button = {
    [string]: any
}

export type Section = {
    AddToggle: (self: Section, id: string, config: ToggleConfig) -> Toggle,
    AddButton: (self: Section, config: ButtonConfig) -> Button,
    AddDropdown: (self: Section, id: string, config: DropdownConfig) -> Dropdown,
    [string]: any
}

export type Tab = {
    AddSection: (self: Tab, title: string) -> Section,
    AddDivider: (self: Tab) -> (),
    AddDropdown: (self: Tab, id: string, config: DropdownConfig) -> Dropdown,
    [string]: any
}

export type Window = {
    AddTab: (self: Window, config: TabConfig) -> Tab,
    SelectTab: (self: Window, index: number) -> (),
    [string]: any
}

export type FluentAPI = {
    CreateWindow: (self: FluentAPI, config: WindowConfig) -> Window,
    SetTheme: (self: FluentAPI, themeName: string) -> (),
    [string]: any
}

type ThemeType = {
    Init: (Fluent: FluentAPI, Tab: any) -> any
}

local Theme = (function()
    local success, module = pcall(function()
        local parent = script and script.Parent
        if not parent then error("no parent") end
        return require(parent:WaitForChild("Theme", 2) :: ModuleScript)
    end)
    if success then return module end
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubMenu/Theme.lua")
    if ok then return loadstring(fileContent)() end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubMenu/Theme.lua"))()
end)() :: ThemeType

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

-- ponytail: simple Toggle and Button contents for the tab
local MainSection = Tabs.Main:AddSection("Main Controls")

MainSection:AddToggle("AutoFarm", {
    Title = "Auto Farm",
    Default = false,
    Callback = function(Value: boolean)
        print("Auto Farm set to:", Value)
    end
})

MainSection:AddButton({
    Title = "Teleport to Spawn",
    Description = "Teleport character to spawn point",
    Callback = function()
        print("Teleporting...")
    end
})

-- ponytail: border / divider separating content and settings
Tabs.Main:AddDivider()

local SettingsSection = Tabs.Main:AddSection("Settings")
Theme.Init(Fluent, SettingsSection)

-- Select the first tab automatically on load
Window:SelectTab(1)
