-- MainToolbar Module
-- Defines the main application toolbar

local ui  = require("limekit.ui")
local res = require("limekit.res")

local Navigation = require "gui.navigation"

local MainToolbar = {}

function MainToolbar.create()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"

    local self = {
        toolbar = ui.Toolbar(),
        newProjectButton = ui.ToolbarButton('New Project'),
        openProjectButton = ui.ToolbarButton('Open Project'),
        homePageButton = ui.ToolbarButton('Home Page'),
        switchToProjectToolbarButton = ui.ToolbarButton('My Project')
    }

    local function initUI()
        self.toolbar:setToolButtonStyle('textbesideicon')

        self.newProjectButton:setIcon(res.Resources.images('toolbar/new_project.png'))
        self.newProjectButton:setOnClick(ProjectCreator.show)

        self.openProjectButton:setIcon(res.Resources.images('toolbar/open_project.png'))
        self.openProjectButton:setOnClick(ProjectManager.openProject)

        self.homePageButton:setIcon(res.Resources.images('toolbar/homepage.png'))
        self.homePageButton:setOnClick(Navigation.returnHomePage)

        self.switchToProjectToolbarButton:setEnabled(false)
        self.switchToProjectToolbarButton:setToolTip('Switch back to your project')
        self.switchToProjectToolbarButton:setIcon(res.Resources.images('toolbar/my_project.png'))
        self.switchToProjectToolbarButton:setOnClick(Navigation.returnToMyProject)
    end

    local function addButtons()
        self.toolbar:addButton(self.newProjectButton)
        self.toolbar:addButton(self.openProjectButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.homePageButton)
        self.toolbar:addButton(self.switchToProjectToolbarButton)
    end

    initUI()
    addButtons()

    return {
        toolbar = self.toolbar,
        newProjectButton = self.newProjectButton,
        openProjectButton = self.openProjectButton,
        homePageButton = self.homePageButton,
        switchToProjectToolbarButton = self.switchToProjectToolbarButton
    }
end

return MainToolbar
