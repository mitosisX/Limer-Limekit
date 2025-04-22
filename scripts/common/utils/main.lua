-- Miscellaneous functions used throughout the app

-- User shouldn't inject code when the app is not running
function disableCodeInjectionRunButton()
    runInjectionCodeButton:setEnabled(false)
end

-- Functions to be invoked once the app has been closed
function appCloseCallBack()
    disableCodeInjectionRunButton()
end

local function starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

function appTabsLightTheme()
    allAppTabs:setStyle(appTabLightStyle)
end

function appTabsDarkTheme()
    allAppTabs:setStyle(appTabDarkStyle)
end

-- Hold other xecute when switched to dark mode
function darkModeCallBack()
    appTabsDarkTheme()
end

function lightModeCallBack()
    appTabsLightTheme()
end

-- loads all the user projects and displays them for easy access
function fetchAllProjectsForUser()
    local projectList = app.listFolder(limekitProjectsFolder)
    local foldersOnly = {}
    
    for _, item in ipairs(projectList) do
        local fullPath = app.joinPaths(limekitProjectsFolder, item)

        -- we don't want any hidden folders (folders beginning with a period)
        if app.isFolder(fullPath) and not starts_with(item, '.') then
            table.insert(foldersOnly, item)
        end
    end

    userProjectsList:addItems(foldersOnly) -- set the items for the listbox
end

-- Basically, just sets the userprojects listbox theme
function setUserProjectsListTheme()
    userProjectsList:setStyle(currentTheme == 'light' and userProjectsLightStyle or userProjectsDarkStyle)
end

-- The funtion that writes to the console in the app
function writeToConsole(content)
    logConsole:appendText('>> ' .. content)
end

function createTreeItem(name, icon)
    item = TreeViewItem(name)
    item:setEditable(false)

    item:setIcon(icon)
    -- item.setData({
    --     'full_path': f"/project/{name}",
    --     'last_modified': "2023-11-15"
    -- }, Qt.UserRole)
    return item
end

-- Shows files and folders for the user project
function showUserProjectDir(treeView, path)
    local folders = {}
    local files = {}

    for _, entry in ipairs(app.listFolder(path)) do
        local full_path = app.joinPaths(path, entry)
        --print(full_path)

        -- folder_icon = ""

        if app.isFolder(full_path) then
            -- table.insert(folders, {folder_icon, entry, full_path})
            table.insert(folders, {entry, full_path})
        else
            -- table.insert(files, {file_icon, entry, full_path})
            table.insert(files, {entry, full_path})
            --print(entry)
        end
    end

    for _, entry in ipairs(folders) do
        -- item = TreeViewItem(entry[1])
        local folder_name = entry[1]
        local folder_path = entry[2]

        local item = createTreeItem( folder_name,limekitWindow:getStandardIcon('SP_DirIcon'))

        treeView:addRow(item)
        showUserProjectDir(item, folder_path)
        -- print('FOLDER>>>> ',folder_path)
    end

    for _,  entry in ipairs(files) do
        -- item = TreeViewItem(entry[1])
        local file_name = entry[1]
        local file_path = entry[2]

        local item = createTreeItem(file_name, limekitWindow:getStandardIcon('SP_FileIcon'))
        local item2 = createTreeItem(file_name, limekitWindow:getStandardIcon('SP_FileIcon'))

        treeView:addRow(item)

        -- print('FILE>>>> ', file_path)
    end
end

-- Clears the console text area
function clearConsole()
    logConsole:setText("")
end

-- This function is called to return to the home page from the app's page
function returnHomePage()
    homeStackedWidget:slidePrev()
end

function returnToMyProject()
    homeStackedWidget:slideNext()
end

