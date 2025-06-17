-- Path configurations
documentsFolder = app.getStandardPath('documents')
limekitProjectsFolder = app.joinPaths(documentsFolder, 'limekit projects')
codeInjectionFolder = app.joinPaths(limekitProjectsFolder, '.limekit')
codeInjectionFile = app.joinPaths(codeInjectionFolder, '_code.lua')

-- Create projects folder if it doesn't exist
if not app.exists(limekitProjectsFolder) then
    app.createFolder(limekitProjectsFolder)
end
