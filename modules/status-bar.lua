
local StatusBar = {}

local DEFAULTS = {
    WIDTH = 375,
    HEIGHT = 30,
    EDGE_PADDING = 10,
    CORNER_RADIUS = 8,
    TEXT_VERTICAL_OFFSET = 7,
    TEXT_HEIGHT_REDUCTION = 14,
    TEXT_SIZE = 12,
    BACKGROUND_ELEMENT_INDEX = 1,
    TEXT_ELEMENT_START_INDEX = 2
}

local COLORS = {
    BACKGROUND = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.8},
    TEXT = {red = 0.9, green = 0.9, blue = 0.9}
}

local StatusBarManager = {
    canvas = nil,
    width = DEFAULTS.WIDTH,
    height = DEFAULTS.HEIGHT,
    backgroundColor = COLORS.BACKGROUND,
    textColor = COLORS.TEXT,
    waitingCount = 0,
    activeCount = 0,
    failedCount = 0,
    isDragging = false,
    dragOffset = {x = 0, y = 0},
    position = {x = nil, y = nil},
    globalMouseWatcher = nil,
    rightClickWatcher = nil,
    config = nil
}

function StatusBar:new(config)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self
    
    for k, v in pairs(StatusBarManager) do
        manager[k] = v
    end
    
    manager.config = config
    
    if config and config.statusBar then
        if config.statusBar.height then
            manager.height = config.statusBar.height
        end
        if config.statusBar.width then
            manager.width = config.statusBar.width
        end
    end
    
    manager:loadPosition()
    
    return manager
end

function StatusBarManager:getScreenInfo()
    local frame = hs.screen.mainScreen():frame()
    return {
        width = frame.w,
        height = frame.h,
        x = frame.x,
        y = frame.y
    }
end

function StatusBarManager:createCanvas()
    local screen = self:getScreenInfo()
    if not screen then
        print("Error: Could not get screen information")
        return false
    end
    
    if self.canvas then
        self.canvas:delete()
    end
    
    local x = self.position.x or (screen.x + DEFAULTS.EDGE_PADDING)
    local y = self.position.y or (screen.y + screen.height - self.height - DEFAULTS.EDGE_PADDING)
    
    local success, canvas = pcall(function()
        local newCanvas = hs.canvas.new({
            x = x,
            y = y,
            w = self.width,
            h = self.height
        })
        
        newCanvas:level(hs.canvas.windowLevels.overlay)
        newCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        newCanvas:clickActivating(false)
        
        return newCanvas
    end)
    
    if not success or not canvas then
        print("Error: Failed to create status bar canvas")
        return false
    end
    
    self.canvas = canvas
    
    self.canvas:insertElement({
        type = "rectangle",
        action = "fill",
        roundedRectRadii = {xRadius = DEFAULTS.CORNER_RADIUS, yRadius = DEFAULTS.CORNER_RADIUS},
        fillColor = self.backgroundColor,
        trackMouseDown = true,
        trackMouseUp = true,
        trackMouseMove = true
    })
    
    self:setupDragHandlers()
    self:updateStatusText()
    self.canvas:show()
    return true
end

function StatusBarManager:setupDragHandlers()
    if not self.canvas then return end
    
    self.canvas:mouseCallback(function(canvas, message, id, x, y)        
        if message == "mouseDown" then
            local mousePos = hs.mouse.absolutePosition()
            local canvasFrame = canvas:frame()
            
            local flags = hs.eventtap.checkKeyboardModifiers()
            if flags.alt then
                self:showContextMenu(mousePos)
                return
            end
            
            self.isDragging = true
            self.dragOffset.x = mousePos.x - canvasFrame.x
            self.dragOffset.y = mousePos.y - canvasFrame.y
        elseif message == "mouseUp" then
            if self.isDragging then
                self.isDragging = false
                local canvasFrame = canvas:frame()
                self.position.x = canvasFrame.x
                self.position.y = canvasFrame.y
                self:savePosition()
            end
        end
    end)
    
    if self.globalMouseWatcher then
        self.globalMouseWatcher:stop()
    end
    
    self.globalMouseWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseDragged}, function(event)
        if self.isDragging then
            local mousePos = hs.mouse.absolutePosition()
            local newX = mousePos.x - self.dragOffset.x
            local newY = mousePos.y - self.dragOffset.y
            
            local screen = self:getScreenInfo()
            newX = math.max(screen.x, math.min(newX, screen.x + screen.width - self.width))
            newY = math.max(screen.y, math.min(newY, screen.y + screen.height - self.height))
            
            self.canvas:frame({x = newX, y = newY, w = self.width, h = self.height})
        end
        return false
    end)
    
    self.globalMouseWatcher:start()
    
    if self.rightClickWatcher then
        self.rightClickWatcher:stop()
    end
    
    self.rightClickWatcher = hs.eventtap.new({hs.eventtap.event.types.rightMouseDown}, function(event)
        local mousePos = hs.mouse.absolutePosition()
        local canvasFrame = self.canvas:frame()
        
        if mousePos.x >= canvasFrame.x and mousePos.x <= (canvasFrame.x + canvasFrame.w) and
           mousePos.y >= canvasFrame.y and mousePos.y <= (canvasFrame.y + canvasFrame.h) then
            self:showContextMenu(mousePos)
            return true -- Consume the event
        end
        
        return false -- Let other apps handle the right-click
    end)
    
    self.rightClickWatcher:start()
