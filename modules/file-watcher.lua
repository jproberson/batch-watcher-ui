local FileWatcher = {}

local DEFAULT_QUEUE_PATTERNS = { "batch", "sandbox" }
local DEFAULT_DEADLETTER_PATTERN = "deadletter"
local HIDDEN_DIR_PREFIX = "."
local WAITING_FILE_PREFIX = "x_"
local CURRENT_DIR = "."
local PARENT_DIR = ".."
local PATH_SEPARATOR = "/"

local FILE_TYPES = {
	WAITING = "waiting",
	ACTIVE = "active",
	OTHER = "other",
}

local EVENT_TYPES = {
	COUNTS_UPDATED = "counts_updated",
}

local function isQueueDir(name, queuePatterns)
	if name:sub(1, 1) == HIDDEN_DIR_PREFIX then
		return false
	end

	local lowerName = name:lower()
	for _, pattern in ipairs(queuePatterns) do
		if lowerName:find(pattern:lower()) then
			return true
		end
	end
	return false
end

local function getQueueDirs(baseDir, queuePatterns)
	local dirs = {}
	local attributes = hs.fs.attributes(baseDir)

	if not attributes or attributes.mode ~= "directory" then
		return dirs
	end

	for file in hs.fs.dir(baseDir) do
		if file ~= CURRENT_DIR and file ~= PARENT_DIR then
			local fullPath = baseDir .. PATH_SEPARATOR .. file
			local fileAttributes = hs.fs.attributes(fullPath)

			if fileAttributes and fileAttributes.mode == "directory" and isQueueDir(file, queuePatterns) then
				table.insert(dirs, file)
			end
		end
	end

	return dirs
end

local function getFilesInDir(dirPath)
	local files = {}
	local attributes = hs.fs.attributes(dirPath)

	if not attributes or attributes.mode ~= "directory" then
		return files
	end

	for file in hs.fs.dir(dirPath) do
		if file ~= CURRENT_DIR and file ~= PARENT_DIR then
			local fullPath = dirPath .. PATH_SEPARATOR .. file
			local fileAttributes = hs.fs.attributes(fullPath)

			if fileAttributes and fileAttributes.mode == "file" then
				table.insert(files, file)
			end
		end
	end

	return files
end

function FileWatcher:new(baseDir, callback, config)
	local watcher = {
		baseDir = baseDir,
		callback = callback,
		config = config or {},
		pathWatcher = nil,
		queueDirs = {},
	}

	setmetatable(watcher, self)
	self.__index = self

	return watcher
end

function FileWatcher:initialize()
	local queuePatterns = (self.config.fileWatcher and self.config.fileWatcher.queuePatterns) or DEFAULT_QUEUE_PATTERNS
	self.queueDirs = getQueueDirs(self.baseDir, queuePatterns)
end

local function classifyFile(fileName)
	if fileName:sub(1, 2) == WAITING_FILE_PREFIX then
		return FILE_TYPES.WAITING
	elseif fileName:sub(1, 1):match("%d") then
		return FILE_TYPES.ACTIVE
	else
		return FILE_TYPES.OTHER
	end
end

function FileWatcher:countFiles()
	local counts = { waiting = 0, active = 0, failed = 0 }

	for _, dirName in ipairs(self.queueDirs) do
		local dirPath = self.baseDir .. PATH_SEPARATOR .. dirName
		local files = getFilesInDir(dirPath)
		
		local deadletterPattern = (self.config.fileWatcher and self.config.fileWatcher.deadletterPattern)
			or DEFAULT_DEADLETTER_PATTERN
		local isDeadletter = dirName:lower():find(deadletterPattern:lower()) ~= nil

		for _, fileName in ipairs(files) do
			if isDeadletter then
				counts.failed = counts.failed + 1
			else
				local fileType = classifyFile(fileName)
				if fileType == FILE_TYPES.WAITING then
					counts.waiting = counts.waiting + 1
				elseif fileType == FILE_TYPES.ACTIVE then
					counts.active = counts.active + 1
				end
			end
		end
	end

	return counts
end

function FileWatcher:checkForChanges()
	local queuePatterns = (self.config.fileWatcher and self.config.fileWatcher.queuePatterns) or DEFAULT_QUEUE_PATTERNS
	self.queueDirs = getQueueDirs(self.baseDir, queuePatterns)

	local counts = self:countFiles()
	self.callback({
		type = EVENT_TYPES.COUNTS_UPDATED,
		counts = counts,
	})
end

function FileWatcher:start()
	if not hs.fs.attributes(self.baseDir) then
		print("Error: Base directory does not exist: " .. self.baseDir)
		return false
	end

	self:initialize()

	self.pathWatcher = hs.pathwatcher.new(self.baseDir, function()
		local success, err = pcall(function()
			self:checkForChanges()
		end)
		if not success then
			print("Error in file watcher: " .. tostring(err))
		end
	end)

	if self.pathWatcher then
		self.pathWatcher:start()
		print("File watcher started for: " .. self.baseDir)
		return true
	else
		print("Failed to create path watcher for: " .. self.baseDir)
		return false
	end
end

function FileWatcher:stop()
	if self.pathWatcher then
		self.pathWatcher:stop()
		self.pathWatcher = nil
		print("File watcher stopped")
	end
end

return FileWatcher
