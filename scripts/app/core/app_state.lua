-- AppState Module
-- Manages global application state

local AppState = {
    projectIsRunning = false,
    activeProjectPath = nil
}

function AppState.setProjectRunning(isRunning, projectPath)
    AppState.projectIsRunning = isRunning
    AppState.activeProjectPath = projectPath or AppState.activeProjectPath
end

function AppState.getProjectRunning()
    return AppState.projectIsRunning, AppState.activeProjectPath
end

function AppState.reset()
    AppState.projectIsRunning = false
    AppState.activeProjectPath = nil
end

return AppState
