-- UserProjectsDock Module
-- Displays list of user projects

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")

local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local UserProjectsDock = {}

function UserProjectsDock.create()
    local userProjectsList = ui.ListBox()

    userProjectsList:setOnItemDoubleClick(function(sender, folder, index)
        if AppState.projectIsRunning then
            ui.Dialogs.critical(App.window, "Error!",
                "Please stop the app first before opening another project")
            return
        end

        local ProjectManager = require "app.core.project_manager"
        local appFolder = fs.FileSystem.joinPaths(Paths.limekitProjectsFolder, folder)
        local appJSON = fs.FileSystem.joinPaths(appFolder, 'app.json')
        ProjectManager.loadProject(appJSON)
    end)

    userProjectsList:setResizeRule('expanding', 'expanding')

    local dock = ui.Dockable("Your Projects")
    dock:setChild(userProjectsList)

    return {
        userProjectsListDock = dock,
        userProjectsList = userProjectsList
    }
end

return UserProjectsDock
