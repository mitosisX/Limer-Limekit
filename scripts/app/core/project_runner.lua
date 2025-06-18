local AppState = require "app.core.app_state"

local ProjectRunner = {
    process = nil
}

function ProjectRunner.init(dependencies)
    ProjectRunner.ui = dependencies.ui
end

-- Main execution function
function ProjectRunner.run(projectPath)
    if AppState.projectIsRunning then
        Console.error("Project is already running")
        return
    end

    Console.clear()
    ProjectRunner.process = app.runProject(projectPath)

    -- Configure process handlers
    ProjectRunner.process:setOnProcessReadyRead(function(data)
        ProjectRunner._handleOutput(data)
    end)

    ProjectRunner.process:setOnProcessStarted(function()
        ProjectRunner._handleStart(projectPath)
        AppState.projectIsRunning = true

        ProjectRunner.ui.updateRunState()
    end)

    ProjectRunner.process:setOnProcessFinished(function()
        ProjectRunner._handleStop()
        AppState.projectIsRunning = false
        ProjectRunner.process = nil

        ProjectRunner.ui.updateRunState()
    end)

    ProjectRunner.process:run()
end

function ProjectRunner.stop()
    if AppState.projectIsRunning then
        ProjectRunner.process:stop()
    end
end

-- Helper functions
function ProjectRunner._handleStart(projectPath)
    -- ProjectRunner.ui.updateRunState('running')
    Console.log("Starting project...")
end

function ProjectRunner._handleOutput(data)
    if string.find(data, 'Error:') or string.find(data, 'ython>"]') then
        Console.error(data)
    else
        Console.logstream(data)
    end
end

function ProjectRunner._handleStop()
    -- ProjectRunner.ui.updateRunState('stopped', exitCode)
    -- ProjectRunner.console.log("Project stopped")

    ProjectRunner.process = nil
    Console.log("Project stopped")
end

return ProjectRunner
