local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"

local userProjectsList = ListBox()
userProjectsList:setOnItemDoubleClick(function(sender, folder, index)
    if AppState.projectIsRunning then
        app.criticalAlertDialog(limekitWindow, "Error!",
            "Please stop the app first before opening another project")
        return
    end

    local appFolder = app.joinPaths(Paths.limekitProjectsFolder, folder)
    local appJSON = app.joinPaths(appFolder, 'app.json')
    -- finalizeProjectOpening(appJSON)
    ProjectManager.loadProject(appJSON)
end)

userProjectsList:setResizeRule('expanding', 'expanding')

local userProjectsListDock = Dockable("Your Projects")
userProjectsListDock:setChild(userProjectsList)

return {
    userProjectsListDock = userProjectsListDock,
    userProjectsList = userProjectsList
}
