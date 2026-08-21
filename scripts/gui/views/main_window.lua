-- MainWindow Module
-- Application entry point - creates and wires all components together

local ui  = require("limekit.ui")
local res = require("limekit.res")

local App = require "app.core.app"
local Styles = require "gui.styles.init"
local Theme = require "app.core.theme"
local ProjectManager = require "app.core.project_manager"

local Console = require "gui.views.console.console"
local InspectorView = require "gui.views.inspector.view"
local DesignerView = require "gui.views.designer.view"
local AppTab = require "gui.tabs.app_tab"
local PropertiesTab = require "gui.tabs.properties_tab"
local DebugTab = require "gui.tabs.debug_tab"
local ProjectWorkspace = require "gui.components.project_tab_container"
local Dockables = require "gui.dockables.init"
local MainToolbar = require "gui.toolbars.toolbar"
local MainMenu = require "gui.menus.main"
local WelcomeView = require "gui.views.homepage.welcome"
local Shortcuts = require "gui.shortcuts"

local MainWindow = {}

function MainWindow.create()
    local console = Console.create()
    App.setConsole(console)

    local inspectorView = InspectorView.create()
    App.setInspectorTab(inspectorView)

    local appTab = AppTab.create()
    App.setAppTab(appTab)

    local propertiesTab = PropertiesTab.create()
    App.setPropertiesTab(propertiesTab)

    local debugTab = DebugTab.create(console, inspectorView)
    App.setDebugTab(debugTab)

    local designerTab = DesignerView.create()
    App.setDesignerTab(designerTab)

    local projectWorkspace = ProjectWorkspace.create(appTab, propertiesTab, designerTab)
    App.setProjectWorkspace(projectWorkspace)

    local dockables = Dockables.create()
    App.setDockables(dockables)

    local toolbar = MainToolbar.create()
    App.setToolbar(toolbar)

    local menu = MainMenu.create()

    local window = ui.Window {
        title = "Limer - Rézolu",
        icon = res.Resources.images('app/lemon.png')
    }
    App.setWindow(window)

    -- ponytail: a window-level stylesheet overrides the darklight app palette → white widgets.
    -- Fold these rules into the theme stylesheets if you want them back. See gui/styles/general_styles.lua.
    -- window:setStyle(Styles.GENERAL_STYLES)

    local homeStackedWidget = ui.SlidingStackedWidget()
    homeStackedWidget:setOrientation('vertical')
    homeStackedWidget:setAnimation('OutExpo')
    App.setHomeStackedWidget(homeStackedWidget)

    Theme.init(Styles)

    window:setMenubar(menu.menubar)
    window:addToolbar(toolbar.toolbar)
    window:addDockable(dockables.projectFilesDock.dock, 'left')
    window:addDockable(dockables.userProjectsListDock.userProjectsListDock, 'right')

    homeStackedWidget:addLayout(WelcomeView.create())
    homeStackedWidget:addChild(projectWorkspace.view)

    local homescreenSplitter = ui.Splitter('vertical')
    homescreenSplitter:addChild(homeStackedWidget)
    homescreenSplitter:addChild(debugTab.tabWidget)

    window:setMainChild(homescreenSplitter)

    window:setOnShown(function()
        window:maximize()

        -- Roughly three quarters workspace, one quarter console. Without
        -- this the splitter falls back to the two children's size hints and
        -- gives the console close to half the window, which is far more than
        -- a few lines of output needs. Set after maximize, because the sizes
        -- are shared out against the window's actual height and setting them
        -- against the pre-maximised one is immediately overridden.
        homescreenSplitter:setSizes({ 74, 26 })

        ProjectManager.listAvailableProjects()
    end)

    Styles.applyProjectListBoxStyles(Theme.active)

    -- Held on the App table because a KeyboardShortcut whose only
    -- reference is a local dies with this function.
    App.shortcuts = Shortcuts.attach(window)

    App.markInitialized()

    return window
end

return MainWindow
