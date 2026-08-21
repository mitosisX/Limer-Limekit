-- Dockables Module
-- Factory for the two docks Limer keeps: the project's files on the left,
-- your projects on the right.

local ProjectFilesDock = require "gui.dockables.project_files_dock"
local UserProjectsDock = require "gui.dockables.user_projects_dock"

local Dockables = {}

function Dockables.create()
    return {
        projectFilesDock = ProjectFilesDock.create(),
        userProjectsListDock = UserProjectsDock.create()
    }
end

return Dockables
