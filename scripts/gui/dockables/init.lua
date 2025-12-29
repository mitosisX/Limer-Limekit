-- Dockables Module
-- Factory for creating all dockable panels

local WidgetsDock = require "gui.dockables.widgets_dock"
local AppUtilsDock = require "gui.dockables.app_utils_dock"
local PythonUtilsDock = require "gui.dockables.python_utils_dock"
local UserProjectsDock = require "gui.dockables.user_projects_dock"
local AppFolderDock = require "gui.dockables.app_folder_dock"

local Dockables = {}

function Dockables.create()
    return {
        widgetsDock = WidgetsDock.create(),
        appUtilsDock = AppUtilsDock.create(),
        pyUtilsDock = PythonUtilsDock.create(),
        userProjectsListDock = UserProjectsDock.create(),
        appFolderDock = AppFolderDock.create()
    }
end

return Dockables
