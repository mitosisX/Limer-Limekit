-- UserProjectsDock Module
-- Displays list of user projects

local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local UserProjectsDock = {}

function UserProjectsDock.create()
    local userProjectsList = ListBox()

    userProjectsList:setOnItemDoubleClick(function(sender, folder, index)
        if AppState.projectIsRunning then
            app.criticalAlertDialog(App.window, "Error!",
                "Please stop the app first before opening another project")
            return
        end

        local ProjectManager = require "app.core.project_manager"
        local appFolder = app.joinPaths(Paths.limekitProjectsFolder, folder)
        local appJSON = app.joinPaths(appFolder, 'app.json')
        ProjectManager.loadProject(appJSON)
    end)

    userProjectsList:setResizeRule('expanding', 'expanding')

    local dock = Dockable("Your Projects")
    dock:setChild(userProjectsList)

    return {
        userProjectsListDock = dock,
        userProjectsList = userProjectsList
    }
end

return UserProjectsDock
