local ProjectCreator = require "gui.modals.project_creator"
local Navigation = require "gui.navigation"
local AppState = require "app.core.app_state"

toolbar = Toolbar()
toolbar:setIconStyle('textbesideicon')

newProjectToolbarButton = ToolbarButton('New Project')
newProjectToolbarButton:setIcon(images('toolbar/new_project.png'))
newProjectToolbarButton:setOnClick(ProjectCreator.show)

openProjectToolbarButton = ToolbarButton('Open Project')
openProjectToolbarButton:setIcon(images('toolbar/open_project.png'))
openProjectToolbarButton:setOnClick(ProjectManager.openProject)

homePageToolbarButton = ToolbarButton('Home Page')
homePageToolbarButton:setIcon(images('toolbar/homepage.png'))
homePageToolbarButton:setOnClick(Navigation.returnHomePage)

switchToProjectToolbarButton = ToolbarButton('My Project')
switchToProjectToolbarButton:setEnabled(AppState.projectIsRunningfalse and true or false)
switchToProjectToolbarButton:setToolTip('Switch back to your project')
switchToProjectToolbarButton:setIcon(images('toolbar/my_project.png'))
switchToProjectToolbarButton:setOnClick(Navigation.returnToMyProject)

recentlyOpenedToolbarButton = ToolbarButton('Recent Projects')
recentlyOpenedToolbarButton:setToolTip('Projects you just opened in the runner')
recentlyOpenedToolbarButton:setIcon(images('database_refresh.png'))

recentProjectsMenu = Menu()
recentlyOpenedToolbarButton:setMenu(recentProjectsMenu)

toolbar:addButton(newProjectToolbarButton)
toolbar:addButton(openProjectToolbarButton)
toolbar:addButton(ToolbarButton('-'))
toolbar:addButton(homePageToolbarButton)
toolbar:addButton(switchToProjectToolbarButton)
-- toolbar:addButton(recentlyOpenedToolbarButton)

return { toolbar = toolbar, switchToProjectToolbarButton = switchToProjectToolbarButton }
