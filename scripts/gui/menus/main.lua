-- MainMenu Module
-- Defines the application menu bar

local Navigation = require "gui.navigation"
local Theme = require "app.core.theme"
local AppState = require "app.core.app_state"

local MainMenu = {}

function MainMenu.create()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"
    local ProjectRunner = require "app.core.project_runner"
    local AboutPage = require "gui.modals.about"

    local menubarItems = {
        {
            label = '&File',
            submenu = {
                {
                    name = 'create_project',
                    label = 'New Project',
                    icon = images('toolbar/new_project.png'),
                    shortcut = "Ctrl+N",
                    click = ProjectCreator.show
                },
                {
                    label = 'Open Project',
                    icon = images('toolbar/open_project.png'),
                    shortcut = "Ctrl+O",
                    click = ProjectManager.openProject
                },
                { label = '-' },
                {
                    label = 'Exit',
                    icon = images('exit.png'),
                    click = function() app.quit() end
                }
            }
        },
        {
            label = '&View',
            name = 'view',
            submenu = {
                {
                    label = "Home Page",
                    click = Navigation.returnHomePage,
                    shortcut = "Ctrl+H"
                },
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
        },
        {
            label = "&App",
            submenu = {
                {
                    label = "Run",
                    disabled = true,
                    shortcut = "Ctrl+R",
                    click = function()
                        if not AppState.projectIsRunning and AppState.activeProjectPath ~= nil then
                            ProjectRunner.toggle()
                        end
                    end
                },
                {
                    label = "Stop",
                    shortcut = "Ctrl+X",
                    click = function()
                        if AppState.projectIsRunning then
                            ProjectRunner.stop()
                        end
                    end
                },
                { label = "-" }
            }
        },
        {
            label = "&Help",
            submenu = {
                { label = "About Limer", click = AboutPage.show }
            }
        }
    }

    local menubar = Menubar()
    menubar:buildFromTemplate(menubarItems)

    return {
        menubar = menubar
    }
end

return MainMenu
