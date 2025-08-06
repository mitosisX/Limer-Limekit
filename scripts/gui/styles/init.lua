local ProjectStyles = require "gui.styles.user_projects_styles"
local ProjectTabsStyle = require "gui.styles.project_tabs_styles"
local GeneralStyles = require "gui.styles.general_styles"

local Styles = {}
Styles.GENERAL_STYLES = GeneralStyles.GENERAL_STYLES

-- The ListBox that shows all available user projects
function Styles.applyProjectListBoxStyles(activeTheme)
    if activeTheme == 'light' then
        Dockables.userProjectsListDock.userProjectsList:setStyle(ProjectStyles.PROJECT_LISTBOX_LIGHT)
        ProjectWorkspace.tabs:setStyle(ProjectTabsStyle.PROJECT_TAB_LIGHT_THEME)
    elseif activeTheme == 'dark' then
        Dockables.userProjectsListDock.userProjectsList:setStyle(ProjectStyles.PROJECT_LISTBOX_DARK)
        ProjectWorkspace.tabs:setStyle(ProjectTabsStyle.PROJECT_TAB_DARK_THEME)
    end
end

return Styles
