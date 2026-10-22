-- Paths Configuration Module
-- Defines all application paths

local fs  = require("limekit.fs")
local sys = require("limekit.sys")

local Paths = {}

Paths.documentsFolder = sys.System.getStandardPath('documents')
Paths.limekitProjectsFolder = fs.FileSystem.joinPaths(Paths.documentsFolder, 'limekit projects')

function Paths.ensureFoldersExist()
    if not fs.FileSystem.exists(Paths.limekitProjectsFolder) then
        fs.FileSystem.createFolder(Paths.limekitProjectsFolder)
    end
end

Paths.ensureFoldersExist()

return Paths
