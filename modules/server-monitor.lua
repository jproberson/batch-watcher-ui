-- Server Monitor Module
-- Checks if the backend server is running

local ServerMonitor = {}

local CURL_TIMEOUTS = {
    CONNECT = "5",
    MAX_TIME = "10"
}

local DEFAULT_CHECK_INTERVAL = 30
local CURL_PATH = "/usr/bin/curl"
local PS_PATH = "/bin/ps"
local PS_ARGS = {"aux"}

local ServerMonitorManager = {
    isServerUp = false,
    checkTimer = nil,
    config = nil,
    callback = nil
}

function ServerMonitor:new(config, callback)
    local monitor = {}
    setmetatable(monitor, self)
    self.__index = self
    
    for k, v in pairs(ServerMonitorManager) do
        monitor[k] = v
    end
    
    monitor.config = config.serverCheck or {}
    monitor.callback = callback
    
    return monitor
end

function ServerMonitorManager:checkServerHttp()
    if not self.config.healthUrl then
        self:updateServerStatus(false)
        return
    end
    
    local url = self.config.healthUrl
    
    local task = hs.task.new(CURL_PATH, function(exitCode, stdOut, stdErr)
        local serverUp = (exitCode == 0)
        
        if self.config.debug then
            local status = serverUp and "UP" or "DOWN"
            local message = string.format("Server health check: %s (%s)", status, url)
            if not serverUp and stdErr and stdErr ~= "" then
                message = message .. " - Error: " .. stdErr
            elseif not serverUp then
                message = message .. " - Exit code: " .. exitCode
            end
            print(message)
        end
        
        self:updateServerStatus(serverUp)
    end, {
        "--connect-timeout", CURL_TIMEOUTS.CONNECT,
        "--max-time", CURL_TIMEOUTS.MAX_TIME, 
        "--silent",
        "--fail",
        "--insecure",
        url
    })
    
    local success = task:start()
    if not success and self.config.debug then
        print("Failed to start curl task for health check")
        self:updateServerStatus(false)
    end
end

function ServerMonitorManager:checkServerProcess()
    if not self.config.processName then
        self:updateServerStatus(false)
        return
    end
    
    local processName = self.config.processName
    
    local task = hs.task.new(PS_PATH, function(exitCode, stdOut, stdErr)
        local serverUp = (exitCode == 0 and stdOut and stdOut:find(processName) ~= nil)
        
        if self.config.debug then
            local status = serverUp and "is running" or "not found"
            if exitCode ~= 0 and stdErr and stdErr ~= "" then
                print(string.format("Process check error: %s", stdErr))
            end
            print(string.format("Process check: %s %s", processName, status))
        end
        
        self:updateServerStatus(serverUp)
    end, PS_ARGS)
    
    local success = task:start()
    if not success and self.config.debug then
        print("Failed to start ps task for process check")
        self:updateServerStatus(false)
    end
end

function ServerMonitorManager:updateServerStatus(isUp)
    if self.isServerUp ~= isUp then
        self.isServerUp = isUp
        
        if self.callback then
            self.callback({
                type = "server_status_changed",
                isServerUp = isUp,
                timestamp = os.date("%H:%M:%S")
            })
        end
        
        print(string.format("Server status changed: %s", isUp and "UP" or "DOWN"))
    end
end

function ServerMonitorManager:performHealthCheck()
    if self.config.healthUrl then
        self:checkServerHttp()
    elseif self.config.processName then
        self:checkServerProcess()
    else
        self:updateServerStatus(true)
    end
end

function ServerMonitorManager:start()
    if not self.config.enabled then
        print("Server monitoring disabled")
        return
    end
    
    print("Starting server monitoring...")
    
    self:performHealthCheck()
    
    local interval = self.config.checkInterval or DEFAULT_CHECK_INTERVAL
    self.checkTimer = hs.timer.doEvery(interval, function()
        self:performHealthCheck()
    end)
    
    print(string.format("Server monitoring started (checking every %d seconds)", interval))
end

function ServerMonitorManager:stop()
    if self.checkTimer then
        self.checkTimer:stop()
        self.checkTimer = nil
        print("Server monitoring stopped")
    end
end

function ServerMonitorManager:getServerStatus()
    return self.isServerUp
end

return ServerMonitor