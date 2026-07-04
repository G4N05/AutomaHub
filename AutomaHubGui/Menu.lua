--!strict

local WindUI = getgenv().WindUI

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

local Window = getgenv().Window
if not Window then
    warn("[AutomaHub] Window is not initialized yet!")
    return
end

-- Use custom logo asset as Main tab icon if available, otherwise fallback to "home"
local mainIcon = getgenv().AutomaHubIcon or "home"

local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = mainIcon })
}

-- Init Theme in Main tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(WindUI, Tabs.Main)
else
    warn("[AutomaHub] Failed to load Theme module!")
end
