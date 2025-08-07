local ProjectCreator = require "gui.modals.project_creator"
local Navigation = require "gui.navigation"
local AppState = require "app.core.app_state"

local ToolBar = {}

function ToolBar.create()
    local self = {
        toolbar = Toolbar(),
        newProjectToolbarButton = ToolbarButton('New Project'),
        openProjectToolbarButton = ToolbarButton('Open Project'),
        homePageToolbarButton = ToolbarButton('Home Page'),
        switchToProjectToolbarButton = ToolbarButton('My Project'),
    }

    -- Initialize UI components
    function self:_initUI()
        self.toolbar:setIconStyle('textbesideicon')

        self.newProjectToolbarButton:setIcon(images('toolbar/new_project.png'))
        self.newProjectToolbarButton:setOnClick(ProjectCreator.show)

        self.openProjectToolbarButton:setIcon(images('toolbar/open_project.png'))
        self.openProjectToolbarButton:setOnClick(ProjectManager.openProject)

        self.homePageToolbarButton:setIcon(images('toolbar/homepage.png'))
        self.homePageToolbarButton:setOnClick(Navigation.returnHomePage)

        self.switchToProjectToolbarButton:setEnabled(AppState.projectIsRunningfalse and true or false)
        self.switchToProjectToolbarButton:setToolTip('Switch back to your project')
        self.switchToProjectToolbarButton:setIcon(images('toolbar/my_project.png'))
        self.switchToProjectToolbarButton:setOnClick(Navigation.returnToMyProject)
    end

    function self:_addButtons()
        self.toolbar:addButton(self.newProjectToolbarButton)
        self.toolbar:addButton(self.openProjectToolbarButton)
        self.toolbar:addButton(ToolbarButton('-'))
        self.toolbar:addButton(self.homePageToolbarButton)
        self.toolbar:addButton(self.switchToProjectToolbarButton)
    end

    self:_initUI()
    self:_addButtons()


    return {
        toolbar = self.toolbar,
        newProjectToolbarButton = self.newProjectToolbarButton,
        openProjectToolbarButton = self.openProjectToolbarButton,
        homePageToolbarButton = self.homePageToolbarButton,
        switchToProjectToolbarButton = self.switchToProjectToolbarButton,
    }
end

-- toolbar = Toolbar()
-- toolbar:setIconStyle('textbesideicon')

-- newProjectToolbarButton = ToolbarButton('New Project')
-- newProjectToolbarButton:setIcon(images('toolbar/new_project.png'))
-- newProjectToolbarButton:setOnClick(ProjectCreator.show)

-- openProjectToolbarButton = ToolbarButton('Open Project')
-- openProjectToolbarButton:setIcon(images('toolbar/open_project.png'))
-- openProjectToolbarButton:setOnClick(ProjectManager.openProject)

-- homePageToolbarButton = ToolbarButton('Home Page')
-- homePageToolbarButton:setIcon(images('toolbar/homepage.png'))
-- homePageToolbarButton:setOnClick(Navigation.returnHomePage)

-- switchToProjectToolbarButton = ToolbarButton('My Project')
-- switchToProjectToolbarButton:setEnabled(AppState.projectIsRunningfalse and true or false)
-- switchToProjectToolbarButton:setToolTip('Switch back to your project')
-- switchToProjectToolbarButton:setIcon(images('toolbar/my_project.png'))
-- switchToProjectToolbarButton:setOnClick(Navigation.returnToMyProject)

-- recentlyOpenedToolbarButton = ToolbarButton('Recent Projects')
-- recentlyOpenedToolbarButton:setToolTip('Projects you just opened in the runner')
-- recentlyOpenedToolbarButton:setIcon(images('database_refresh.png'))

-- recentProjectsMenu = Menu()
-- recentlyOpenedToolbarButton:setMenu(recentProjectsMenu)

-- toolbar:addButton(newProjectToolbarButton)
-- toolbar:addButton(openProjectToolbarButton)
-- toolbar:addButton(ToolbarButton('-'))
-- toolbar:addButton(homePageToolbarButton)
-- toolbar:addButton(switchToProjectToolbarButton)
-- toolbar:addButton(recentlyOpenedToolbarButton)

-- return { toolbar = toolbar, switchToProjectToolbarButton = switchToProjectToolbarButton }

return ToolBar
