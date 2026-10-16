-- MainWindow Module
-- Application entry point - creates and wires all components together

local ui  = require("limekit.ui")
local res = require("limekit.res")
local sys = require("limekit.sys")

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

    -- A window of its own, built now and hidden until the toolbar's
    -- Designer button (or Ctrl+Shift+D) shows it.
    local designer = DesignerView.create()
    App.setDesigner(designer)

    local projectWorkspace = ProjectWorkspace.create(appTab, propertiesTab)
    App.setProjectWorkspace(projectWorkspace)

    local dockables = Dockables.create()
    App.setDockables(dockables)

    local toolbar = MainToolbar.create()
    App.setToolbar(toolbar)

    local menu = MainMenu.create()

    local window = ui.Window {
        title = "Limer",
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

    -- The welcome page scrolls in a small window rather than setting the
    -- window's minimum width; see project_tab_container for the same.
    local welcome = ui.Container()
    welcome:setLayout(WelcomeView.create())
    local welcomeScroller = ui.Scroller()
    welcomeScroller:setChild(welcome)
    welcomeScroller:setResizable(true)
    homeStackedWidget:addChild(welcomeScroller)
    homeStackedWidget:addChild(projectWorkspace.view)

    local homescreenSplitter = ui.Splitter('vertical')
    homescreenSplitter:addChild(homeStackedWidget)
    homescreenSplitter:addChild(debugTab.tabWidget)
    -- When the window is resized, the workspace takes three quarters of the
    -- change and the console one; without this a short window gave the
    -- console most of the height.
    homescreenSplitter:setStretchFactors({ 3, 1 })

    window:setMainChild(homescreenSplitter)

    -- Closing Limer closes the designer with it -- after asking, if it
    -- holds unsaved work. Otherwise a visible designer would keep the
    -- process alive with Limer's own window gone.
    window:setOnClose(function(_, event)
        if not designer.confirmQuit() then
            event.ignore()
            return
        end
        designer.hide()
    end)

    window:setOnShown(function()
        window:maximize()

        -- Roughly three quarters workspace, one quarter console. Without
        -- this the splitter falls back to the two children's size hints and
        -- gave the console two thirds of the window. The sizes are real
        -- pixels from the maximised height, set a moment later: { 74, 26 }
        -- set here, before the window manager had finished maximising, was
        -- overridden and never took effect.
        sys.Timer.singleShot(250, function()
            local _, height = window:getSize()
            local console = math.max(160, math.floor(height * 0.26))
            homescreenSplitter:setSizes({ height - console, console })
        end)

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
