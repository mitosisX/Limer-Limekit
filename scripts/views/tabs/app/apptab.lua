-- Hold the UI for displaying user project properties; project name, version, etc...
-- Editing/modification of user project is also carried out here
appTabMainLay = VLayout()
appTabMainLay:setContentAlignment('vcenter', 'center')

appTabGroup = GroupBox()

DropShadow(appTabGroup)

appTabGroup:setMinWidth(500)
appTabGroup:setMaxWidth(500)

appContentLay = VLayout()    -- This is where everything inside the GroupBox will reside

appDetailsGroup = GroupBox() -- Holds the layout that holds the icon, run button, location

appDetailsLay = HLayout()    -- The above mentioned layout

loadedAppIcon = Image(images('app/image.png'))
loadedAppIcon:setResizeRule('fixed', 'fixed')
loadedAppIcon:resizeImage(50, 50)

appDetailsLay2 = VLayout()
appDetailsLay2:setContentAlignment('bottom')

loadedAppName = Label("App:")

appDetailsLay2:addChild(loadedAppName)
appDetailsLay2:addChild(Label(string.format('Your OS: <strong>%s</strong>',
    app.getOSName())))

runAppButton = Button('Run')
runAppButton:setResizeRule('fixed', 'fixed')
runAppButton:setIcon(images('app/run.png'))

runAppButton:setOnClick(runApp)

runProgress = ProgressBar()
runProgress:setRange(0, 0)
runProgress:setMaxHeight(5)
-- runProgress:setMaxWidth(20)
runProgress:setResizeRule('maximum', 'maximum')
runProgress:setVisibility(false)

appDetailsLay2:addChild(runAppButton)

appDetailsLay2:addChild(runProgress)

appDetailsLay:addChild(loadedAppIcon)
appDetailsLay:addLayout(appDetailsLay2)

appDetailsGroup:setLayout(appDetailsLay)

appContentLay:addChild(appDetailsGroup)

-- appContentLay:addChild(runProgress)

-- Layouts to hold all details for the app
appDetailsGridLayout = GridLayout()
appDetailsGridLayout:setMargins(0, 40, 0, 0)

appDetailsGridLayout:addChild(Label('App name'), 0, 0)

editAppName = LineEdit()
appDetailsGridLayout:addChild(editAppName, 1, 0)

appDetailsGridLayout:addChild(Label('Author'), 0, 1)
editAppAuthor = LineEdit()
appDetailsGridLayout:addChild(editAppAuthor, 1, 1)

editAppVersion = LineEdit()
appDetailsGridLayout:addChild(Label('Version'), 2, 0)
appDetailsGridLayout:addChild(editAppVersion, 3, 0)

appDetailsGridLayout:addChild(Label('Copyright'), 2, 1)

editAppCopyright = LineEdit()
appDetailsGridLayout:addChild(editAppCopyright, 3, 1)

appDetailsGridLayout:addChild(Label('Description'), 4, 0)

editAppDescription = LineEdit()
appDetailsGridLayout:addChild(editAppDescription, 5, 0)

editAppEmail = LineEdit()
appDetailsGridLayout:addChild(Label('Email'), 4, 1)
appDetailsGridLayout:addChild(editAppEmail, 5, 1)

-- Add the buttons

editAppButtonLay = HLayout()
-- editAppButtonLay:setContentAlignment('right')
editAppButtonLay:addStretch()

saveEditButton = Button('Save')
saveEditButton:setIcon(images('editor/normal.png'))
saveEditButton:setOnClick(function()
    askToSave = app.questionAlertDialog(limekitWindow, 'Confirm',
        'Are you sure you want to save the modification?')

    if askToSave then
        newAppName = editAppName:getText()

        userProjectJSON.project.name = newAppName
        userProjectJSON.project.version = editAppVersion:getText()
        userProjectJSON.project.author = editAppAuthor:getText()
        userProjectJSON.project.copyright = editAppCopyright:getText()
        userProjectJSON.project.description = editAppDescription:getText()
        userProjectJSON.project.email = editAppEmail:getText()

        app.writeFile(app.joinPaths(userProjectFolder, 'app.json'),
            json.stringify(userProjectJSON))

        loadedAppName:setText(string.format('App: <strong>%s</strong> ',
            newAppName))

        writeToConsole('project updated successfuly')
    else
        writeToConsole('Not saving')
    end
end)

revertEditButton = Button('Revert')
revertEditButton:setIcon(images('homepage/create_project/cancel.png'))

editAppButtonLay:addChild(saveEditButton)
editAppButtonLay:addChild(revertEditButton)

appContentLay:addLayout(appDetailsGridLayout)
appContentLay:addLayout(editAppButtonLay)
appTabGroup:setLayout(appContentLay)

appTabMainLay:addChild(appTabGroup)
