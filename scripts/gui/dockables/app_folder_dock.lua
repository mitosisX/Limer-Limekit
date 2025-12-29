-- AppFolderDock Module
-- Displays project directory tree

local AppFolderDock = {}

function AppFolderDock.create()
    local dirTree = TreeView()
    dirTree:setHeaderHidden(true)
    dirTree:setColumnWidth(0, 100)

    local dock = Dockable("App directory")
    dock:setMinWidth(300)
    dock:setChild(dirTree)

    return {
        appFolderDock = dock,
        appProjectDirTree = dirTree
    }
end

return AppFolderDock
