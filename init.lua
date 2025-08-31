
local config = require("batch-notifier.config")
local FileWatcher = require("batch-notifier.modules.file-watcher")
local StatusBar = require("batch-notifier.modules.status-bar")
local ServerMonitor = require("batch-notifier.modules.server-monitor")

local batchNotifier = {
	fileWatcher = nil,
	statusBar = nil,
	serverMonitor = nil,
	isRunning = false,
}

local function initialize()
	print("Initializing Batch Job Status Widget...")

	batchNotifier.statusBar = StatusBar:new(config)
	batchNotifier.fileWatcher = FileWatcher:new(config.baseDir, function(event)
		handleFileEvent(event)
	end, config)
	batchNotifier.serverMonitor = ServerMonitor:new(config, function(event)
		handleServerEvent(event)
	end)

	print("Batch Job Status Widget initialized for: " .. config.baseDir)
end

function handleFileEvent(event)
	if batchNotifier.statusBar then
		batchNotifier.statusBar:updateCounts(event.counts.waiting, event.counts.active, event.counts.failed)
	end
end

function handleServerEvent(event)
	if event.type == "server_status_changed" then
		if config.serverCheck.hideWhenServerDown then
			if event.isServerUp then
				if batchNotifier.statusBar then
					batchNotifier.statusBar:show()
				end
				if batchNotifier.fileWatcher then
					batchNotifier.fileWatcher:start()
				end
				print("Server is UP - Status widget activated")
			else
				if batchNotifier.statusBar then
					batchNotifier.statusBar:hide()
				end
				if batchNotifier.fileWatcher then
					batchNotifier.fileWatcher:stop()
				end
				print("Server is DOWN - Status widget hidden")
			end
		end
	end
end

local function start()
	if batchNotifier.isRunning then
		print("Batch Job Notifier is already running")
		return
	end

	if not batchNotifier.fileWatcher then
		initialize()
	end

	batchNotifier.serverMonitor:start()

	batchNotifier.fileWatcher:start()
	batchNotifier.statusBar:show()
	
	hs.timer.doAfter(0.5, function()
		if batchNotifier.fileWatcher then
			batchNotifier.fileWatcher:checkForChanges()
		end
	end)

	batchNotifier.isRunning = true
	print("Batch Job Status Widget started!")
end

local function stop()
	if not batchNotifier.isRunning then
		print("Batch Job Notifier is not running")
		return
	end

	if batchNotifier.fileWatcher then
		batchNotifier.fileWatcher:stop()
	end

	if batchNotifier.statusBar then
		batchNotifier.statusBar:hide()
	end

	if batchNotifier.serverMonitor then
		batchNotifier.serverMonitor:stop()
	end

	batchNotifier.isRunning = false
	print("Batch Job Status Widget stopped")
end

local function restart()
	stop()
	hs.timer.doAfter(1, start)
end

local function status()
	local statusMsg = batchNotifier.isRunning and "Running" or "Stopped"
	local watchDir = config.baseDir or "Not configured"

	print(string.format("Batch Job Notifier Status: %s", statusMsg))
	print(string.format("Watching directory: %s", watchDir))

	if batchNotifier.statusBar then
		print("Status bar is visible")
	end
end

local function triggerUpdate()
	if not batchNotifier.isRunning then
		print("Batch notifier is not running")
		return
	end

	if batchNotifier.fileWatcher then
		batchNotifier.fileWatcher:checkForChanges()
		print("Manual file count update triggered")
	else
		print("File watcher not initialized")
	end
end

hs.batchNotifier = {
	start = start,
	stop = stop,
	restart = restart,
	status = status,
	update = triggerUpdate,
}

local function reloadConfig(files)
	local doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end
	if doReload then
		hs.reload()
	end
end

local hammerspoonConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

local function getSourceDirectory()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local sourcePath = info.source:sub(2)
        local sourceDir = sourcePath:match("^(.*/)")
        if sourceDir then
            local realPath = hs.fs.symlinkAttributes(sourceDir, "target")
            if realPath then
                return realPath
            end
            return sourceDir
        end
    end
    return nil
end

local sourceDir = getSourceDirectory()
if sourceDir then
    local sourceConfigWatcher = hs.pathwatcher.new(sourceDir, reloadConfig):start()
end

if config.autoStart then
	hs.timer.doAfter(1, start)
else
	print("Batch Job Notifier loaded. Use hs.batchNotifier.start() to begin watching.")
	print("Available commands:")
	print("  hs.batchNotifier.start()    - Start the notifier")
	print("  hs.batchNotifier.stop()     - Stop the notifier")
	print("  hs.batchNotifier.restart()  - Restart the notifier")
	print("  hs.batchNotifier.status()   - Show current status")
	print("  hs.batchNotifier.update()   - Force file count update")
end

hs.alert.show("Batch Notifier Config Loaded")

