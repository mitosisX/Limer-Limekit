selIconPath = "" -- The path for the app icon, the user selected

projectJsonStruct = {
    project = {
        name = "",
        author = "",
        description = "",
        copyright = "",
        version = "",
        email = ""
        -- lua_require = ""
    }
}

function processProjectCreation()
    userProjectNamePicked = createNameLineEdit:getText()
    userProjectVersionPicked = createVersionLineEdit:getText()

    if userProjectNamePicked ~= "" and userProjectVersionPicked ~= "" then
        if selIconPath ~= "" then
            createUserProject(userProjectNamePicked, userProjectVersionPicked)
        else
            app.warningAlertDialog(window, 'Not complete', 'Please select an image for your window')
        end
    else
        app.warningAlertDialog(window, 'Not complete', 'Make sure all fields are filled')
    end
end

-- This handles all the user project creation
function createUserProject(userProjectNamePicked, userProjectVersionPicked)

    userProjectFolder = app.joinPaths(limekitProjectsFolder, userProjectNamePicked)

    if not app.exists(userProjectFolder) then
        projectJsonStruct.project.name = userProjectNamePicked
        projectJsonStruct.project.version = userProjectVersionPicked

        app.createFolder(userProjectFolder) -- create the folder for the new project

        scriptsFolder = app.joinPaths(userProjectFolder, 'scripts')
        imagesFolder = app.joinPaths(userProjectFolder, 'images')
        miscFolder = app.joinPaths(userProjectFolder, 'misc')

        -- Create all required project folders and fields

        app.createFile(app.joinPaths(userProjectFolder, '.require'))
        app.createFolder(scriptsFolder)
        app.createFolder(imagesFolder)
        app.createFolder(miscFolder)

        userProjectFile = app.joinPaths(userProjectFolder, 'app.json')

        writeToConsole(userProjectFile)

        mainLuaStruct =
            "-- Welcome to the new era for modern lua gui development\nwindow = Window{title='New app - Limekit', icon = images('app.png'), size={400, 200}}\nwindow:show()"

        -- Now write to the main.lua
        app.writeFile(app.joinPaths(scriptsFolder, 'main.lua'), mainLuaStruct)
        app.writeFile(userProjectFile, json.stringify(projectJsonStruct))

        app.copyFile(selIconPath, app.joinPaths(imagesFolder, 'app.png'))

        modal:dismiss()

        writeToConsole('Created at ' .. userProjectFolder)
        app.alert(window, 'Success!', 'Project has been created')
    else
        app.criticalAlertDialog(window, 'Project already exists.', 'Could not create the project.')
    end

end
