-- Shortcuts Module
-- Keyboard shortcuts for actions that have no menu item.
--
-- Run, Stop and Build used to live on an App menu whose only purpose was to
-- carry them. The menu is gone and the buttons are on the toolbar, but a
-- toolbar button cannot hold a shortcut on its own, so they are attached to
-- the window here.

local ui  = require("limekit.ui")

local AppState = require "app.core.app_state"

local Shortcuts = {}

--- Attaches every shortcut to `window` and returns them.
--
-- The table is returned rather than dropped because a KeyboardShortcut whose
-- only reference is a local dies with the function that made it, taking the
-- shortcut with it.
function Shortcuts.attach(window)
    local ProjectRunner = require "app.core.project_runner"
    local BuildDialog = require "gui.modals.build_dialog"
    local ApiPalette = require "gui.modals.api_palette"

    local function bind(sequence, handler)
        local shortcut = ui.KeyboardShortcut(window, sequence)
        shortcut:setOnKeyPress(handler)
        return shortcut
    end

    return {
        run = bind("Ctrl+R", function()
            if AppState.activeProjectPath == nil then return end
            if not AppState.projectIsRunning then ProjectRunner.run(AppState.activeProjectPath) end
        end),

        stop = bind("Ctrl+X", function()
            if AppState.projectIsRunning then ProjectRunner.stop() end
        end),

        build = bind("Ctrl+B", function()
            if AppState.activeProjectPath == nil then return end
            if AppState.projectIsRunning then return end
            BuildDialog.show()
        end),

        api = bind("Ctrl+K", function()
            ApiPalette.show(window)
        end),

        designer = bind("Ctrl+Shift+D", function()
            if AppState.activeProjectPath == nil then return end
            local App = require "app.core.app"
            App.designer.show()
        end),
    }
end

return Shortcuts
