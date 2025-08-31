-- Configuration for Batch Job Status Widget

local function loadExternalConfig()
    local configPath = hs.fs.pathToAbsolute("~/.hammerspoon/batch-notifier/.env")
    local externalConfig = {}
    
    local file = io.open(configPath, "r")
    if not file then
        print(".env file not found, using defaults")
        return {}
    end
    
    for line in file:lines() do
        line = line:gsub("^%s*", ""):gsub("%s*$", "")
        if line ~= "" and not line:match("^#") then
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and value then
                key = key:gsub("^%s*", ""):gsub("%s*$", "")
                value = value:gsub("^%s*", ""):gsub("%s*$", "")
                
                if value:lower() == "true" then
                    externalConfig[key] = true
                elseif value:lower() == "false" then
                    externalConfig[key] = false
                elseif tonumber(value) then
                    externalConfig[key] = tonumber(value)
                else
                    externalConfig[key] = value
                end
            end
        end
    end
    
    file:close()
    return externalConfig
end

local external = loadExternalConfig()

local function splitPatterns(str)
    local patterns = {}
    if str then
        for pattern in string.gmatch(str, "[^,]+") do
            local trimmed = pattern:gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(patterns, trimmed)
        end
    end
    return patterns
end

local config = {
    baseDir = external.WATCH_DIR and hs.fs.pathToAbsolute(external.WATCH_DIR),
    autoStart = external.AUTO_START ~= nil and external.AUTO_START or true,
    
    statusBar = {
        width = external.WIDGET_WIDTH or 375,
        height = external.WIDGET_HEIGHT or 30,
        padding = 10
    },
    
    fileWatcher = {
        queuePatterns = splitPatterns(external.QUEUE_PATTERNS) or {"batch", "sandbox"},
        deadletterPattern = external.DEADLETTER_PATTERN or "deadletter"
    },
    
    serverCheck = {
        enabled = true,
        healthUrl = external.HEALTH_URL,
        processName = nil,
        checkInterval = external.CHECK_INTERVAL or 5,
        hideWhenServerDown = external.HIDE_WHEN_DOWN ~= nil and external.HIDE_WHEN_DOWN or true
    },
    
    debug = external.DEBUG or false
}

return config