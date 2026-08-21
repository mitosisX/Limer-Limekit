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
        -- One button, not two. See gui/navigation.lua.
        viewToggleButton = ui.ToolbarButton('My Project')
    }

    -- The button names its destination rather than its origin, which is the
    -- way a button that does something is normally labelled.
    local function showDestination(onHome)
        if onHome then
            self.viewToggleButton:setText('My Project')
            self.viewToggleButton:setToolTip('Switch to your project')
            self.viewToggleButton:setIcon(res.Resources.images('toolbar/my_project.png'))
        else
            self.viewToggleButton:setText('Home Page')
            self.viewToggleButton:setToolTip('Switch to the home page')
            self.viewToggleButton:setIcon(res.Resources.images('toolbar/homepage.png'))
        end
    end

    local function initUI()
        self.toolbar:setToolButtonStyle('textbesideicon')

        self.newProjectButton:setIcon(res.Resources.images('toolbar/new_project.png'))
        self.newProjectButton:setOnClick(ProjectCreator.show)

        self.openProjectButton:setIcon(res.Resources.images('toolbar/open_project.png'))
        self.openProjectButton:setOnClick(ProjectManager.openProject)

        -- Dead until there is a project to switch to. Before one is open
        -- both pages are the home page.
        self.viewToggleButton:setEnabled(false)
        self.viewToggleButton:setOnClick(Navigation.toggle)

        showDestination(true)
        Navigation.observe(showDestination)
    end

    local function addButtons()
        self.toolbar:addButton(self.newProjectButton)
        self.toolbar:addButton(self.openProjectButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.viewToggleButton)
    end

    initUI()
    addButtons()

    return {
        toolbar = self.toolbar,
        newProjectButton = self.newProjectButton,
        openProjectButton = self.openProjectButton,
        viewToggleButton = self.viewToggleButton,

        --- Called once a project is open, which is when switching between
        --- the two pages starts to mean something.
        enableViewToggle = function()
            self.viewToggleButton:setEnabled(true)
        end
    }
end

return MainToolbar
