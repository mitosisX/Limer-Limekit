-- MainToolbar Module
-- New, Open | Run, Build | the view switch.

local ui  = require("limekit.ui")
local res = require("limekit.res")

local Navigation = require "gui.navigation"
local AppState = require "app.core.app_state"

local MainToolbar = {}

function MainToolbar.create()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"
    local ProjectRunner = require "app.core.project_runner"
    local BuildDialog = require "gui.modals.build_dialog"

    local self = {
        toolbar = ui.Toolbar(),
        newProjectButton = ui.ToolbarButton('New Project'),
        openProjectButton = ui.ToolbarButton('Open Project'),
        runButton = ui.ToolbarButton('Run'),
        buildButton = ui.ToolbarButton('Build'),
        designerButton = ui.ToolbarButton('Designer'),
        -- One button, not two. See gui/navigation.lua.
        viewToggleButton = ui.ToolbarButton('My Project')
    }

    -- Painted from Navigation's state, which is where it belongs: opening a
    -- project and the View menu move the view too, and the button has to
    -- follow all three.
    local function paintViewButton(showingHome)
        if showingHome then
            self.viewToggleButton:setText('My Project')
            self.viewToggleButton:setToolTip('Switch to your project')
            self.viewToggleButton:setIcon(res.Resources.images('toolbar/my_project.png'))
        else
            self.viewToggleButton:setText('Home Page')
            self.viewToggleButton:setToolTip('Switch to the home page')
            self.viewToggleButton:setIcon(res.Resources.images('toolbar/homepage.png'))
        end
    end

    local function paintRunButton(isRunning)
        self.runButton:setText(isRunning and 'Stop' or 'Run')
        self.runButton:setIcon(res.Resources.images(isRunning and 'app/stop.png' or 'app/run.png'))
        self.runButton:setToolTip(isRunning and 'Stop this project  (Ctrl+X)'
                                             or 'Run this project  (Ctrl+R)')
        self.buildButton:setEnabled(not isRunning and AppState.activeProjectPath ~= nil)
    end

    local function initUI()
        self.toolbar:setToolButtonStyle('textbesideicon')

        self.newProjectButton:setIcon(res.Resources.images('toolbar/new_project.png'))
        self.newProjectButton:setOnClick(ProjectCreator.show)

        self.openProjectButton:setIcon(res.Resources.images('toolbar/open_project.png'))
        self.openProjectButton:setOnClick(ProjectManager.openProject)

        self.runButton:setEnabled(false)
        self.runButton:setOnClick(function()
            if AppState.activeProjectPath == nil then return end
            ProjectRunner.toggle()
        end)

        self.buildButton:setIcon(res.Resources.images('editor/normal.png'))
        self.buildButton:setToolTip('Build this project into an application  (Ctrl+B)')
        self.buildButton:setEnabled(false)
        self.buildButton:setOnClick(function()
            if AppState.activeProjectPath == nil then return end
            BuildDialog.show()
        end)

        -- Designs live in a project's design folder, so there has to be one.
        self.designerButton:setIcon(res.Resources.images('designer/designer.svg'))
        self.designerButton:setToolTip('Design windows by dragging widgets  (Ctrl+Shift+D)')
        self.designerButton:setEnabled(false)
        self.designerButton:setOnClick(function()
            if AppState.activeProjectPath == nil then return end
            local App = require "app.core.app"
            App.designer.show()
        end)

        -- Dead until there is a project to switch to. Before one is open
        -- both pages are the home page.
        self.viewToggleButton:setEnabled(false)
        self.viewToggleButton:setOnClick(Navigation.toggle)

        paintViewButton(Navigation.isOnHome())
        paintRunButton(false)
        Navigation.observe(paintViewButton)
        ProjectRunner.observe(paintRunButton)
    end

    local function addButtons()
        self.toolbar:addButton(self.newProjectButton)
        self.toolbar:addButton(self.openProjectButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.runButton)
        self.toolbar:addButton(self.buildButton)
        self.toolbar:addButton(self.designerButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.viewToggleButton)
    end

    initUI()
    addButtons()

    return {
        toolbar = self.toolbar,
        newProjectButton = self.newProjectButton,
        openProjectButton = self.openProjectButton,
        runButton = self.runButton,
        buildButton = self.buildButton,
        designerButton = self.designerButton,
        viewToggleButton = self.viewToggleButton,

        --- Called once a project is open, which is when running, building
        --- and switching pages all start to mean something.
        enableProjectActions = function()
            self.runButton:setEnabled(true)
            self.buildButton:setEnabled(true)
            self.designerButton:setEnabled(true)
            self.viewToggleButton:setEnabled(true)
        end
    }
end

return MainToolbar
