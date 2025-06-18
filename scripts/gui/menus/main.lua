local AboutPage = require "gui.modals.about"
local ProjectCreator = require "gui.modals.project_creator"
local Navigation = require "gui.navigation"
local Theme = require "app.core.theme"

-- function that handles changing of themes
-- function switchLightOrDark(menuitem)
--     theme_ = menuitem:getText() -- gets the text available on the button clicked

--     if theme_ == 'Light' then
--         theme:setTheme('light')
--         menuitem:setText('Dark')
--         menuitem:setIcon(images('app/dark.png')) -- corresponding icon for dark theme
--         currentTheme = 'light'

--         setUserProjectsListTheme()

--         appTabsLightTheme()
--     elseif theme_ == 'Dark' then
--         theme:setTheme('dark')
--         menuitem:setText('Light')
--         menuitem:setIcon(images('app/light.png')) -- corresponding icon for light theme
--         currentTheme = 'dark'

--         setUserProjectsListTheme()

--         appTabsDarkTheme()
--     end
-- end

-- The menu items template
local appMenubarItems = {
    {
        label = '&File', -- Accelerator for letter F
        submenu = {
            {
                name = 'create_project',
                label = 'New Project',
                icon = images('toolbar/new_project.png'),
                shortcut = "Ctrl+N",
                click = ProjectCreator.show
            }, {
            label = 'Open Project',
            icon = images('toolbar/open_project.png'),
            shortcut = "Ctrl+O",
            click = ProjectManager.openProject
        },
            -- hyphen adds a separator
            { label = '-' },
            {
                label = 'Exit',
                icon = images('exit.png'),
                click = function() app.exit() end
            }
        }
    }, {
    label = '&View',
    name = 'view',
    submenu = {
        -- { label = "Cut",       shortcut = "Ctrl+C",    icon = images('editor/cut1.png') },
        -- { label = "Copy",      shortcut = "Ctrl+X",    icon = images('editor/copy.png') },
        -- { label = "Paste",     shortcut = "Ctrl+V",    icon = images('editor/paste.png') },
        -- { label = "-" },
        -- { label = "Redo",      shortcut = "Ctrl+Y",    icon = images('editor/redo.png') },
        -- { label = "Undo",      shortcut = "Ctrl+Z",    icon = images('editor/undo.png') },
        -- { label = "-" },
        { label = "Home Page", click = Navigation.returnHomePage, shortcut = "Ctrl+H" },
        -- {label = "Application Log"},
        {
            label = "Theme",
            submenu = {
                {
                    name = 'light_theme',
                    label = 'Dark',
                    icon = images('app/dark.png'),
                    click = Theme.toggleTheme
                }
            }
        }
    }
}, {
    label = "&App",
    submenu = {
        { label = "Run", shortcut = "Ctrl+R", click = runApp }, {
        label = "Stop",
        shortcut = "Ctrl+X",
        click = function(obj)
            if projectRunnerProcess then
                projectRunnerProcess:stop()
            end
        end
    }, { label = "-" }
        -- {
        --     label = "Build",
        --     shortcut = 'Ctrl+B'
        -- }
    }
}, {
    label = "&Help",
    submenu = {
        --     {
        --     label = 'Register'
        -- },
        { label = "About Limer", click = AboutPage }
    }
}
}

menubar = Menubar()
menubar:buildFromTemplate(appMenubarItems)

return { menubar = menubar }
