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
    local ok, why = Files.validName(name)
    if not ok then return nil, why end
    local dir = generatedDir(project)
    if not FS.exists(dir) then FS.createFolder(dir) end
    local path = Files.generatedPath(project, name)
    local ok, err = pcall(FS.writeFile, path, source)
    if not ok then return nil, tostring(err) end
    return path
end

--- A throwaway project that shows the design and nothing else, so the
--- normal project runner can run it. Lives under design/.preview/ so it
--- travels with the project and is easy to delete. Returns its path.
function Files.writePreview(project, name, source)
    local dir = FS.joinPaths(designDir(project), ".preview")
    local scripts = FS.joinPaths(dir, "scripts")
    local designed = FS.joinPaths(scripts, "designed")
    for _, folder in ipairs({ designDir(project), dir, scripts, designed }) do
        if not FS.exists(folder) then FS.createFolder(folder) end
    end
    local ok, err = pcall(function()
        FS.writeFile(FS.joinPaths(dir, "app.json"),
            '{ "api": "2.0", "project": { "name": "' .. name .. ' (preview)", "version": "0" }, "files": { "aliases": {} } }\n')
        FS.writeFile(FS.joinPaths(designed, name .. ".lua"), source)
        FS.writeFile(FS.joinPaths(scripts, "main.lua"),
            "-- Preview written by Limer's designer. Delete freely.\n" ..
            'local design = require("designed.' .. name .. '").new()\n' ..
            "design.window:show()\n")
    end)
    if not ok then return nil, tostring(err) end
    return dir
end

-- Modules Limer itself writes into scripts/designed/. A design with one of
-- these names would overwrite it on Generate -- and be overwritten back.
Files.RESERVED = { images = true }

--- A design name is a module name, so it has to be a Lua identifier, and
--- not one Limer generates itself. Returns true, or false and why.
function Files.validName(name)
    if type(name) ~= "string" or not name:match("^[%a_][%w_]*$") then
        return false, "a design name must be a Lua identifier: letters, digits, underscores"
    end
    if Files.RESERVED[name] then
        return false, ("%q is reserved: Limer generates scripts/designed/%s.lua itself"):format(name, name)
    end
    return true
end

return Files
