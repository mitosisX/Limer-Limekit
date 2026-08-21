-- MainToolbar Module
-- New, Open | Run, Build | API.
--
-- What left: "Home Page" and "My Project". They drove a two-page sliding
-- stack, and the home page is a splash screen -- a GIF, six cards about the
-- project, one Create button. Nobody navigates back to a brochure while
-- working, so it is now the state Limer shows when no project is open, and
-- closing a project is what returns you to it.
--
-- What arrived: Run and Build. They are the two things you do to a project
-- over and over, and they were reachable only from a form buried in a tab.

local ui  = require("limekit.ui")
local res = require("limekit.res")

local AppState = require "app.core.app_state"

local MainToolbar = {}

function MainToolbar.create()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"
    local ProjectRunner = require "app.core.project_runner"
    local BuildDialog = require "gui.modals.build_dialog"
    local ApiPalette = require "gui.modals.api_palette"
    local App = require "app.core.app"

    local self = {
        toolbar = ui.Toolbar(),
        newProjectButton = ui.ToolbarButton('New Project'),
        openProjectButton = ui.ToolbarButton('Open Project'),
        runButton = ui.ToolbarButton('Run'),
        buildButton = ui.ToolbarButton('Build'),
        apiButton = ui.ToolbarButton('API')
    }

    local function updateRunState(isRunning)
        self.runButton:setText(isRunning and 'Stop' or 'Run')
        self.runButton:setIcon(res.Resources.images(isRunning and 'app/stop.png' or 'app/run.png'))
        self.buildButton:setEnabled(not isRunning and AppState.activeProjectPath ~= nil)
    end

    local function initUI()
        self.toolbar:setToolButtonStyle('textbesideicon')

        self.newProjectButton:setIcon(res.Resources.images('toolbar/new_project.png'))
        self.newProjectButton:setOnClick(ProjectCreator.show)

        self.openProjectButton:setIcon(res.Resources.images('toolbar/open_project.png'))
        self.openProjectButton:setOnClick(ProjectManager.openProject)

        self.runButton:setIcon(res.Resources.images('app/run.png'))
        self.runButton:setToolTip('Run this project  (Ctrl+R)')
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

        self.apiButton:setToolTip('Search the Limekit API  (Ctrl+K)')
        self.apiButton:setOnClick(function()
            ApiPalette.show(App.window)
        end)

        ProjectRunner.observe(updateRunState)
    end

    local function addButtons()
        self.toolbar:addButton(self.newProjectButton)
        self.toolbar:addButton(self.openProjectButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.runButton)
        self.toolbar:addButton(self.buildButton)
        self.toolbar:addSeparator()
        self.toolbar:addButton(self.apiButton)
    end

    initUI()
    addButtons()

    return {
        toolbar = self.toolbar,
        newProjectButton = self.newProjectButton,
        openProjectButton = self.openProjectButton,
        runButton = self.runButton,
        buildButton = self.buildButton,

        --- Called when a project is opened: the run and build buttons are
        --- dead until there is something to run.
        enableProjectActions = function()
            self.runButton:setEnabled(true)
            self.buildButton:setEnabled(true)
        end,

        --- Called when the project is closed.
        disableProjectActions = function()
            self.runButton:setEnabled(false)
            self.buildButton:setEnabled(false)
        end
    }
end

return MainToolbar
