-- ProjectWatcher Module
-- Keeps the Project tree honest about what is on disk.
--
-- Limer's file tree was read once, when the project opened, and never again.
-- Create a file in your editor and Limer went on showing the project as it
-- had been, which is worse than showing nothing: a stale tree looks correct.

local sys = require("limekit.sys")

local App = require "app.core.app"

local ProjectWatcher = {
    watcher = nil,
    root = nil,
}

--- Watches `root`, calling `onChange` once shortly after anything changes.
function ProjectWatcher.start(root, onChange)
    ProjectWatcher.stop()

    if not root or root == "" then return false end

    local ok, watcher = pcall(sys.FileWatcher)
    if not ok then
        App.console.warn("Project watcher unavailable: " .. tostring(watcher))
        return false
    end

    ProjectWatcher.watcher = watcher
    ProjectWatcher.root = root

    watcher:setOnChange(function()
        onChange()
    end)

    local counted = watcher:watchTree(root)
    return counted > 0
end

function ProjectWatcher.stop()
    if ProjectWatcher.watcher then
        ProjectWatcher.watcher:clear()
        ProjectWatcher.watcher = nil
        ProjectWatcher.root = nil
    end
end

function ProjectWatcher.isWatching()
    return ProjectWatcher.watcher ~= nil
end

function ProjectWatcher.getCount()
    if not ProjectWatcher.watcher then return 0 end
    return ProjectWatcher.watcher:getCount()
end

return ProjectWatcher
