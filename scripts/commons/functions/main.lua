function writeToConsole(content)
    logConsole:appendText('>> ' .. content)
end

function clearConsole()
    logConsole:setText("")
end

function returnHomePage()
    homeStackedWidget:slidePrev()
end

function projectCreator()
    modal = Modal(window, "Let's get you started - Limekit")
    modal:setMinSize(550, 400)
    modal:setMaxSize(550, 400)

    createMainLayout = HLayout()

    groupB = GroupBox()
    groupB:setBackgroundColor('#307DE1')

    gBLayo = VLayout()
    gBLayo:setContentAlignment('center')

    title1 = Label('<strong>Quick setup</strong>')
    title1:setTextColor('white')

    subTitle1 = Label('Takes seconds to get an app running\n')
    subTitle1:setTextColor('white')

    gBLayo:addChild(title1)
    gBLayo:addChild(subTitle1)

    title2 = Label('<strong>Cross-platform solution</strong>')
    title2:setTextColor('white')
    subTitle2 = Label('Same code for Windows, Linux and macOS\n')
    subTitle2:setTextColor('white')

    gBLayo:addChild(title2)
    gBLayo:addChild(subTitle2)

    title3 = Label('<strong>Intuitive API</strong>')
    title3:setTextColor('white')
    subTitle3 = Label('Our API is friendly even to newbies\n')
    subTitle3:setTextColor('white')

    gBLayo:addChild(title3)
    gBLayo:addChild(subTitle3)

    title4 = Label('<strong>Modern GUI</strong>')
    title4:setTextColor('white')
    subTitle4 = Label('Develop modern looking programs in no time')
    subTitle4:setTextColor('white')

    gBLayo:addChild(title4)
    gBLayo:addChild(subTitle4)

    groupB:setLayout(gBLayo)
    createMainLayout:addChild(groupB)

    createLayout = VLayout()
    createLayout:setMargins(10, 0, 0, 0)
    createMainLayout:addLayout(createLayout)

    createImage = Image(images('homepage/create_project/package.png'))
    createImage:setImageAlign('center')

    createHeader = Label('<strong>Create your project</strong>')
    createHeader:setTextAlign('center')

    createName = Label('Name')
    createNameLineEdit = LineEdit()

    createVersion = Label('Version')
    createVersionLineEdit = LineEdit()
    createVersionLineEdit:setText('1.0')

    createIcon = Label('Window icon')
    createIcon:setWhatsThis('The icon that shows on your window') -- Right click to show the 'Whats This'

    createIconImage = Label()
    createIconImage:setImage(images('homepage/create_project/pick_image.png'))
    createIconImage:setCursor('pointinghand')
    createIconImage:setOnClick(function(obj)
        selIcon = app.openFileDialog(window, "Pick and image for the app", "", {
            ["App Icon"] = {".png"}
        })

        if selIcon ~= "" then
            selIconPath = selIcon

            -- set the image picked and do some resize
            if selIconPath then
                obj:setImage(selIconPath)
                obj:resizeImage(50, 50)
            end
        end
    end)

    createButton = Button('Create')
    createButton:setIcon(images('homepage/create_project/done.png'))
    createButton:setOnClick(processProjectCreation)

    -- Now, display everything all together
    createLayout:addChild(createImage)
    createLayout:addChild(createHeader)

    createLayout:addChild(createName)
    createLayout:addChild(createNameLineEdit)

    createLayout:addChild(createVersion)
    createLayout:addChild(createVersionLineEdit)

    createLayout:addChild(createIcon)
    createLayout:addChild(createIconImage)

    createLayout:addChild(createButton)

    -- buttons = modal:getButtons({'ok', 'cancel'})
    -- v:addChild(buttons)

    modal:setLayout(createMainLayout)

    modal:show()
end

-- Takes the app.json path and does the initialization

function initProject(projectFile)
    homeStackedWidget:slideNext() -- switch from home page to app's page

    userProjectFolder = string.match(file, '.*/') -- This gets the folder for the selected project
    readPackagePaths()

    userProjectJSON = json.parse(app.readFile(projectFile)) -- the app.json

    scriptsFolder = app.joinPaths(userProjectFolder, 'scripts')
    imagesFolder = app.joinPaths(userProjectFolder, 'images')
    miscFolder = app.joinPaths(userProjectFolder, 'misc')

    local appName = userProjectJSON.project.name -- will be used in multiple location

    loadedAppName:setText(py.str_format('App: <strong>{}</strong> ', appName))

    editAppName:setText(appName)
    editAppVersion:setText(userProjectJSON.project.version)
    editAppAuthor:setText(userProjectJSON.project.author)
    editAppCopyright:setText(userProjectJSON.project.copyright)
    editAppDescription:setText(userProjectJSON.project.description)
    editAppEmail:setText(userProjectJSON.project.email)

    local windowIcon = app.joinPaths(imagesFolder, 'app.png')

    loadedAppIcon:setImage(windowIcon)
    loadedAppIcon:resizeImage(50, 50) -- maintain our initial 50x50 size when switching between user app images
