local AppState = {
    projectIsRunning = false,
    currentProjectPath = nil
}

-- Safe state modifier
function AppState.setProjectRunning(isRunning, projectPath)
    AppState.projectIsRunning = isRunning
    AppState.currentProjectPath = projectPath or AppState.currentProjectPath
end

-- State check
function AppState.isProjectRunning()
    return AppState.projectIsRunning, AppState.currentProjectPath
end

return AppState
