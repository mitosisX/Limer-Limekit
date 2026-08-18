-- PathManager Module
-- Manages package.path entries for projects

local fs  = require("limekit.fs")
local sys = require("limekit.sys")

local AppState = require "app.core.app_state"

local PathManager = {
    paths = {},
    pathsFile = nil
}

function PathManager.load()
    PathManager.pathsFile = fs.FileSystem.joinPaths(AppState.activeProjectPath, '.require')

    if fs.FileSystem.exists(PathManager.pathsFile) then
        local content = fs.FileSystem.readFile(PathManager.pathsFile)
        PathManager.paths = sys.System.splitString(content, '\n') or {}
    else
        PathManager.paths = {}
    end

    return PathManager
end

function PathManager.save()
    if PathManager.pathsFile then
        fs.FileSystem.writeFile(PathManager.pathsFile, table.concat(PathManager.paths, '\n'))
    end
end

function PathManager.addPath(path)
    path = fs.FileSystem.normalPath(path)
    table.insert(PathManager.paths, path)
    PathManager.save()
end

function PathManager.removePath(index)
    if index < 1 or index > #PathManager.paths then
        return false
    end

    table.remove(PathManager.paths, index)
    PathManager.save()
    return true
end

function PathManager.getPaths()
    return PathManager.paths
end

function PathManager.clear()
    PathManager.paths = {}
    PathManager.pathsFile = nil
end

return PathManager
