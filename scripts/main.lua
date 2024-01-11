--[[
							Limekit run

			Copyright: Take bytes
			Author: Omega Msiska

			(Note: This source code is provided unobfuscated, commented and written in the simplest lua syntax
			possible in the hope that it is useful for educational purposes. It remains the copyright of the author)

		v 1.0
		Development Started: 10 November, 2023

]] --
theme = app.Theme('darklight')
theme:setTheme('light')

json = require 'json'

-- System related
projectRunnerProcess = None -- The process handling the execution of user program

-- User files and folders
documentsFolder = app.getStandardPath('documents')
limekitProjectsFolder = app.joinPaths(documentsFolder, 'limekit projects')
userProjectJSON = None -- The app.json for each projects
userProjectFolder = "" -- The folder for the current project
requirePathFile = "" -- Path to the .require file
allRequirePathsTable = {} -- All paths obtained from the .require file
isRunning = false -- whether or not the app is running

scriptsFolder = ""
imagesFolder = ""
miscFolder = ""
--- END: User files and folders

app.execute(scripts('commons/functions/main.lua'))
app.execute(scripts('views/homepage/welcome.lua'))
app.execute(scripts('views/menus/main.lua'))
app.execute(scripts('views/toolbar/main.lua'))
app.execute(scripts('views/tabs/main.lua'))
app.execute(scripts('views/docks/main.lua'))

-- Create the user projects folder if it doesn't exist yet
if not app.exists(limekitProjectsFolder) then
    app.createFolder(limekitProjectsFolder)
end

window = Window {
    title = "Limer - Take bytes",
    icon = route('app_icon'),
    size = {1000, 600}
}

window:setOnShown(function()
    window:maximize()
end)

app.setFontFile(misc('Comfortaa-Regular.ttf'), 8)

mainLay = VLayout() -- The master layout for the whole app

segmentation = Splitter('horizontal')

-- db = Sqlite3('D:/sandbox/limekit.db')

menubar = Menubar()
menubar:buildFromTemplate(appMenubarItems) -- derived from commons/menus.lua
window:setMenubar(menubar)

window:addToolbar(toolbar)

segmentation:addChild(toolboxDock)

seg = Splitter('vertical')

homeStackedWidget = SlidingStackedWidget() -- Holds the home page and app's page
homeStackedWidget:setOrientation('vertical')
homeStackedWidget:setAnimation('OutExpo')
-- homeStackedWidget.autoStart() -- should comment out this one

homeStackedWidget:addLayout(welcomeView)
homeStackedWidget:addChild(allAppTabs) -- The Tab holding App, Assets, Properties..

seg:addChild(homeStackedWidget) -- home page - from components
seg:addChild(appLogDock)

segmentation:addChild(seg)
segmentation:addLayout(docksLay)

mainLay:addChild(segmentation)

window:setLayout(mainLay)
window:show()
