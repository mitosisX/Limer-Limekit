-- Paths Configuration Module
-- Defines all application paths

local Paths = {}

Paths.documentsFolder = app.getStandardPath('documents')
Paths.limekitProjectsFolder = app.joinPaths(Paths.documentsFolder, 'limekit projects')
Paths.codeInjectionFolder = app.joinPaths(Paths.limekitProjectsFolder, '.limekit')
Paths.codeInjectionFile = app.joinPaths(Paths.codeInjectionFolder, '_code.lua')

function Paths.ensureFoldersExist()
    if not app.exists(Paths.limekitProjectsFolder) then
        app.createFolder(Paths.limekitProjectsFolder)
    end
end

Paths.ensureFoldersExist()

return Paths
