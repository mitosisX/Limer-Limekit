-- Styles Module
-- Manages application-wide styles and themes

local ProjectStyles = require "gui.styles.user_projects_styles"
local ProjectTabsStyle = require "gui.styles.project_tabs_styles"
local GeneralStyles = require "gui.styles.general_styles"
local App = require "app.core.app"

local Styles = {
    GENERAL_STYLES = GeneralStyles.GENERAL_STYLES,
    PROJECT_LISTBOX_LIGHT = ProjectStyles.PROJECT_LISTBOX_LIGHT,
    PROJECT_LISTBOX_DARK = ProjectStyles.PROJECT_LISTBOX_DARK,
    PROJECT_TAB_LIGHT = ProjectTabsStyle.PROJECT_TAB_LIGHT_THEME,
    PROJECT_TAB_DARK = ProjectTabsStyle.PROJECT_TAB_DARK_THEME
}

function Styles.applyProjectListBoxStyles(activeTheme)
    if not App.dockables or not App.projectWorkspace then
        return
    end

    if activeTheme == 'light' then
        App.dockables.userProjectsListDock.userProjectsList:setStyle(Styles.PROJECT_LISTBOX_LIGHT)
        App.projectWorkspace.tabs:setStyle(Styles.PROJECT_TAB_LIGHT)
    elseif activeTheme == 'dark' then
        App.dockables.userProjectsListDock.userProjectsList:setStyle(Styles.PROJECT_LISTBOX_DARK)
        App.projectWorkspace.tabs:setStyle(Styles.PROJECT_TAB_DARK)
    end
end

return Styles
