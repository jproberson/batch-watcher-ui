local MenuBar = {}

local MenuBarManager = {
    menubar = nil,
    config = nil,
    waitingCount = 0,
    activeCount = 0,
    failedCount = 0,
    display = nil
}

function MenuBar:new(config)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self
    
    for k, v in pairs(MenuBarManager) do
        manager[k] = v
    end
    
    manager.config = config
    
    if config and config.statusBar then
        manager.display = config.statusBar.display
    end
    
    return manager
end

function MenuBarManager:createMenuBar()
    if self.menubar then
        self.menubar:delete()
    end
    
    self.menubar = hs.menubar.new()
    if not self.menubar then
        print("Error: Failed to create menu bar item")
        return false
    end
    
    self:updateStatusText()
    self:setupClickHandler()
    
    return true
end

function MenuBarManager:updateStatusText()
    if not self.menubar then return end
    
    local menubarConfig = self.config.statusBar.menubar
    local statusText = menubarConfig.format
        :gsub("{waiting}", self.display.waitingLabel)
        :gsub("{active}", self.display.activeLabel)
        :gsub("{failed}", self.display.failedLabel)
        :gsub("{waitingCount}", tostring(self.waitingCount))
        :gsub("{activeCount}", tostring(self.activeCount))
        :gsub("{failedCount}", tostring(self.failedCount))
    
    if not menubarConfig.showWhenZero and 
       self.waitingCount == 0 and self.activeCount == 0 and self.failedCount == 0 then
        statusText = ""
    end
    
    self.menubar:setTitle(statusText)
end

function MenuBarManager:setupClickHandler()
    if not self.menubar then return end
    
    local menuItems = {
        {title = "Clear Waiting Files", fn = function() self:clearFiles("waiting") end},
        {title = "Clear Active Files", fn = function() self:clearFiles("active") end},
        {title = "Clear Deadletter Files", fn = function() self:clearFiles("failed") end},
        {title = "-"},
        {title = "Clear All Batch Files", fn = function() self:clearFiles("all") end},
        {title = "-"},
        {title = "Open Batch Folder", fn = function() self:openBatchFolder() end},
        {title = "Display Style", menu = {
            {title = "Floating Widget Only", fn = function() self:setDisplayMode("floating") end},
            {title = "Menu Bar Only", fn = function() self:setDisplayMode("menubar") end},
            {title = "Both Floating + Menu Bar", fn = function() self:setDisplayMode("both") end}
        }},
    }
    
    self.menubar:setMenu(menuItems)
end

function MenuBarManager:setDisplayMode(mode)
    if hs.batchNotifier and hs.batchNotifier.setDisplayMode then
        hs.batchNotifier.setDisplayMode(mode)
    end
end

function MenuBarManager:openBatchFolder()
    if not self.config or not self.config.baseDir then
        hs.alert.show("No base directory configured")
        return
    end
    
    hs.execute("open '" .. self.config.baseDir .. "'")
end

function MenuBarManager:clearFiles(type)
    if not self.config or not self.config.baseDir then
        hs.alert.show("No base directory configured")
        return
    end
    
    local queuePatterns = self.config.fileWatcher.queuePatterns or {"batch", "sandbox"}
    local deadletterPattern = self.config.fileWatcher.deadletterPattern or "deadletter"
    
    local function getQueueDirs()
        local dirs = {}
        local attributes = hs.fs.attributes(self.config.baseDir)
        
        if not attributes or attributes.mode ~= "directory" then
            return dirs
        end
        
        for file in hs.fs.dir(self.config.baseDir) do
            if file ~= "." and file ~= ".." then
                local fullPath = self.config.baseDir .. "/" .. file
                local fileAttributes = hs.fs.attributes(fullPath)
                
                if fileAttributes and fileAttributes.mode == "directory" then
                    local lowerName = file:lower()
                    for _, pattern in ipairs(queuePatterns) do
                        if lowerName:find(pattern:lower()) then
                            table.insert(dirs, file)
                            break
                        end
                    end
                end
            end
        end
        
        return dirs
    end
    
    local function clearFilesInDir(dirPath, fileType)
        local count = 0
        local attributes = hs.fs.attributes(dirPath)
        
        if not attributes or attributes.mode ~= "directory" then
            return count
        end
        
        for file in hs.fs.dir(dirPath) do
            if file ~= "." and file ~= ".." then
                local fullPath = dirPath .. "/" .. file
                local fileAttributes = hs.fs.attributes(fullPath)
                
                if fileAttributes and fileAttributes.mode == "file" then
                    local shouldDelete = false
                    
                    if fileType == "all" then
                        shouldDelete = true
                    elseif fileType == "waiting" and file:sub(1, 2) == "x_" then
                        shouldDelete = true
                    elseif fileType == "active" and file:sub(1, 1):match("%d") then
                        shouldDelete = true
                    elseif fileType == "failed" then
                        shouldDelete = true
                    end
                    
                    if shouldDelete then
                        local success = os.remove(fullPath)
                        if success then
                            count = count + 1
                        end
                    end
                end
            end
        end
        
        return count
    end
    
    local typeText = type == "all" and "all batch files" or type .. " files"
    local shouldConfirm = self.config.statusBar.confirmDeletes
    
    if shouldConfirm then
        local confirmation = hs.dialog.blockAlert("Confirm File Deletion", 
            "Are you sure you want to delete " .. typeText .. "?", 
            "Delete", "Cancel")
        
        if confirmation == "Cancel" then
            return
        end
    end
    
    local totalDeleted = 0
    local queueDirs = getQueueDirs()
    
    for _, dirName in ipairs(queueDirs) do
        local dirPath = self.config.baseDir .. "/" .. dirName
        local isDeadletter = dirName:lower():find(deadletterPattern:lower()) ~= nil
        
        if type == "failed" and isDeadletter then
            totalDeleted = totalDeleted + clearFilesInDir(dirPath, "failed")
        elseif type ~= "failed" and not isDeadletter then
            totalDeleted = totalDeleted + clearFilesInDir(dirPath, type)
        elseif type == "all" then
            totalDeleted = totalDeleted + clearFilesInDir(dirPath, "all")
        end
    end
    
    hs.alert.show("Deleted " .. totalDeleted .. " " .. typeText)
end

function MenuBarManager:updateCounts(waiting, active, failed)
    local countsChanged = (self.waitingCount ~= waiting or 
                          self.activeCount ~= active or 
                          self.failedCount ~= failed)
    
    self.waitingCount = waiting
    self.activeCount = active
    self.failedCount = failed
    
    if countsChanged then
        self:updateStatusText()
    end
end

function MenuBarManager:show()
    self:createMenuBar()
end

function MenuBarManager:hide()
    if self.menubar then
        self.menubar:delete()
        self.menubar = nil
    end
end

return MenuBar