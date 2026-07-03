--!strict

local baseUrl = "https://raw.githubusercontent.com/G4N05/AutomaHub/main/"

getgenv().AutomaHubLoaderModule = true

local function fetchScript(path: string): any
    if isfile and isfile(path) then
        return loadstring(readfile(path))()
    end
    return loadstring(game:HttpGet(baseUrl .. path))()
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

local successLogic, errLogic = pcall(fetchScript, "AutomaHubGui/LogicFunction.lua")
if not successLogic then
    L:setStatus("Error loading logic!")
    task.wait(1)
    L:destroy()
    error("Failed to load logic: " .. tostring(errLogic))
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
