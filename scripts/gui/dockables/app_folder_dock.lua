appProjectDirTree = TreeView()
appProjectDirTree:setHeaderHidden(true)
appProjectDirTree:setColumnWidth(0, 100)

appFolderDock = Dockable("App directory")
appFolderDock:setMinWidth(300)
appFolderDock:setChild(appProjectDirTree)

return { appFolderDock = appFolderDock, appProjectDirTree = appProjectDirTree }
