-- BuildManager Module
-- Handles building projects into standalone executables

local AppState = require "app.core.app_state"
local App = require "app.core.app"

local BuildManager = {
    process = nil,
    isBuilding = false,
    ui = nil
}

function BuildManager.init(dependencies)
    BuildManager.ui = dependencies.ui
end

function BuildManager.build(projectPath, options)
    if BuildManager.isBuilding then
        App.console.error("Build already in progress")
        return
    end

    options = options or {}

    App.console.clear()
    App.console.log("Starting build process...")

    BuildManager.process = app.buildProject(projectPath, options)

    BuildManager.process:setOnBuildOutput(function(data)
        BuildManager._handleOutput(data)
    end)

    BuildManager.process:setOnBuildStarted(function()
        BuildManager._handleStart()
    end)

    BuildManager.process:setOnBuildFinished(function(success, outputPath)
        BuildManager._handleFinish(success, outputPath)
    end)

    BuildManager.process:setOnBuildError(function(error)
        BuildManager._handleError(error)
    end)

    BuildManager.process:build()
end

function BuildManager.stop()
    if BuildManager.isBuilding and BuildManager.process then
        BuildManager.process:stop()
        App.console.log("Build cancelled")
        BuildManager.isBuilding = false
    end
end

function BuildManager._handleStart()
    BuildManager.isBuilding = true
    App.console.log("Build started...")

    if BuildManager.ui then
        BuildManager.ui.updateBuildState(true)
    end
end

function BuildManager._handleOutput(data)
    if string.find(data, 'Error') or string.find(data, 'error') then
        App.console.error(data)
    else
        App.console.log(data)
    end
end

function BuildManager._handleFinish(success, outputPath)
    BuildManager.isBuilding = false
    BuildManager.process = nil

    if success then
        App.console.log("Build completed successfully!")
        if outputPath then
            App.console.log("Output: " .. outputPath)
        end
    else
        App.console.error("Build failed")
    end

    if BuildManager.ui then
        BuildManager.ui.updateBuildState(false)
    end
end

function BuildManager._handleError(error)
    App.console.error("Build error: " .. tostring(error))
end

function BuildManager.buildCurrentProject(options)
    if not AppState.activeProjectPath then
        App.console.error("No project loaded")
        return
    end

    BuildManager.build(AppState.activeProjectPath, options)
end

return BuildManager