-- Modal for project creation
-- This is the modal that pops up when the user clicks on 'New Project'
function projectCreator()
    modal = Modal(limekitWindow, "Let's get you started - Limekit")
    modal:setMinSize(550, 400)
    modal:setMaxSize(550, 400)

    createMainLayout = HLayout()

    groupB = GroupBox()
    groupB:setBackgroundColor('#307DE1')

    gBLayo = VLayout()
    gBLayo:setContentAlignment('center')

    title1 = Label('Quick setup')
    title1:setTextColor('white')
    title1:setBold(true)

    subTitle1 = Label('Takes seconds to get an app running\n')
    subTitle1:setTextColor('white')

    gBLayo:addChild(title1)
    gBLayo:addChild(subTitle1)

    title2 = Label('Cross-platform solution')
    title2:setBold(true)
    title2:setTextColor('white')
    subTitle2 = Label('Same code for Windows, Linux and macOS\n')
    subTitle2:setTextColor('white')

    gBLayo:addChild(title2)
    gBLayo:addChild(subTitle2)

    title3 = Label('Intuitive API')
    title3:setBold(true)
    title3:setTextColor('white')
    subTitle3 = Label('Our API is friendly even to beginners\n')
    subTitle3:setTextColor('white')

    gBLayo:addChild(title3)
    gBLayo:addChild(subTitle3)

    title4 = Label('Modern GUI')
    title4:setBold(true)
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
    createImage:setImageAlignment('center')

    createHeader = Label('Create your project')
    createHeader:setBold(true)
    createHeader:setTextAlign('center')
    createHeader:setTextSize(10)

    createName = Label('Name')
    createName:setBold(true)
    createNameLineEdit = LineEdit()

    createVersion = Label('Version')
    createVersion:setBold(true)
    createVersionLineEdit = LineEdit()
    createVersionLineEdit:setText('1.0')

    createIcon = Label('Window icon')
    createIcon:setBold(true)
    createIcon:setWhatsThis('The icon that shows on your limekitWindow') -- Right click to show the 'Whats This'

    createIconImage = Label()
    createIconImage:setImage(images('homepage/create_project/pick_image.png'))
    createIconImage:setCursor('pointinghand')
    createIconImage:setOnClick(function(obj)
        selIcon = app.openFileDialog(limekitWindow, "Pick and image for the app", "", {
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
-- This is where the app.json file is read and the project folder is set
-- Execution when loading a project
function initProject(projectFile)
    homeStackedWidget:slideNext() -- switch from home page to app's page

    userProjectFolder = string.match(file, '.*/') -- This gets the folder for the selected project
    readPackagePaths()

    userProjectJSON = json.parse(app.readFile(projectFile)) -- the app.json

    scriptsFolder = app.joinPaths(userProjectFolder, 'scripts')
    imagesFolder = app.joinPaths(userProjectFolder, 'images')
    miscFolder = app.joinPaths(userProjectFolder, 'misc')

    local appName = userProjectJSON.project.name

    loadedAppName:setText(string.format('App: <strong>%s</strong> ', appName))

    editAppName:setText(appName)
    editAppVersion:setText(userProjectJSON.project.version)
    editAppAuthor:setText(userProjectJSON.project.author)
    editAppCopyright:setText(userProjectJSON.project.copyright)
    editAppDescription:setText(userProjectJSON.project.description)
    editAppEmail:setText(userProjectJSON.project.email)

    local limekitWindowIcon = app.joinPaths(imagesFolder, 'app.png')

    loadedAppIcon:setImage(limekitWindowIcon)
    loadedAppIcon:resizeImage(50, 50) -- maintain our initial 50x50 size when switching between user app images
end

function finalizeProjectOpening(file)
    if file ~= nil then
        initProject(file)

        writeToConsole(file)

        projName = userProjectJSON.project.name -- The name of the project
        
        theRecentProject = MenuItem(projName)
        theRecentProject:setOnClick(function()
            initProject(app.joinPaths(userProjectFolder, 'app.json'))
        end)

        switchToProjectToolbarButton:setEnabled(true)

        appProjectDirTree:clear()

        showUserProjectDir(appProjectDirTree, userProjectFolder)
        -- theRecentProject:setIcon(limekitWindowIcon)

        recentProjectsMenu:addMenuItem(theRecentProject)
        recentProjectsMenu:setOnClick(function()
            -- app.warningAlertDialog(limekitWindow, 'Not complete', projName)
        end)

    end
end

-- This function is called when the user clicks on the 'Open Project' button
function projectOpener()
    file = app.openFileDialog(limekitWindow, "Open a project", limekitProjectsFolder, {
        ["Limekit app"] = {".json"}
    })
    
    finalizeProjectOpening(file)
end


-- 24 November, 2023 (12:29 PM)
-- This is where all the magic happens ;-)

function runProject()
    clearConsole() -- Clear the console before running the new project

    writeToConsole('Please wait while running your app')

    projectRunnerProcess = app.runProject(userProjectFolder) -- The global var in main.lua

    -- configure event listener that gets called when the process is ready to read output
    projectRunnerProcess:setOnProcessReadyRead(function(data)
        if string.find(data, 'Error:') or string.find(data, 'ython>"]') then
            writeToConsole("<span style='color:red;'>" .. data .. '</span>')
        else
            writeToConsole(data)
        end
    end)

    -- Called when the program is being executed
    projectRunnerProcess:setOnProcessStarted(function()
        projectIsRunning = true
        writeToConsole('<strong>Starting app</strong>')

        runAppButton:setText('Stop')
        codeEditorRunAppButton:setText('Stop')
        runAppButton:setIcon(images('app/stop.png'))
        codeEditorRunAppButton:setIcon(images('app/stop.png'))

        runProgress:setVisibility(true)
        codeEditorRunProgress:setVisibility(true)
    end)

    -- Whenever the process is stopped or finished, this function is called
    -- when the app is closed (incase of an error) or the user clicks on stop button
    projectRunnerProcess:setOnProcessFinished(function()
        projectIsRunning = false
        writeToConsole('<strong>App closed</strong>')

        runAppButton:setText('Run')
        codeEditorRunAppButton:setText('Run')
        runAppButton:setIcon(images('app/run.png'))
        codeEditorRunAppButton:setIcon(images('app/run.png'))

        runProgress:setVisibility(false)
        codeEditorRunProgress:setVisibility(false)

        appCloseCallBack() -- all functions to be invoked

    end)

    -- Start the process to run the project
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

-- This function is called to write the paths to the .require file
function packagePathsWriter()
    local concatPaths = table.concat(allRequirePathsTable, '\n')

    app.writeFile(requirePathFile, concatPaths)

end

-- This function is called to start or stop the app
function runApp()
    if not projectIsRunning then
        -- projectIsRunning = true
        -- runAppButton:setResizeRule('fixed', 'fixed')
        runProject()
    else
        projectIsRunning = false
        projectRunnerProcess:stop()
    end
end

-- This function is called to show the About page modal
function aboutPage()
    modal = Modal(limekitWindow, "About Limer")
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

    aboutNameTitle = Label('Name')
    aboutNameTitle:setBold(true)
    aboutNameTitle:setTextColor('white')

    aboutName = Label('Limekit\n')
    aboutName:setTextColor('white')

    gBLayo:addChild(aboutNameTitle)
    gBLayo:addChild(aboutName)

    aboutVersionTitle = Label('Version')
    aboutVersionTitle:setBold(true)
    aboutVersionTitle:setTextColor('white')

    aboutVersion = Label('1.0 (wonder)\n')
    aboutVersion:setTextColor('white')

    gBLayo:addChild(aboutVersionTitle)
    gBLayo:addChild(aboutVersion)

    aboutChiefTitle = Label('Chief Developer')
    aboutChiefTitle:setBold(true)
    aboutChiefTitle:setTextColor('white')

    aboutChief = Label('Omega Msiska\n')
    aboutChief:setTextColor('white')

    gBLayo:addChild(aboutChiefTitle)
    gBLayo:addChild(aboutChief)

    title3 = Label('Company')
    title3:setBold(true)
    title3:setTextColor('white')
    subTitle3 = Label('Take bytes\n')
    subTitle3:setTextColor('white')

    gBLayo:addChild(title3)
    gBLayo:addChild(subTitle3)

    title4 = Label('My github')
    title4:setBold(true)
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