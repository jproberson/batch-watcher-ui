local ActivityTracker = {}

local ActivityTrackerManager = {
    config = nil,
    fileTracking = {},
    globalActivity = {},
    baseDir = nil,
}

function ActivityTracker:new(config, baseDir)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self

    for k, v in pairs(ActivityTrackerManager) do
        manager[k] = v
    end

    manager.config = config
    manager.baseDir = baseDir
    manager.fileTracking = {}
    manager.globalActivity = {}

    return manager
end

function ActivityTrackerManager:isEnabled()
    return self.config and self.config.statusBar and self.config.statusBar.enableFileStatusTracking
end

function ActivityTrackerManager:clearActivityHistory()
    if not self:isEnabled() then
        return
    end
    
    self.globalActivity = {}
    self.fileTracking = {}
end

function ActivityTrackerManager:trackRecentActivity(activityType, waiting, active, failed)
    if not self:isEnabled() then
        return
    end

    local currentFiles = self:getAllCurrentFiles()
    local timestamp = os.time()

    self:cleanupOldActivity()

    for fileId, fileInfo in pairs(currentFiles) do
        local currentState = fileInfo.state
        local previousJourney = self.fileTracking[fileId] and self.fileTracking[fileId].journey or ""

        local updatedJourney = self:updateFileJourney(fileId, fileInfo.batchType, currentState, previousJourney)

        self.fileTracking[fileId] = {
            batchType = fileInfo.batchType,
            state = currentState,
            journey = updatedJourney,
            lastSeen = timestamp,
        }
    end

    for i, activity in ipairs(self.globalActivity) do
        local activityFileId = activity.fileId
        if currentFiles[activityFileId] then
            activity.journey = self.fileTracking[activityFileId].journey
        end
    end

    for fileId, fileInfo in pairs(currentFiles) do
        local found = false
        for _, activity in ipairs(self.globalActivity) do
            if activity.fileId == fileId then
                found = true
                break
            end
        end

        if not found then
            table.insert(self.globalActivity, {
                fileId = fileId,
                batchType = fileInfo.batchType,
                state = fileInfo.state,
                journey = self.fileTracking[fileId].journey,
                timestamp = timestamp,
            })
        end
    end

    while #self.globalActivity > 20 do
        table.remove(self.globalActivity, 1)
    end
end

function ActivityTrackerManager:cleanupOldActivity()
    local currentTime = os.time()
    local maxAge = 30 * 60

    local i = 1
    while i <= #self.globalActivity do
        if currentTime - self.globalActivity[i].timestamp > maxAge then
            table.remove(self.globalActivity, i)
        else
            i = i + 1
        end
    end

    while #self.globalActivity > 20 do
        table.remove(self.globalActivity, 1)
    end
end

function ActivityTrackerManager:getAllCurrentFiles()
    local currentFiles = {}

    if not self.baseDir then
        return currentFiles
    end

    local queuePatterns = self.config.fileWatcher.queuePatterns or { "batch", "sandbox" }
    local deadletterPattern = self.config.fileWatcher.deadletterPattern or "deadletter"

    local function scanDirectory(dirPath, isDeadletter)
        local attributes = hs.fs.attributes(dirPath)
        if not attributes or attributes.mode ~= "directory" then
            return
        end

        for file in hs.fs.dir(dirPath) do
            if file ~= "." and file ~= ".." then
                local fullPath = dirPath .. "/" .. file
                local fileAttributes = hs.fs.attributes(fullPath)

                if fileAttributes and fileAttributes.mode == "file" then
                    local state
                    if isDeadletter then
                        state = "failed"
                    elseif file:sub(1, 2) == "x_" then
                        state = "waiting"
                    elseif file:sub(1, 7) == "worker_" then
                        state = "processing"
                    else
                        state = "unknown"
                    end

                    if state ~= "unknown" then
                        local fileId = file:match("worker_(.+)") or file:match("x_(.+)") or file
                        local batchType = self:extractBatchType(fullPath)

                        currentFiles[fileId] = {
                            filename = file,
                            fullPath = fullPath,
                            state = state,
                            batchType = batchType,
                        }
                    end
                end
            end
        end
    end

    local attributes = hs.fs.attributes(self.baseDir)
    if attributes and attributes.mode == "directory" then
        for file in hs.fs.dir(self.baseDir) do
            if file ~= "." and file ~= ".." then
                local fullPath = self.baseDir .. "/" .. file
                local fileAttributes = hs.fs.attributes(fullPath)

                if fileAttributes and fileAttributes.mode == "directory" then
                    local lowerName = file:lower()
                    local isDeadletter = lowerName:find(deadletterPattern:lower()) ~= nil

                    if isDeadletter then
                        scanDirectory(fullPath, true)
                    else
                        for _, pattern in ipairs(queuePatterns) do
                            if lowerName:find(pattern:lower()) then
                                scanDirectory(fullPath, false)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return currentFiles
end

function ActivityTrackerManager:extractBatchType(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return "Unknown"
    end

    local firstLine = file:read("*line")
    file:close()

    if firstLine then
        local batchType = firstLine:match("([^,]+)")
        return batchType or "Unknown"
    end

    return "Unknown"
end

function ActivityTrackerManager:updateFileJourney(fileId, batchType, currentState, previousJourney)
    local stateOrder = { "waiting", "processing", "completed", "failed" }
    local stateArrow = " → "

    if previousJourney == "" then
        return batchType .. ": " .. currentState
    end

    local journeyParts = {}
    for part in previousJourney:gmatch("[^→]+") do
        table.insert(journeyParts, part:match("^%s*(.-)%s*$"))
    end

    local lastPart = journeyParts[#journeyParts]
    if lastPart and not lastPart:find(":") then
        local lastState = lastPart
        if lastState ~= currentState then
            return previousJourney .. stateArrow .. currentState
        end
    else
        return batchType .. ": " .. currentState
    end

    return previousJourney
end

function ActivityTrackerManager:generateTooltipText()
    if not self:isEnabled() then
        return nil
    end

    if #self.globalActivity == 0 then
        return "No recent activity"
    end

    local tooltipLines = {}
    for i = math.max(1, #self.globalActivity - 10), #self.globalActivity do
        local activity = self.globalActivity[i]
        if activity and activity.journey then
            table.insert(tooltipLines, activity.journey)
        end
    end

    if #tooltipLines == 0 then
        return "No recent activity"
    end

    return table.concat(tooltipLines, "\n")
end

return ActivityTracker