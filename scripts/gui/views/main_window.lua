-- I know the code does not follow best code practices, especially the global variables
-- present in this code. Anyone willing to offer redesign is welcome

json             = require "json"
Theme            = require 'app.core.theme'
local Styles     = require "gui.styles.init"
ProjectRunner    = require "app.core.project_runner"
-- AppState         = require "app.core.app_state"

ProjectManager   = require "app.core.project_manager"
local Menu       = require 'gui.menus.main'
Toolbar          = require 'gui.toolbars.toolbar'.create()
Dockables        = require 'gui.dockables.init'
AppTab           = require 'gui.tabs.app_tab'.create()
CodeInjectorTab  = require "gui.views.codeinjection.injection".create()
local DebugTab   = require "gui.tabs.debug_tab"

local Welcome    = require 'gui.views.homepage.welcome'
ProjectWorkspace = require "scripts.gui.components.project_tab_container".create()

limekitWindow    = Window {
    title = "Limer - Rézolu",
    icon = images('app/lemon.png'),
    -- size = { APP_WINDOW_WIDTH, APP_WINDOW_HEIGHT }
}

limekitWindow:setStyle(Styles.GENERAL_STYLES)

limekitWindow:setOnShown(function()
    limekitWindow:maximize()

    ProjectManager.listAvailableProjects()
end)

-- Setup main layout and components
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

-- The Application and Properties tab, and all tabs accessible after opening a project
homeStackedWidget:addChild(ProjectWorkspace.view)

homescreenSplitter:addChild(homeStackedWidget)
homescreenSplitter:addChild(DebugTab.tabWidget)
-- homescreenSplitter:addChild(ConsoleTab.consoleTab)
-- homescreenSplitter:addChild(CodeInjectorTab.codeInjectionTab)


limekitWindow:setMainChild(homescreenSplitter)

Styles.applyProjectListBoxStyles(Theme.activeTheme)

return limekitWindow
