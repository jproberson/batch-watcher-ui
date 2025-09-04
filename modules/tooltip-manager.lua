local TooltipManager = {}

local TooltipManagerInstance = {
    currentTooltip = nil,
    tooltipTimer = nil,
    hoveredSection = nil,
    config = nil,
    activityTracker = nil,
}

function TooltipManager:new(config, activityTracker)
    local manager = {}
    setmetatable(manager, self)
    self.__index = self

    for k, v in pairs(TooltipManagerInstance) do
        manager[k] = v
    end

    manager.config = config
    manager.activityTracker = activityTracker
    manager.currentTooltip = nil
    manager.tooltipTimer = nil
    manager.hoveredSection = nil

    return manager
end

function TooltipManagerInstance:isEnabled()
    return self.config and self.config.statusBar and self.config.statusBar.enableFileStatusTracking
end

function TooltipManagerInstance:startTooltipTimer(section, mousePos, parentCanvas)
    if not self:isEnabled() then
        return
    end

    self:cancelTooltipTimer()

    self.tooltipTimer = hs.timer.doAfter(0.8, function()
        self:showTooltip(mousePos, parentCanvas)
    end)
end

function TooltipManagerInstance:cancelTooltipTimer()
    if self.tooltipTimer then
        self.tooltipTimer:stop()
        self.tooltipTimer = nil
    end
end

function TooltipManagerInstance:showTooltip(mousePos, parentCanvas)
    if not self:isEnabled() then
        return
    end

    self:hideTooltip()

    local tooltipText = self.activityTracker:generateTooltipText()
    if not tooltipText or tooltipText == "" then
        return
    end

    local lines = {}
    for line in tooltipText:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local maxLineLength = 0
    for _, line in ipairs(lines) do
        if #line > maxLineLength then
            maxLineLength = #line
        end
    end

    local charWidth = 7
    local lineHeight = 16
    local padding = 20

    local tooltipWidth = math.max(200, maxLineLength * charWidth + padding)
    local tooltipHeight = #lines * lineHeight + padding

    local canvasFrame = parentCanvas:frame()
    self.currentTooltip = hs.canvas.new({
        x = canvasFrame.x + canvasFrame.w + 10,
        y = canvasFrame.y,
        w = tooltipWidth,
        h = tooltipHeight,
    })

    self.currentTooltip:level(hs.canvas.windowLevels.screenSaver)

    self.currentTooltip[1] = {
        type = "rectangle",
        fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.95 },
        strokeColor = { red = 0.3, green = 0.3, blue = 0.3, alpha = 1.0 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
    }

    self.currentTooltip[2] = {
        type = "text",
        text = tooltipText,
        textFont = "Menlo",
        textSize = 11,
        textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 1.0 },
        frame = { x = 10, y = 5, w = tooltipWidth - 20, h = tooltipHeight - 10 },
    }

    self.currentTooltip:show()
end

function TooltipManagerInstance:hideTooltip()
    if self.currentTooltip then
        self.currentTooltip:delete()
        self.currentTooltip = nil
    end
end

function TooltipManagerInstance:cleanup()
    self:cancelTooltipTimer()
    self:hideTooltip()
end

return TooltipManager