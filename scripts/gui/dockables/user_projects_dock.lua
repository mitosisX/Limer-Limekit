userProjectsList = ListBox()
userProjectsList:setOnItemDoubleClick(function(sender, folder, index)
    if projectIsRunning then
        app.criticalAlertDialog(limekitWindow, "Error!",
            "Please stop the app first before opening another project")
        return
    end

    local appFolder = app.joinPaths(limekitProjectsFolder, folder)
    local appJSON = app.joinPaths(appFolder, 'app.json')
    -- finalizeProjectOpening(appJSON)
    ProjectManager.loadProject(appJSON)
end)

userProjectsList:setStyle(currentTheme == 'light' and userProjectsLightStyle or userProjectsDarkStyle)
userProjectsList:setResizeRule('expanding', 'expanding')

userProjectsListDock = Dockable("Your Projects")
userProjectsListDock:setChild(userProjectsList)

return { userProjectsListDock = userProjectsListDock, userProjectsList = userProjectsList }
