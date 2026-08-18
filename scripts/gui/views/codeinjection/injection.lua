-- CodeInjector Module
-- Provides hot-reload functionality for running projects
--
-- HOW IT WORKS:
-- Content from the TextField is written to ".limekit/_code.lua"
-- The engine watches this directory and executes the code when it changes

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")

local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local CodeInjector = {}

function CodeInjector.create()
    local self = {
        view = ui.Container(),
        codeInjectionLayout = ui.VLayout(),
        buttonLayout = ui.HLayout(),
        runButton = ui.Button('Run'),
        clearButton = ui.Button('Clear'),
        codeField = ui.TextField()
    }

    local function initUI()
        self.buttonLayout:setContentAlignment('left')

        self.runButton:setResizeRule('fixed', 'fixed')
        self.runButton:setOnClick(function()
            local code = self.codeField:getText()

            if code ~= "" then
                fs.FileSystem.writeFile(Paths.codeInjectionFile, code)
                self.codeField:clear()
            else
                ui.Dialogs.critical(App.window, 'Error!',
                    "You'll need to write some code first...")
            end
        end)

        self.clearButton:setResizeRule('fixed', 'fixed')
        self.clearButton:setOnClick(function()
            self.codeField:clear()
        end)

        self.buttonLayout:addChild(self.runButton)
        self.buttonLayout:addChild(self.clearButton)

        self.codeInjectionLayout:addLayout(self.buttonLayout)

        self.codeField:setHint('Enter injection code here...')
        self.codeField:setToolTip("Code entered here will be used to alter your running program")
        self.codeField:setOnTextChange(function(sender, text)
            local hasCode = string.len(text) > 1
            self.runButton:setEnabled(hasCode and AppState.projectIsRunning)
        end)

        self.codeInjectionLayout:addChild(self.codeField)
        self.view:setLayout(self.codeInjectionLayout)
    end

    initUI()

    return {
        view = self.view,

        getView = function()
            return self.view
        end
    }
end

return CodeInjector
