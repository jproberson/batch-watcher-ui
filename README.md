# Batch Job Monitor

I got tired of constantly checking directories to see how many batch jobs were waiting or running, so I made this little Hammerspoon widget that sits in the bottom-left corner and shows me the counts in real time.

**Requirements:** macOS with [Hammerspoon](https://www.hammerspoon.org/) installed.

It's pretty specific to my setup - looks for files that start with `x_` (waiting), files that start with numbers (active), and anything in deadletter folders. Only shows up when my server is actually running.

## Setup

Copy or clone this project to `~/.hammerspoon/batch-notifier`:

```bash
git clone <repo-url> ~/.hammerspoon/batch-notifier
```

Create a `.env` file with your configuration:

```
WATCH_DIR=~/your/batch/directory/path
HEALTH_URL=https://your-server.com/health-check
AUTO_START=true
HIDE_WHEN_DOWN=true
DEBUG=false
WIDGET_WIDTH=180
WIDGET_HEIGHT=30
QUEUE_PATTERNS=batch,sandbox
DEADLETTER_PATTERN=deadletter
CHECK_INTERVAL=5
```

Then add this to your `~/.hammerspoon/init.lua`:
```lua
require("batch-notifier")
```

## What it does

Watches a directory for batch job files and shows counts like "W: 5 | A: 12 | D: 0" in a compact widget. Only appears when the health check passes, so you know your backend is actually running.

The health check hits an endpoint every 5 seconds (configurable). Widget automatically hides/shows based on server status.

## Console commands

```lua
hs.batchNotifier.start()    -- Start monitoring
hs.batchNotifier.stop()     -- Stop monitoring  
hs.batchNotifier.restart()  -- Restart monitoring
hs.batchNotifier.status()   -- Show current status
hs.batchNotifier.update()   -- Force file count update
```