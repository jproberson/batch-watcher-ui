
local StatusBar = {}

local ELEMENT_INDICES = {
    BACKGROUND = 1,
    BACKGROUND_WAITING = 2,
    BACKGROUND_ACTIVE = 3,
    BACKGROUND_FAILED = 4,
    TEXT_WAITING = 5,
    TEXT_ACTIVE = 6,
    TEXT_FAILED = 7,
    TEXT_SEPARATORS = 8
}


local StatusBarManager = {
    canvas = nil,
    width = nil,
    height = nil,
    backgroundColor = nil,
    textColor = nil,
    waitingCount = 0,
    activeCount = 0,
    failedCount = 0,
    isDragging = false,
    dragOffset = {x = 0, y = 0},
    position = {x = nil, y = nil},
    globalMouseWatcher = nil,
    rightClickWatcher = nil,
    config = nil,
    lastActivity = nil,
    originalBackgroundColor = nil,
    animatedCounts = {waiting = 0, active = 0, failed = 0}
}

function StatusBar:new(config)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self
    
    for k, v in pairs(StatusBarManager) do
        if type(v) == "table" then
            manager[k] = {}
            for tk, tv in pairs(v) do
                manager[k][tk] = tv
            end
        else
            manager[k] = v
        end
    end
    
    manager.config = config
    
    if config and config.statusBar then
        manager.width = config.statusBar.width
        manager.height = config.statusBar.height
        manager.backgroundColor = config.statusBar.colors.background
        manager.textColor = config.statusBar.colors.text
        manager.ui = config.statusBar.ui
        manager.display = config.statusBar.display
        manager.animations = config.statusBar.animations
    end
    
    manager:loadPosition()
    
    manager.animatedCounts = {
        waiting = manager.waitingCount,
        active = manager.activeCount,
        failed = manager.failedCount
    }
    
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
    
    local x = self.position.x or (screen.x + self.ui.edgePadding)
    local y = self.position.y or (screen.y + screen.height - self.height - self.ui.edgePadding)
    
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
        roundedRectRadii = {xRadius = self.ui.cornerRadius, yRadius = self.ui.cornerRadius},
        fillColor = self.backgroundColor,
        trackMouseDown = true,
        trackMouseUp = true,
        trackMouseMove = true
    })
    
    self:setupDragHandlers()
    self:setupTextElements()
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

function StatusBarManager:setupTextElements()
    if not self.canvas then return end
    
    -- Remove all existing text elements
    while #self.canvas > ELEMENT_INDICES.BACKGROUND do
        self.canvas:removeElement(ELEMENT_INDICES.BACKGROUND + 1)
    end
    
    -- Fixed layout calculations for proper spacing
    local totalWidth = self.width
    local textY = self.ui.textVerticalOffset
    local textHeight = self.height - self.ui.textHeightReduction
    
    -- Reserve space for separators and calculate section widths
    local separatorWidth = 12  -- Width for " | " separators
    local padding = 8
    local availableWidth = totalWidth - (2 * separatorWidth) - (2 * padding)
    local sectionWidth = availableWidth / 3
    
    -- Section positions
    local waitingX = padding
    local activeX = waitingX + sectionWidth + separatorWidth
    local failedX = activeX + sectionWidth + separatorWidth
    
    local transparentColor = {red = 0, green = 0, blue = 0, alpha = 0}
    local cornerRadius = self.ui.cornerRadius or 8
    
    self.canvas:insertElement({
        type = "rectangle",
        action = "fill",
        fillColor = transparentColor,
        roundedRectRadii = {xRadius = cornerRadius, yRadius = cornerRadius},
        frame = {x = waitingX - 2, y = 2, w = sectionWidth + 4, h = self.height - 4}
    })
    
    self.canvas:insertElement({
        type = "rectangle", 
        action = "fill",
        fillColor = transparentColor,
        roundedRectRadii = {xRadius = cornerRadius, yRadius = cornerRadius},
        frame = {x = activeX - 2, y = 2, w = sectionWidth + 4, h = self.height - 4}
    })
    
    self.canvas:insertElement({
        type = "rectangle",
        action = "fill", 
        fillColor = transparentColor,
        roundedRectRadii = {xRadius = cornerRadius, yRadius = cornerRadius},
        frame = {x = failedX - 2, y = 2, w = sectionWidth + 4, h = self.height - 4}
    })
    
    local waitingText = string.format("%s: %2d", self.display.waitingLabel, math.max(0, math.floor(self.animatedCounts.waiting + 0.5)))
    local activeText = string.format("%s: %2d", self.display.activeLabel, math.max(0, math.floor(self.animatedCounts.active + 0.5)))
    local failedText = string.format("%s: %2d", self.display.failedLabel, math.max(0, math.floor(self.animatedCounts.failed + 0.5)))
    self.canvas:insertElement({
        type = "text",
        text = waitingText,
        textFont = "Monaco",
        textSize = self.ui.textSize,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {x = waitingX, y = textY, w = sectionWidth, h = textHeight}
    })
    
    self.canvas:insertElement({
        type = "text",
        text = activeText,
        textFont = "Monaco",
        textSize = self.ui.textSize,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {x = activeX, y = textY, w = sectionWidth, h = textHeight}
    })
    
    self.canvas:insertElement({
        type = "text",
        text = failedText,
        textFont = "Monaco",
        textSize = self.ui.textSize,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {x = failedX, y = textY, w = sectionWidth, h = textHeight}
    })
    
    self.canvas:insertElement({
        type = "text",
        text = "|",
        textFont = "Monaco",
        textSize = self.ui.textSize,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {x = waitingX + sectionWidth + 2, y = textY, w = separatorWidth - 4, h = textHeight}
    })
    
    self.canvas:insertElement({
        type = "text",
        text = "|",
        textFont = "Monaco",
        textSize = self.ui.textSize,
        textColor = self.textColor,
        textAlignment = "center",
        frame = {x = activeX + sectionWidth + 2, y = textY, w = separatorWidth - 4, h = textHeight}
    })
