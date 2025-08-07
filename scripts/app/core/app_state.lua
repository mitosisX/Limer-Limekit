local AppState = {
    projectIsRunning = false,
    activeProjectPath = nil
}

-- Safe state modifier
function AppState.setProjectRunning(isRunning, projectPath)
    AppState.projectIsRunning = isRunning
    AppState.activeProjectPath = projectPath or AppState.activeProjectPath
end

-- State check
function AppState.isProjectRunning()
    return AppState.projectIsRunning, AppState.activeProjectPath
end

return AppState
