-- ProjectRunner Module
-- Handles project execution and process management

local AppState = require "app.core.app_state"
local App = require "app.core.app"

local ProjectRunner = {
    process = nil,
    ui = nil
}

function ProjectRunner.init(dependencies)
    ProjectRunner.ui = dependencies.ui
end

function ProjectRunner.run(projectPath)
    if AppState.projectIsRunning then
        App.console.error("Project is already running")
        return
    end

    App.console.clear()
    ProjectRunner.process = app.runProject(projectPath)

    ProjectRunner.process:setOnProcessReadyRead(function(data)
        ProjectRunner._handleOutput(data)
    end)

    ProjectRunner.process:setOnProcessStarted(function()
        ProjectRunner._handleStart(projectPath)
        AppState.projectIsRunning = true

        if ProjectRunner.ui then
            ProjectRunner.ui.updateRunState()
        end

        -- Notify inspector tab
        if App.inspectorTab then
            App.inspectorTab.onProjectStateChange(true)
        end
    end)

    ProjectRunner.process:setOnProcessFinished(function()
        ProjectRunner._handleStop()
        AppState.projectIsRunning = false
        ProjectRunner.process = nil

        if ProjectRunner.ui then
            ProjectRunner.ui.updateRunState()
        end

        -- Notify inspector tab
        if App.inspectorTab then
            App.inspectorTab.onProjectStateChange(false)
        end
    end)

    ProjectRunner.process:run()
end

function ProjectRunner.stop()
    if AppState.projectIsRunning and ProjectRunner.process then
        ProjectRunner.process:stop()
    end
end

function ProjectRunner.toggle()
    if AppState.projectIsRunning then
        ProjectRunner.stop()
    else
        ProjectRunner.run(AppState.activeProjectPath)
    end
end

function ProjectRunner._handleStart(projectPath)
    App.console.log("Starting project...")
end

function ProjectRunner._handleOutput(data)
    if string.find(data, 'Error:') or string.find(data, 'ython>"]') then
        App.console.error(data)
    else
        App.console.logstream(data)
    end
end

function ProjectRunner._handleStop()
    ProjectRunner.process = nil
    App.console.log("Project stopped")
end

return ProjectRunner
