-- AppFolderDock Module
-- Displays project directory tree

local ui  = require("limekit.ui")

local AppFolderDock = {}

function AppFolderDock.create()
    local dirTree = ui.TreeView()
    dirTree:setHeaderHidden(true)
    dirTree:setColumnWidth(1, 100)

    local dock = ui.Dockable("App directory")
    dock:setMinWidth(300)
    dock:setChild(dirTree)

    return {
        appFolderDock = dock,
        appProjectDirTree = dirTree
    }
end

return AppFolderDock
