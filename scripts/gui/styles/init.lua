local ProjectStyles = require "gui.styles.user_projects_styles"

local Styles = {}

-- The ListBox that shows all available user projects
function Styles.applyProjectListBoxStyles(currentTheme)
    if currentTheme == 'light' then
        Dockables.userProjectsListDock.userProjectsList:setStyle(ProjectStyles.PROJECT_LISTBOX_LIGHT)
    elseif currentTheme == 'dark' then
        Dockables.userProjectsListDock.userProjectsList:setStyle(ProjectStyles.PROJECT_LISTBOX_DARK)
    end
end

return Styles
