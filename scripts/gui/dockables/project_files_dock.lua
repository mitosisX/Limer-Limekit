-- ProjectFilesDock Module
-- The project's files, on the left, where every editor puts them.
--
-- This is the only dock Limer keeps on that side now. The widgets, app utils
-- and python utils lists used to live here; they were a toolbox in every
-- visual respect, and users reasonably tried to drag from them onto a canvas
-- Limer does not have. A file tree makes the honest promise: these are
-- things you click.
--
-- Double-clicking a file hands it to whatever the desktop has registered for
-- it. Limer does not edit code -- Limekit ships language-server stubs, so
-- the editor you already use knows the whole API.

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local sys = require("limekit.sys")

local AppState = require "app.core.app_state"

local ProjectFilesDock = {}

--- The on-disk path a tree item stands for.
--
-- Rebuilt from the item's ancestry rather than remembered one per item.
-- A TreeViewItem is a QTreeWidgetItem, and PySide hands back a new Python
-- wrapper each time Qt is asked for one, so a `paths[item]` table would miss
-- as often as it hit. (Widgets do not behave this way -- lupa returns the
-- same proxy for a LimeObject every time -- but tree items are not widgets.)
function ProjectFilesDock.pathOf(item)
    if not AppState.activeProjectPath then return nil end

    local parts = {}
    local node = item
    while node do
        table.insert(parts, 1, node:getText(1))
        node = node:getParent()
    end

    local path = AppState.activeProjectPath
    for _, part in ipairs(parts) do
        path = fs.FileSystem.joinPaths(path, part)
    end
    return path
end

local function eachItem(tree, visit)
    local function walk(item)
        visit(item)
        for index = 1, item:getChildCount() do
            walk(item:getChildAt(index))
        end
    end
    for index = 1, tree:getTopItemCount() do
        walk(tree:getTopItemAt(index))
    end
end

--- Which folders are open, by path.
--
-- The tree is rebuilt from scratch whenever the project changes on disk, and
-- a tree that collapses itself every time a file is saved is worse than one
-- that never updates. Paths rather than items, because the items themselves
-- are about to be thrown away.
function ProjectFilesDock.captureExpanded(tree)
    local expanded = {}
    eachItem(tree, function(item)
        if item:getExpanded() then
            local path = ProjectFilesDock.pathOf(item)
            if path then expanded[path] = true end
        end
    end)
    return expanded
end

--- Reopens the folders that were open before the rebuild.
function ProjectFilesDock.restoreExpanded(tree, expanded)
    if not expanded then return end
    eachItem(tree, function(item)
        local path = ProjectFilesDock.pathOf(item)
        if path and expanded[path] then
            item:setExpanded(true)
        end
    end)
end

function ProjectFilesDock.create()
    local tree = ui.TreeView()
    tree:setHeaderHidden(true)
    tree:setColumnWidth(1, 100)

    tree:setOnItemDoubleClick(function(_, item)
        local path = ProjectFilesDock.pathOf(item)
        if not path or not fs.FileSystem.exists(path) then return end
        if fs.FileSystem.isFolder(path) then return end

        local App = require "app.core.app"
        local ok, err = pcall(sys.System.openPath, path)
        if ok then
            App.console.log("Opened " .. path)
        else
            App.console.error("Could not open " .. path .. ": " .. tostring(err))
        end
    end)

    local dock = ui.Dockable("Project")
    dock:setMinWidth(260)
    dock:setChild(tree)

    return {
        dock = dock,
        tree = tree
    }
end

return ProjectFilesDock
