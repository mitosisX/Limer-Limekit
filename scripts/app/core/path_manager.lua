local AppState = require "app.core.app_state"

local PathManager = {
    paths = {}
}

function PathManager:load()
    PathManager.pathsFile = app.joinPaths(AppState.activeProjectPath, '.require')

    if app.exists(self.pathsFile) then
        local content = app.readFile(self.pathsFile)
        Console.log(content)
        PathManager.paths = app.splitString(content, '\n') or {}
    end
    return PathManager
end

function PathManager:save()
    app.writeFile(PathManager.pathsFile, table.concat(PathManager.paths, '\n'))
end

function PathManager:addPath(path)
    path = app.normalPath(path)

    table.insert(PathManager.paths, path)

    PathManager:save()
end

function PathManager:removePath(index)
    if index < 1 or index > #PathManager.paths then
        return false, "Invalid index"
    end

    table.remove(PathManager.paths, index)
    PathManager:save()
    table.insert(PathManager.paths, index, PathManager.paths[index])
end

function PathManager:getPaths()
    return self.paths
end

-- return self:load()


return PathManager
