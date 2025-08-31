# Batch Job Monitor

I got tired of constantly checking directories to see how many batch jobs were waiting or running, so I made this little Hammerspoon widget that sits in the bottom-left corner and shows me the counts in real time.

**Requirements:** macOS with [Hammerspoon](https://www.hammerspoon.org/) installed.

It's pretty specific to my setup - looks for files that start with `x_` (waiting), files that start with numbers (active), and anything in deadletter folders. Only shows up when my server is actually running.

## Setup

Copy or clone this project to `~/.hammerspoon/batch-notifier`:

```bash
git clone <repo-url> ~/.hammerspoon/batch-notifier
```

Create your configuration file with just the essentials:

```bash
echo 'return {
    baseDir = "~/your/batch/directory/path",
    serverCheck = { healthUrl = "https://your-server.com/health" }
}' > ~/.hammerspoon/batch-notifier/user-config.lua
```

Edit the `baseDir` and `healthUrl` to match your setup. Everything else uses sensible defaults.

Then add this to your `~/.hammerspoon/init.lua`:
```lua
require("batch-notifier")
```

## What it does

Watches a directory for batch job files and shows counts like "W: 5 | A: 12 | D: 0" in a compact draggable widget. Only appears when the health check passes, so you know your backend is actually running.

**Features:**
- **Multiple display modes** - Floating widget, menu bar, or both
- **Draggable** - Click and drag to reposition the widget anywhere on screen
- **Position memory** - Remembers location between restarts
- **Auto-reload** - Configuration reloads automatically when you edit files
- **Smart visibility** - Hides/shows based on server status
- **Context menu** - Right-click or Alt+click for file clearing options
- **Confirmation control** - Configure or bypass deletion confirmations

The health check hits an endpoint every 5 seconds (configurable). Widget automatically hides/shows based on server status.

**Context Menu:** Right-click or Alt+click the widget to access file clearing options. Hold Shift while clicking menu items to bypass confirmation dialogs.

**Note:** Dragging requires granting Hammerspoon accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility.

## Console commands

```lua
hs.batchNotifier.start()    -- Start monitoring
hs.batchNotifier.stop()     -- Stop monitoring  
hs.batchNotifier.restart()  -- Restart monitoring
hs.batchNotifier.status()   -- Show current status
hs.batchNotifier.update()   -- Force file count update
```

## Configuration Reference

For advanced configuration, you can customize any of these settings in your `~/.hammerspoon/batch-notifier/user-config.lua`:

```lua
return {
    -- Required: Directory containing your batch job folders
    baseDir = "~/your/batch/directory/path",
    
    -- Server health monitoring
    serverCheck = {
        healthUrl = "https://your-server.com/health",  -- Required if using server monitoring
        checkInterval = 5,                             -- Seconds between health checks (default: 5)
        hideWhenServerDown = true,                     -- Hide widget when server is down (default: true)
        enabled = true                                 -- Enable server monitoring (default: true)
    },
    
    -- Widget appearance and behavior  
    statusBar = {
        displayMode = "floating",                      -- Display mode: "floating", "menubar", "both" (default: "floating")
        width = 180,                                   -- Widget width in pixels (default: 180)
        height = 30,                                   -- Widget height in pixels (default: 30)
        confirmDeletes = false,                        -- Show confirmation dialogs for file deletion (default: false)
        colors = {                                     -- Custom colors (optional)
            background = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.8},
            text = {red = 0.9, green = 0.9, blue = 0.9}
        },
        ui = {                                         -- Advanced UI customization (optional)
            edgePadding = 10,                          -- Distance from screen edges (default: 10)
            cornerRadius = 8,                          -- Rounded corner radius (default: 8)
            textVerticalOffset = 7,                    -- Text position adjustment (default: 7)
            textHeightReduction = 14,                  -- Text area height adjustment (default: 14)
            textSize = 12                              -- Font size (default: 12)
        },
        display = {                                    -- Status display customization (optional)
            waitingLabel = "W",                        -- Label for waiting jobs (default: "W")
            activeLabel = "A",                         -- Label for active jobs (default: "A")
            failedLabel = "D",                         -- Label for failed jobs (default: "D")
            format = "{waiting}: {waitingCount}  |  {active}: {activeCount}  |  {failed}: {failedCount}"
            -- Alternative formats:
            -- format = "{waitingCount}w {activeCount}a {failedCount}d"
            -- format = "[{waiting}:{waitingCount}, {active}:{activeCount}, {failed}:{failedCount}]"
            -- format = "Waiting: {waitingCount}, Active: {activeCount}, Failed: {failedCount}"
        },
        menubar = {                                        -- Menu bar specific settings (optional)
            format = "{waitingCount}|{activeCount}|{failedCount}", -- Compact format for menu bar space
            showWhenZero = true                            -- Show menu bar item when all counts are zero (default: true)
        }
    },
    
    -- File pattern matching
    fileWatcher = {
        queuePatterns = {"batch", "sandbox"},          -- Directory patterns to watch (default: {"batch", "sandbox"})
        deadletterPattern = "deadletter"               -- Pattern for failed job directories (default: "deadletter")
    },
    
    -- General settings
    autoStart = true,                                  -- Auto-start when Hammerspoon loads (default: true)
    debug = false                                      -- Enable debug logging (default: false)
}
```