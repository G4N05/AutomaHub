--!strict

local WindUI = getgenv().WindUI

-- ponytail: require or readfile for Theme module (strictly local)
local Theme = (function()
    local themeScript = typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("Theme")
    if themeScript and themeScript:IsA("ModuleScript") then
        local success, module = pcall(require, themeScript)
        if success then return module end
    end
    
    local ok, fileContent = pcall(readfile, "AutomaHubGui/Theme.lua")
    if not ok then
        -- Fallback if executed from inside AutomaHubGui directory
        ok, fileContent = pcall(readfile, "Theme.lua")
    end
    
    if ok then
        local loader, err = loadstring(fileContent)
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
    Theme = Window:Tab({ Title = "Theme", Icon = "palette" })
}

-- Init Theme in Theme tab
if Theme and typeof(Theme) == "table" and typeof(Theme.Init) == "function" then
    Theme.Init(WindUI, Tabs.Theme)
else
    warn("[AutomaHub] Failed to load Theme module!")
end