end

function projectOpener()
    file = app.openFileDialog(window, "Open a project", limekitProjectsFolder, {
        ["Limekit app"] = {".json"}
    })

    if file ~= "" then
        initProject(file)

        local theRecentProject = MenuItem(userProjectJSON.project.name)
        theRecentProject:setOnClick(function()
            initProject(app.joinPaths(userProjectFolder, 'app.json'))
        end)
        -- theRecentProject:setIcon(windowIcon)

        recentProjectsMenu:addMenuItem(theRecentProject)

    end
end

-- 24 November, 2023 (12:29 PM)
-- This is where all the magic happens ;-)

function runProject()
    clearConsole()

    writeToConsole('Please wait while running your app')

    projectRunnerProcess = app.runProject(userProjectFolder) -- Setting the global var in main.lua

    projectRunnerProcess:setOnProcessReadyRead(function(data)
        if string.find(data, 'Error:') or string.find(data, 'ython>"]') then
            writeToConsole("<span style='color:red;'>" .. data .. '</span>')
        else
            writeToConsole(data)
        end
    end)

    projectRunnerProcess:setOnProcessStarted(function()
        writeToConsole('<strong>Starting app</strong>')

        runAppButton:setText('Stop')
        runAppButton:setIcon(images('app/stop.png'))
        runProgress:setVisibility(true)

    end)

    projectRunnerProcess:setOnProcessFinished(function()
        isRunning = false
        writeToConsole('<strong>App closed</strong>')

        runAppButton:setText('Run')
        runAppButton:setIcon(images('app/run.png'))
        runProgress:setVisibility(false)

    end)

    projectRunnerProcess:run()
end

-- The .require file in the user folder
function readPackagePaths()
    requirePathFile = app.joinPaths(userProjectFolder, '.require')

    if app.exists(requirePathFile) then
        pathsList:clear()

        pathsList:addItem('default: misc')

        local readTheFile = app.readFile(requirePathFile)
        allRequirePathsTable = app.splitString(readTheFile, '\n')

        pathsList:setItems(allRequirePathsTable)
    end
end

function packagePathsWriter()
    local concatPaths = table.concat(allRequirePathsTable, '\n')

    app.writeFile(requirePathFile, concatPaths)

end

function runApp()
    if not isRunning then
        isRunning = true
        -- runAppButton:setResizeRule('fixed', 'fixed')
        runProject()
    else
        isRunning = false
        projectRunnerProcess:stop()
    end
end

function aboutPage()
    modal = Modal(window, "About Limer")
    modal:setMinSize(550, 400)
    modal:setMaxSize(550, 400)

    createMainLayout = HLayout()

    groupB = GroupBox()
    groupB:setBackgroundColor('#307DE1')

    theGroupLay = HLayout()

    gi = GifPlayer(images(app.randomChoice({'homepage/sheep.gif', 'homepage/cat.gif'})))
    gi:setSize(120, 120)
    gi:setResizeRule('fixed', 'fixed')
    gi:setMargins(90, 0, 0, 0)

    theGroupLay:addChild(gi)

    theGroupLay:addChild(VLine())

    gBLayo = VLayout()
    gBLayo:setContentAlignment('center')

    aboutNameTitle = Label('<strong>Name</strong>')
    aboutNameTitle:setTextColor('white')

    aboutName = Label('Limekit\n')
    aboutName:setTextColor('white')

    gBLayo:addChild(aboutNameTitle)
    gBLayo:addChild(aboutName)

    aboutVersionTitle = Label('<strong>Version</strong>')
    aboutVersionTitle:setTextColor('white')

    aboutVersion = Label('1.0 (wonder)\n')
    aboutVersion:setTextColor('white')

    gBLayo:addChild(aboutVersionTitle)
    gBLayo:addChild(aboutVersion)

    aboutChiefTitle = Label('<strong>Chief Developer</strong>')
    aboutChiefTitle:setTextColor('white')

    aboutChief = Label('Omega Msiska\n')
    aboutChief:setTextColor('white')

    gBLayo:addChild(aboutChiefTitle)
    gBLayo:addChild(aboutChief)

    title3 = Label('<strong>Company</strong>')
    title3:setTextColor('white')
    subTitle3 = Label('Take bytes\n')
    subTitle3:setTextColor('white')

    gBLayo:addChild(title3)
    gBLayo:addChild(subTitle3)

    title4 = Label('<strong>My github</strong>')
    title4:setTextColor('white')
    subTitle4 = Label('mitosisx')
    subTitle4:setTextColor('white')

    gBLayo:addChild(title4)
    gBLayo:addChild(subTitle4)

    theGroupLay:addLayout(gBLayo)
    groupB:setLayout(theGroupLay)
    createMainLayout:addChild(groupB)

    -- buttons = modal:getButtons({'ok', 'cancel'})
    -- v:addChild(buttons)

    modal:setLayout(createMainLayout)

    modal:show()
end
