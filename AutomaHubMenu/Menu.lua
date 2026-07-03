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

export type Tab = {
    AddDropdown: (self: Tab, id: string, config: DropdownConfig) -> Dropdown,
    [string]: any
}

export type Window = {
    AddTab: (self: Window, config: TabConfig) -> Tab,
    [string]: any
}

export type FluentAPI = {
    CreateWindow: (self: FluentAPI, config: WindowConfig) -> Window,
    SetTheme: (self: FluentAPI, themeName: string) -> (),
    [string]: any
}

type ThemeType = {
    Init: (Fluent: FluentAPI, Tab: Tab) -> any
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

Theme.Init(Fluent, Tabs.Main)
