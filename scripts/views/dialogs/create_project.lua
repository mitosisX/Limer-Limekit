-- This file handles all project creation logic
selIconPath = "" -- The path for the app icon, the user selected

projectJsonStruct = {
    project = {
        name = "",
        author = "",
        description = "",
        copyright = "",
        version = "",
        email = ""
    },
    files = {
        aliases = {}
    }
}

-- This function processes project creation
function processProjectCreation()
    userProjectNamePicked = createNameLineEdit:getText()
    userProjectVersionPicked = createVersionLineEdit:getText()

    if userProjectNamePicked ~= "" and userProjectVersionPicked ~= "" then
        if selIconPath ~= "" then
            createUserProject(userProjectNamePicked, userProjectVersionPicked)
        else
            app.warningAlertDialog(limekitWindow, 'Not complete', 'Please select an image for your Window')
        end
    else
        app.warningAlertDialog(limekitWindow, 'Not complete', 'Make sure all fields are filled')
    end
end

-- Resonates with the above function (processProjectCreation) to finally create the project
-- writing to the app.json file and creating the folders required
-- for the project to be created successfully

function createUserProject(userProjectNamePicked, userProjectVersionPicked)
    userProjectFolder = app.joinPaths(limekitProjectsFolder, userProjectNamePicked)

    if not app.exists(userProjectFolder) then
        projectJsonStruct.project.name = userProjectNamePicked
        projectJsonStruct.project.version = userProjectVersionPicked

        app.createFolder(userProjectFolder) -- create the folder for the new project

        userScriptsFolder = app.joinPaths(userProjectFolder, 'scripts')
        useImagesFolder = app.joinPaths(userProjectFolder, 'images')
        userMiscFolder = app.joinPaths(userProjectFolder, 'misc')

        -- Create all required project folders and fields

        app.createFile(app.joinPaths(userProjectFolder, '.require'))
        app.createFolder(userScriptsFolder)
        app.createFolder(useImagesFolder)
        app.createFolder(userMiscFolder)

        userProjectFile = app.joinPaths(userProjectFolder, 'app.json')

        -- writeToConsole(userProjectFile)

        -- To replace
        mainLuaStruct =
        "-- Welcome to the new era for modern lua gui development\n\nwindow = Window{title='New app - Limekit', icon = images('app.png'), size={400, 400}}\nwindow:show()"

        -- Now write to the main.lua and app.json

        json_string = json.stringify(projectJsonStruct)
        json_formatted = app.formatJSON(json_string)

        app.writeFile(app.joinPaths(userScriptsFolder, 'main.lua'), mainLuaStruct)
        app.writeFile(userProjectFile, json_formatted)

        app.copyFile(selIconPath, app.joinPaths(useImagesFolder, 'app.png'))

        modal:dismiss()

        writeToConsole('Created at ' .. userProjectFolder)

        -- local appFolder = app.joinPaths(limekitProjectsFolder, folder)
        local appJSON = app.joinPaths(userProjectFolder, 'app.json')
        finalizeProjectOpening(appJSON) -- Open the project

        app.alert(limekitWindow, 'Success!', 'Project has been created')
    else
        app.criticalAlertDialog(limekitWindow, 'Project already exists.', 'Could not create the project.')
    end
end
