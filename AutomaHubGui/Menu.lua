--!strict

local Fluent = getgenv().Fluent or loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))() :: any

-- ponytail: require, readfile, or HTTP fallback for Theme module
local Theme = (function()
    local themeScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("Theme")
    if themeScript and themeScript:IsA("ModuleScript") then
        local success, module = pcall(require, themeScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubGui/Theme.lua")
    if ok then
        local loader, err = loadstring(fileContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    local ok2, remoteContent = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubGui/Theme.lua")
    if ok2 then
        local loader, err = loadstring(remoteContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    return nil
end)()

-- ponytail: require, readfile, or HTTP fallback for ESP (LogicFunction) module
local ESP = (function()
    if getgenv().AutomaHubESP then
        return getgenv().AutomaHubESP
    end

    local logicScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("LogicFunction")
    if logicScript and logicScript:IsA("ModuleScript") then
        local success, module = pcall(require, logicScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHub/AutomaHubGui/LogicFunction.lua")
    if ok then
        local loader, err = loadstring(fileContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    local ok2, remoteContent = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/G4N05/AutomaHub/main/AutomaHubGui/LogicFunction.lua")
    if ok2 then
        local loader, err = loadstring(remoteContent)
        if loader then
            local success, module = pcall(loader)
            if success and module then return module end
        end
    end
    
    return nil
end)()

local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
}

-- Init Theme in Main tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(Fluent, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end

-- Init Visuals (ESP) Controls in Visuals tab
if ESP then
    Tabs.Visuals:AddToggle("ESPMasterToggle", {
        Title = "Enable ESP",
        Description = "Master toggle to activate/deactivate ESP",
        Default = false,
        Callback = function(Value: boolean)
            ESP.SetMasterEnabled(Value)
        end
    })

    Tabs.Visuals:AddDropdown("ESPSelection", {
        Title = "Choose ESP",
        Description = "Select target ESP types to display",
        Values = { "Player", "Generator", "Pallet", "SCP / Zombie" },
        Multi = true,
        Default = {},
        Callback = function(Value: any)
            ESP.SetSelectedKinds(Value)
        end
    })
else
    warn("[AutomaHub] Failed to load ESP module!")
end
