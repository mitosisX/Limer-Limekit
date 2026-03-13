-- MainWindow Module
-- Application entry point - creates and wires all components together

local App = require "app.core.app"
local Styles = require "gui.styles.init"
local Theme = require "app.core.theme"
local ProjectManager = require "app.core.project_manager"

local Console = require "gui.views.console.console"
local CodeInjector = require "gui.views.codeinjection.injection"
local AppTab = require "gui.tabs.app_tab"
local PropertiesTab = require "gui.tabs.properties_tab"
local DebugTab = require "gui.tabs.debug_tab"
local ProjectWorkspace = require "gui.components.project_tab_container"
local Dockables = require "gui.dockables.init"
local MainToolbar = require "gui.toolbars.toolbar"
local MainMenu = require "gui.menus.main"
local WelcomeView = require "gui.views.homepage.welcome"

local MainWindow = {}

function MainWindow.create()
    local console = Console.create()
    App.setConsole(console)

    local codeInjector = CodeInjector.create()
    App.setCodeInjectorTab(codeInjector)

    local appTab = AppTab.create()
    App.setAppTab(appTab)

    local propertiesTab = PropertiesTab.create()
    App.setPropertiesTab(propertiesTab)

    local debugTab = DebugTab.create(console, codeInjector)
    App.setDebugTab(debugTab)

    local projectWorkspace = ProjectWorkspace.create(appTab, propertiesTab)
    App.setProjectWorkspace(projectWorkspace)

    local dockables = Dockables.create()
    App.setDockables(dockables)

    local toolbar = MainToolbar.create()
    App.setToolbar(toolbar)

    local menu = MainMenu.create()

    local window = Window {
        title = "Limer - Rézolu",
        icon = images('app/lemon.png')
    }
    App.setWindow(window)

    window:setStyle(Styles.GENERAL_STYLES)

    local homeStackedWidget = SlidingStackedWidget()
    homeStackedWidget:setOrientation('vertical')
    homeStackedWidget:setAnimation('OutExpo')
    App.setHomeStackedWidget(homeStackedWidget)

    Theme.init(Styles)

    window:setMenubar(menu.menubar)
    window:addToolbar(toolbar.toolbar)
    window:addDockable(dockables.widgetsDock, 'left')
    window:addDockable(dockables.appUtilsDock, 'left')
    window:addDockable(dockables.pyUtilsDock, 'left')
    window:addDockable(dockables.appFolderDock.appFolderDock, 'right')
    window:addDockable(dockables.userProjectsListDock.userProjectsListDock, 'right')

    homeStackedWidget:addLayout(WelcomeView.create())
    homeStackedWidget:addChild(projectWorkspace.view)

    local homescreenSplitter = Splitter('vertical')
    homescreenSplitter:addChild(homeStackedWidget)
    homescreenSplitter:addChild(debugTab.tabWidget)

    window:setMainChild(homescreenSplitter)

    window:setOnShown(function()
        window:maximize()
        ProjectManager.listAvailableProjects()
    end)

    Styles.applyProjectListBoxStyles(Theme.active)

    App.markInitialized()

    return window
end

return MainWindow
