local defaults = {
    baseDir = nil,
    autoStart = true,
    
    statusBar = {
        displayMode = "floating",
        width = 180,
        height = 30,
        confirmDeletes = false,
        colors = {
            background = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.8},
            text = {red = 0.9, green = 0.9, blue = 0.9}
        },
        ui = {
            edgePadding = 10,
            cornerRadius = 8,
            textVerticalOffset = 7,
            textHeightReduction = 14,
            textSize = 12
        },
        display = {
            waitingLabel = "W",
            activeLabel = "A", 
            failedLabel = "D",
            separator = "  |  ",
            format = "{waiting}: {waitingCount}  |  {active}: {activeCount}  |  {failed}: {failedCount}"
        },
        menubar = {
            format = "{waitingCount}|{activeCount}|{failedCount}",
            showWhenZero = true
        },
        animations = {
            enabled = true,
            backgroundFlashDuration = 0.3
        }
    },
    
    fileWatcher = {
        queuePatterns = {"batch", "sandbox"},
        deadletterPattern = "deadletter"
    },
    
    serverCheck = {
        enabled = true,
        healthUrl = nil,
        processName = nil,
        checkInterval = 5,
        hideWhenServerDown = true
    },
    
    debug = false
}

local function loadUserConfig()
    local userConfigPath = hs.fs.pathToAbsolute("~/.hammerspoon/batch-notifier/user-config.lua")
    
    if hs.fs.attributes(userConfigPath) then
        local chunk, err = loadfile(userConfigPath)
        if chunk then
            local success, userConfig = pcall(chunk)
            if success and type(userConfig) == "table" then
                return userConfig
            else
                print("Error loading user-config.lua:", userConfig or err)
            end
        else
            print("Error parsing user-config.lua:", err)
        end
    end
    
    return {}
end

local function deepMerge(base, override)
    local result = {}
    
    for key, value in pairs(base) do
        if type(value) == "table" and type(override[key]) == "table" then
            result[key] = deepMerge(value, override[key])
        else
            result[key] = override[key] ~= nil and override[key] or value
        end
    end
    
    for key, value in pairs(override) do
        if result[key] == nil then
            result[key] = value
        end
    end
    
    return result
end

local userConfig = loadUserConfig()
local config = deepMerge(defaults, userConfig)

if config.baseDir then
    config.baseDir = hs.fs.pathToAbsolute(config.baseDir)
end

return config