end

function StatusBarManager:updateStatusText()
    if not self.canvas then return end
    
    while #self.canvas > DEFAULTS.BACKGROUND_ELEMENT_INDEX do
        self.canvas:removeElement(DEFAULTS.TEXT_ELEMENT_START_INDEX)
    end
    
    local statusText = string.format(
        "W: %d  |  A: %d  |  D: %d", 
        self.waitingCount, 
        self.activeCount, 
        self.failedCount
    )
    
    self.canvas:insertElement({
        type = "text",
        text = statusText,
        textFont = "Monaco",
        textSize = DEFAULTS.TEXT_SIZE,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {
            x = 0, 
            y = DEFAULTS.TEXT_VERTICAL_OFFSET, 
            w = self.width, 
            h = self.height - DEFAULTS.TEXT_HEIGHT_REDUCTION
        }
    })
end

function StatusBarManager:updateCounts(waiting, active, failed)
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

function StatusBarManager:show()
    self:createCanvas()
end

function StatusBarManager:hide()
    if self.globalMouseWatcher then
        self.globalMouseWatcher:stop()
        self.globalMouseWatcher = nil
    end
    
    if self.rightClickWatcher then
        self.rightClickWatcher:stop()
        self.rightClickWatcher = nil
    end
    
    if self.canvas then
        self.canvas:delete()
        self.canvas = nil
    end
end

function StatusBarManager:savePosition()
    if self.position.x and self.position.y then
        hs.settings.set("batchNotifier.position", {
            x = self.position.x,
            y = self.position.y
        })
    end
end

function StatusBarManager:loadPosition()
    local savedPosition = hs.settings.get("batchNotifier.position")
    if savedPosition and savedPosition.x and savedPosition.y then
        self.position.x = savedPosition.x
        self.position.y = savedPosition.y
    end
end

function StatusBarManager:showContextMenu(mousePos)
    local flags = hs.eventtap.checkKeyboardModifiers()
    local skipConfirm = flags.shift
    
    local menuItems = {
        {title = "Clear Waiting Files", fn = function() self:clearFiles("waiting", skipConfirm) end},
        {title = "Clear Active Files", fn = function() self:clearFiles("active", skipConfirm) end},
        {title = "Clear Deadletter Files", fn = function() self:clearFiles("failed", skipConfirm) end},
        {title = "-"},
        {title = "Clear All Batch Files", fn = function() self:clearFiles("all", skipConfirm) end},
    }
    
    local canvasFrame = self.canvas:frame()
    local screen = self:getScreenInfo()
    local menuHeight = 120 -- More accurate estimate for 5-item menu (about 24px per item)
    
    local menuPos = {x = mousePos.x, y = mousePos.y}
    
    local spaceBelow = screen.height - (canvasFrame.y + canvasFrame.h)
    local spaceAbove = canvasFrame.y - screen.y
    
    if spaceBelow < menuHeight and spaceAbove > menuHeight then
        menuPos.y = canvasFrame.y - menuHeight - 3
    else
        menuPos.y = canvasFrame.y + canvasFrame.h + 3
    end
    
    menuPos.x = canvasFrame.x + (canvasFrame.w / 2)
    
    local menu = hs.menubar.new():setMenu(menuItems)
    menu:popupMenu(menuPos)
    
    hs.timer.doAfter(0.1, function()
        menu:delete()
    end)
end

function StatusBarManager:clearFiles(type, skipConfirmation)
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
    local shouldConfirm = self.config.statusBar.confirmDeletes and not skipConfirmation
    
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

return StatusBar