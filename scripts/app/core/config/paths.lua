local Paths = {}

-- Path configurations
Paths.documentsFolder = app.getStandardPath('documents')                               -- the "my documents" folder, OS dependent
Paths.limekitProjectsFolder = app.joinPaths(Paths.documentsFolder, 'limekit projects') -- root user projects folder
Paths.codeInjectionFolder = app.joinPaths(Paths.limekitProjectsFolder, '.limekit')     -- where code injection file is stored
Paths.codeInjectionFile = app.joinPaths(Paths.codeInjectionFolder, '_code.lua')        -- the content for code injection

-- Create user projects folder if it doesn't exist
if not app.exists(Paths.limekitProjectsFolder) then
    app.createFolder(Paths.limekitProjectsFolder)
end

return {
    documentsFolder = Paths.documentsFolder,
    limekitProjectsFolder = Paths.limekitProjectsFolder,
    codeInjectionFolder = Paths.codeInjectionFolder,
    codeInjectionFile = Paths.codeInjectionFile
}
