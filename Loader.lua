--!strict

local baseUrl = "https://raw.githubusercontent.com/G4N05/AutomaHub/main/"

getgenv().AutomaHubLoaderModule = true

local function fetchScript(path: string): any
    local content
    local source = "unknown"
    if _G.AutomaHubDeveloperMode and isfile then
        if isfile(path) then
            local ok = pcall(function() content = readfile(path) end)
            if ok and content then source = "Local Workspace (" .. path .. ")" end
        elseif isfile("AutomaHub/" .. path) then
            local ok = pcall(function() content = readfile("AutomaHub/" .. path) end)
            if ok and content then source = "Local Workspace (AutomaHub/" .. path .. ")" end
        end
    end
    if not content then
        local ok, res = pcall(game.HttpGet, game, baseUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res and not res:find("Too Many Requests") and not res:find("429") then
            content = res
            source = "GitHub Raw"
        end
    end
    if not content then
        local cdnUrl = "https://cdn.jsdelivr.net/gh/G4N05/AutomaHub@main/"
        local ok, res = pcall(game.HttpGet, game, cdnUrl .. path .. "?t=" .. tostring(tick()))
        if ok and res then
            content = res
            source = "jsDelivr CDN"
        end
    end
    if not content then
        error("Failed to fetch script: " .. path .. " (local, GitHub, and CDN all failed)")
    end
    print("[AutomaHub Loader] Loaded " .. path .. " from: " .. source)
    local func, err = loadstring(content)
    if not func then
        error("Failed to compile script " .. path .. ": " .. tostring(err) .. "\nContent: " .. string.sub(content, 1, 100))
    end
    return func()
end

local successLoader, Loader = pcall(fetchScript, "Load.lua")
if not successLoader then
    error("Failed to load loader UI: " .. tostring(Loader))
end

local L = Loader.new()
L:setStatus("Connecting to AutomaHub...")
L:setProgress(0.2)
task.wait(0.4)

L:setStatus("Fetching menu resources...")
L:setProgress(0.6)

local successGui, errGui = pcall(fetchScript, "AutomaHubGui/Gui.lua")
if not successGui then
    L:setStatus("Error loading GUI!")
    task.wait(1)
    L:destroy()
    error("Failed to load GUI: " .. tostring(errGui))
end

local successMenu, errMenu = pcall(fetchScript, "AutomaHubGui/Menu.lua")
if not successMenu then
    L:setStatus("Error loading menu!")
    task.wait(1)
    L:destroy()
    error("Failed to load menu: " .. tostring(errMenu))
end

L:setStatus("Loaded successfully!")
L:setProgress(1.0)

L:finish()
