--[[
							Limer

			Copyright: Take bytes
			Author: Omega Msiska

			(Note: This source code is provided unobfuscated, commented and written in the simplest lua syntax
			possible in the hope that it is useful for educational purposes. It remains the copyright of the author)

		v 1.0
		Development Started: 10 November, 2023

]] --
currentTheme = 'light'

theme = app.Theme('darklight')
theme:setTheme(currentTheme)

json = require 'json'         -- to handle every json in this app

local APP_FONT_SIZE = 9.9     -- The app font size, for whatever reason, using 10 makes the window not fullscreen
local APP_WINDOW_WIDTH = 1000 -- App window width
local APP_WINDOW_HEIGHT = 400 -- App window height

-- System related
projectRunnerProcess = None -- The process handling the execution of user program

-- User files and folders
documentsFolder = app.getStandardPath('documents')                         -- locate 'My Documents' folder (system independent)
limekitProjectsFolder = app.joinPaths(documentsFolder, 'limekit projects') -- dir for writing any limekit projects

-- Code Injection
codeInjectionFolder = app.joinPaths(limekitProjectsFolder, '.limekit') -- The dir for code inejction
codeInjectionFile = app.joinPaths(codeInjectionFolder, '_code.lua')    -- The file for code injection

userProjectJSON = None                                                 -- The app.json for each projects
userProjectFolder = ""                                                 -- The folder for the current project
requirePathFile = ""                                                   -- Path to the .require file
allRequirePathsTable = {}                                              -- All paths obtained from the .require file
projectIsRunning = false                                               -- whether or not the app is running

userScriptsFolder = ""
useImagesFolder = ""
userMiscFolder = ""
--- END: User files and folders
---
---

-- Create the user projects folder if it doesn't exist yet
if not app.exists(limekitProjectsFolder) then
	app.createFolder(limekitProjectsFolder)
end

limekitWindow = Window {
	title = "Limer - Take bytes",
	icon = route('app_icon'),
	size = { APP_WINDOW_WIDTH, APP_WINDOW_HEIGHT }
}

limekitWindow:setOnShown(function()
	limekitWindow:maximize()

	fetchAllProjectsForUser() -- Fetch all projects for the user
end)


require 'views.tabs.styles.main'
require 'common.styles.main'
require 'common.utils.main'
require 'views.homepage.welcome'
require 'views.menus.main'
require 'views.toolbar.main'
require 'views.tabs.main'
require 'views.docks.main'

-- app.setFontFile(misc('fonts/Comfortaa-Regular.ttf'), APP_FONT_SIZE)
app.setFontSize(APP_FONT_SIZE)

mainLay = VLayout()  -- The master layout for the whole app

consoCodeTab = Tab() -- The Tab holding the console and code injection tabs

-- The console log Tab
consoleLogTab = Container()
consoLay = VLayout()

logConsole = TextField()     -- The application's console log
logConsole:setReadOnly(true) -- console shouldn't be edited
consoLay:addChild(logConsole)
consoleLogTab:setLayout(consoLay)

consoCodeTab:addTab(consoleLogTab, 'Console Log')

-- The remote code execution tab

remoteCodeExecutionItem = Container()
codeInjectionLay = VLayout()

codeInjHLay = HLayout()
codeInjHLay:setContentAlignment('left')
-- codeInjHLay:addStretch()

runInjectionCodeButton = Button('Run')
runInjectionCodeButton:setEnabled(false)
runInjectionCodeButton:setOnClick(function()
	if not projectIsRunning then end

	local injectionCodeContent = codeInjectionField:getText()

	if injectionCodeContent ~= "" then
		-- local result = app.executeCode(injectionCodeContent) -- execute the code in the field
		-- logConsole:appendText(result) -- append the result to the console log
		app.writeFile(codeInjectionFile, injectionCodeContent)
	else
		app.criticalAlertDialog(limekitWindow, 'Error!',
			"You'll need to write some code first...")
	end
end)
runInjectionCodeButton:setResizeRule('fixed', 'fixed')

resetCodeInjectionFieldButton = Button('Clear')
resetCodeInjectionFieldButton:setOnClick(function(sender)
	codeInjectionField:clear()
	print(projectIsRunning and 'Yes' or 'No')
end)
resetCodeInjectionFieldButton:setResizeRule('fixed', 'fixed')

codeInjHLay:addChild(runInjectionCodeButton)
codeInjHLay:addChild(resetCodeInjectionFieldButton)

-- codeInjHLay:addStretch()

codeInjectionLay:addLayout(codeInjHLay)

codeInjectionField = TextField() -- Where injection code will be retrieved
-- codeInjectionField:setOnKeyPress(function(sender, event)
-- 	-- print(event)
-- 	if KeyBoard.pressed(event, 'Ctrl+Shift+A') then
-- 		print('Key binding')
-- 	elseif KeyBoard.pressed(event, 'Key_F1') then
-- 		print('F1 key presses')
-- 	end
-- end)
codeInjectionField:setHint('Enter injection code here...')
codeInjectionField:setToolTip(
	"Code entered here will be used to alter your running program")
codeInjectionField:setOnTextChange(function(sender, text)
	if string.len(text) > 1 and projectIsRunning then
		runInjectionCodeButton:setEnabled(true)
	else
		runInjectionCodeButton:setEnabled(false)
	end
end)
codeInjectionLay:addChild(codeInjectionField)
remoteCodeExecutionItem:setLayout(codeInjectionLay)

consoCodeTab:addTab(remoteCodeExecutionItem, 'Code Injection')

logConsole:setMaxHeight(150)

menubar = Menubar()
menubar:buildFromTemplate(appMenubarItems) -- derived from common/menus.lua
limekitWindow:setMenubar(menubar)

limekitWindow:addToolbar(toolbar)

limekitWindow:addDock(widgetsDock, 'left')
limekitWindow:addDock(appUtilsDock, 'left')
limekitWindow:addDock(pyUtilsDock, 'left')
limekitWindow:addDock(appFolderDock, 'right')
limekitWindow:addDock(userProjectsListDock, 'right')

homescreenSplitter = Splitter('vertical')

homeStackedWidget = SlidingStackedWidget() -- Holds the home page and app's page
homeStackedWidget:setOrientation('vertical')
homeStackedWidget:setAnimation('OutExpo')
-- homeStackedWidget.autoStart() -- should comment out this one

homeStackedWidget:addLayout(welcomeView)
homeStackedWidget:addChild(allAppTabs)         -- The Tab holding App, Assets, Properties..

homescreenSplitter:addChild(homeStackedWidget) -- home page - from components
homescreenSplitter:addChild(consoCodeTab)

limekitWindow:setMainChild(homescreenSplitter)
limekitWindow:show()
