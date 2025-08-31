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
    failedCount = 0
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
    
    local success, canvas = pcall(function()
        return hs.canvas.new({
            x = screen.x + DEFAULTS.EDGE_PADDING,
            y = screen.y + screen.height - self.height - DEFAULTS.EDGE_PADDING,
            w = self.width,
            h = self.height
        })
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
        fillColor = self.backgroundColor
    })
    
    self:updateStatusText()
    self.canvas:show()
    return true
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
    if self.canvas then
        self.canvas:delete()
        self.canvas = nil
    end
end


return StatusBar