-- App Singleton
-- Central application hub that holds all shared references
-- This replaces the global variables pattern with explicit dependency management

local App = {
    -- UI References (set during initialization)
    window = nil,
    homeStackedWidget = nil,

    -- Module References (set during initialization)
    toolbar = nil,
    dockables = nil,
    appTab = nil,
    propertiesTab = nil,
    codeInjectorTab = nil,
    debugTab = nil,
    projectWorkspace = nil,
    console = nil,

    -- Services
    theme = nil,
    styles = nil,
    projectManager = nil,
    projectRunner = nil,

    -- State
    isInitialized = false
}

function App.setWindow(window)
    App.window = window
end

function App.setHomeStackedWidget(widget)
    App.homeStackedWidget = widget
end

function App.setToolbar(toolbar)
    App.toolbar = toolbar
end

function App.setDockables(dockables)
    App.dockables = dockables
end

function App.setAppTab(appTab)
    App.appTab = appTab
end

function App.setPropertiesTab(propertiesTab)
    App.propertiesTab = propertiesTab
end

function App.setCodeInjectorTab(codeInjectorTab)
    App.codeInjectorTab = codeInjectorTab
end

function App.setDebugTab(debugTab)
    App.debugTab = debugTab
end

function App.setProjectWorkspace(projectWorkspace)
    App.projectWorkspace = projectWorkspace
end

function App.setConsole(console)
    App.console = console
end

function App.setTheme(theme)
    App.theme = theme
end

function App.setStyles(styles)
    App.styles = styles
end

function App.setProjectManager(projectManager)
    App.projectManager = projectManager
end

function App.setProjectRunner(projectRunner)
    App.projectRunner = projectRunner
end

function App.markInitialized()
    App.isInitialized = true
end

return App
