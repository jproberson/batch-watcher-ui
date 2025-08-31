-- Status Bar Module
-- Creates a simple status widget in the bottom-left corner

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
    globalMouseWatcher = nil
}

function StatusBar:new(config)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self
    
    for k, v in pairs(StatusBarManager) do
        manager[k] = v
    end
    
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
        
        -- Enable mouse interactions
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
            self.isDragging = true
            local mousePos = hs.mouse.absolutePosition()
            local canvasFrame = canvas:frame()
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
    
    -- Set up global mouse tracking for dragging
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

return StatusBar