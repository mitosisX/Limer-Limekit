-- Main window setup
json             = require "json"
Theme            = require 'app.core.theme'
local Styles     = require "gui.styles.init"

ProjectManager   = require "app.core.project_manager"
local Menu       = require 'gui.menus.main'
Toolbar          = require 'gui.toolbars.main'
Dockables        = require 'gui.dockables.init'
AppTab           = require 'gui.tabs.app_tab'.create()
local ConsoleTab = require 'gui.tabs.console'
local Welcome    = require 'gui.views.homepage.welcome'


limekitWindow = Window {
    title = "Limer - Take bytes",
    icon = route('app_icon'),
    -- size = { APP_WINDOW_WIDTH, APP_WINDOW_HEIGHT }
}

limekitWindow:setOnShown(function()
    limekitWindow:maximize()

    -- fetchAllProjectsForUser() -- Fetch all projects for the user
    ProjectManager.listAvailableProjects()
end)

-- Setup main layout and components
local mainLay = VLayout()
homeStackedWidget = SlidingStackedWidget()
homeStackedWidget:setOrientation('vertical')
homeStackedWidget:setAnimation('OutExpo')

local homescreenSplitter = Splitter('vertical')

-- Add components to window
limekitWindow:setMenubar(Menu.menubar)
limekitWindow:addToolbar(Toolbar.toolbar)
limekitWindow:addDockable(Dockables.widgetsDock, 'left')
limekitWindow:addDockable(Dockables.appUtilsDock, 'left')
limekitWindow:addDockable(Dockables.pyUtilsDock, 'left')
limekitWindow:addDockable(Dockables.appFolderDock.appFolderDock, 'right')
limekitWindow:addDockable(Dockables.userProjectsListDock.userProjectsListDock, 'right')


-- Setup main view
homeStackedWidget:addLayout(Welcome.create())

appTab = Container()
appTab:setLayout(AppTab.view)

homeStackedWidget:addChild(appTab)
homescreenSplitter:addChild(homeStackedWidget)
homescreenSplitter:addChild(ConsoleTab.consoleTab)
limekitWindow:setMainChild(homescreenSplitter)

Styles.applyProjectListBoxStyles(Theme.currentTheme)

return limekitWindow
