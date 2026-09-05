-- Files
-- Where designs live and where generated modules go, for one project:
--   design/<name>.design.lua          the design, read back by the designer
--   scripts/designed/<name>.lua       the generated module, never read back

local fs = require("limekit.fs")
local DesignModel = require "app.core.design_model"

local FS = fs.FileSystem
local Files = {}

local function designDir(project) return FS.joinPaths(project, "design") end
local function generatedDir(project) return FS.joinPaths(FS.joinPaths(project, "scripts"), "designed") end

function Files.designPath(project, name)
    return FS.joinPaths(designDir(project), name .. ".design.lua")
end

function Files.generatedPath(project, name)
    return FS.joinPaths(generatedDir(project), name .. ".lua")
end

--- Every design name in the project, sorted.
function Files.list(project)
    local dir = designDir(project)
    if not project or not FS.exists(dir) then return {} end
    local names = {}
    for _, entry in ipairs(FS.listFolder(dir)) do
        local name = tostring(entry):match("([^/\\]+)%.design%.lua$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function Files.load(project, name)
    local ok, text = pcall(FS.readFile, Files.designPath(project, name))
    if not ok then return nil, tostring(text) end
    return DesignModel.deserialize(text)
end

function Files.save(project, name, design)
    local dir = designDir(project)
    if not FS.exists(dir) then FS.createFolder(dir) end
    local ok, err = pcall(FS.writeFile, Files.designPath(project, name), DesignModel.serialize(design))
    if not ok then return false, tostring(err) end
    return true
end

function Files.writeGenerated(project, name, source)
    local dir = generatedDir(project)
    if not FS.exists(dir) then FS.createFolder(dir) end
    local path = Files.generatedPath(project, name)
    local ok, err = pcall(FS.writeFile, path, source)
    if not ok then return nil, tostring(err) end
    return path
end

--- A design name is a module name, so it has to be a Lua identifier.
function Files.validName(name)
    return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

return Files