end

function StatusBarManager:updateSingleCounterText(counterType)
    if not self.canvas then return end
    
    local elementIndex
    local displayValue = math.max(0, math.floor(self.animatedCounts[counterType] + 0.5))
    local labelText
    
    if counterType == "waiting" then
        elementIndex = ELEMENT_INDICES.TEXT_WAITING
        labelText = string.format("%s: %2d", self.display.waitingLabel, displayValue)
    elseif counterType == "active" then
        elementIndex = ELEMENT_INDICES.TEXT_ACTIVE
        labelText = string.format("%s: %2d", self.display.activeLabel, displayValue)
    elseif counterType == "failed" then
        elementIndex = ELEMENT_INDICES.TEXT_FAILED
        labelText = string.format("%s: %2d", self.display.failedLabel, displayValue)
    else
        return
    end
    
    if elementIndex <= #self.canvas then
        local currentText = self.canvas[elementIndex].text or ""
        if currentText ~= labelText then
            self.canvas[elementIndex].text = labelText
        end
    end
end

function StatusBarManager:updateStatusText()
    self:updateSingleCounterText("waiting")
    self:updateSingleCounterText("active") 
    self:updateSingleCounterText("failed")
end

function StatusBarManager:updateCounts(waiting, active, failed)
    local countsChanged = (self.waitingCount ~= waiting or 
                          self.activeCount ~= active or 
                          self.failedCount ~= failed)
    
    if countsChanged then        
        local activityType = self:detectActivity(waiting, active, failed)
        
        self.waitingCount = waiting
        self.activeCount = active
        self.failedCount = failed
        
        self.animatedCounts.waiting = waiting
        self.animatedCounts.active = active
        self.animatedCounts.failed = failed
        self:updateStatusText()
        
        if self.animations and self.animations.enabled then
            self:showSimpleActivityIndicator(activityType)
        end
    end
end

function StatusBarManager:detectActivity(waiting, active, failed)
    local waitingDiff = waiting - self.waitingCount
    local activeDiff = active - self.activeCount
    local failedDiff = failed - self.failedCount
    
    if failedDiff > 0 then
        return "failure"
    elseif activeDiff < 0 and waitingDiff <= 0 then
        return "completion"
    elseif activeDiff > 0 then
        return "processing"
    elseif waitingDiff > 0 then
        return "incoming"
    else
        return "change"
    end
end

function StatusBarManager:showSimpleActivityIndicator(activityType)
    if not self.canvas then return end
    
    if activityType == "failure" then
        self:flashSection("failed", "red")
    elseif activityType == "completion" then
        self:flashSection("active", "green")
    elseif activityType == "processing" then
        self:flashSection("active", "blue")
    elseif activityType == "incoming" then
        self:flashSection("waiting", "yellow")
    end
end

function StatusBarManager:flashSection(sectionType, color)
    if not self.canvas then return end
    
    local sectionIndex
    if sectionType == "waiting" then
        sectionIndex = ELEMENT_INDICES.BACKGROUND_WAITING
    elseif sectionType == "active" then
        sectionIndex = ELEMENT_INDICES.BACKGROUND_ACTIVE
    elseif sectionType == "failed" then
        sectionIndex = ELEMENT_INDICES.BACKGROUND_FAILED
    else
        return
    end
    
    local flashColor
    if color == "red" then
        flashColor = {red = 0.8, green = 0.2, blue = 0.2, alpha = 0.6}
    elseif color == "green" then
        flashColor = {red = 0.2, green = 0.8, blue = 0.2, alpha = 0.6}
    elseif color == "blue" then
        flashColor = {red = 0.2, green = 0.4, blue = 0.8, alpha = 0.6}
    elseif color == "yellow" then
        flashColor = {red = 0.8, green = 0.8, blue = 0.2, alpha = 0.6}
    else
        return
    end
    
    if sectionIndex <= #self.canvas then
        self.canvas[sectionIndex].fillColor = flashColor
        
        local flashDuration = self.animations and self.animations.backgroundFlashDuration or 0.3
        hs.timer.doAfter(flashDuration, function()
            if self.canvas and sectionIndex <= #self.canvas then
                local transparentColor = {red = 0, green = 0, blue = 0, alpha = 0}
                self.canvas[sectionIndex].fillColor = transparentColor
            end
        end)
    end
end

function StatusBarManager:updateCanvas()
    if not self.canvas then return end
    
    self.canvas[ELEMENT_INDICES.BACKGROUND].fillColor = self.backgroundColor
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