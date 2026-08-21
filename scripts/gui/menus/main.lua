-- MainMenu Module
-- Defines the application menu bar

local ui  = require("limekit.ui")
local res = require("limekit.res")
local sys = require("limekit.sys")

local Theme = require "app.core.theme"
local Navigation = require "gui.navigation"
local App = require "app.core.app"

local MainMenu = {}

-- 2.0 removed Menubar:buildFromTemplate. 1.x shipped three inconsistent
-- versions of it, disagreeing on how submenus nested, and every one of them
-- bottomed out in addMenuItem/addMenu anyway -- so the table shape lives here,
-- in the module that owns it, rather than in the framework.
--
-- Recognised keys: label ("-" makes a separator), icon, shortcut, click,
-- disabled, submenu.
local function buildMenu(menu, items)
    for _, item in ipairs(items) do
        if item.label == "-" then
            menu:addSeparator()
        elseif item.submenu then
            local sub = ui.Menu(item.label)
            if item.icon then sub:setIcon(item.icon) end
            buildMenu(sub, item.submenu)
            menu:addMenu(sub)
        else
            local entry = ui.MenuItem(item.label)
            if item.icon then entry:setIcon(item.icon) end
            if item.shortcut then entry:setShortcut(item.shortcut) end
            if item.disabled then entry:setEnabled(false) end
            if item.click then entry:setOnClick(item.click) end
            menu:addMenuItem(entry)
        end
    end
    return menu
end

local function buildMenubar(items)
    local menubar = ui.Menubar()
    for _, top in ipairs(items) do
        local menu = ui.Menu(top.label)
        if top.icon then menu:setIcon(top.icon) end
        buildMenu(menu, top.submenu or {})
        menubar:addMenu(menu)
    end
    return menubar
end


function MainMenu.create()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"
    local AboutPage = require "gui.modals.about"

    local menubarItems = {
        {
            label = '&File',
            submenu = {
                {
                    name = 'create_project',
                    label = 'New Project',
                    icon = res.Resources.images('toolbar/new_project.png'),
                    shortcut = "Ctrl+N",
                    click = ProjectCreator.show
                },
                {
                    label = 'Open Project',
                    icon = res.Resources.images('toolbar/open_project.png'),
                    shortcut = "Ctrl+O",
                    click = ProjectManager.openProject
                },
                { label = '-' },
                {
                    label = 'Exit',
                    icon = res.Resources.images('exit.png'),
                    click = function() sys.System.exit() end
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
                    label = "Limekit API...",
                    shortcut = "Ctrl+K",
                    click = function()
                        require("gui.modals.api_palette").show(App.window)
                    end
                },
                { label = "-" },
                {
                    label = "Theme",
                    submenu = {
                        {
                            name = 'light_theme',
                            label = 'Dark',
                            icon = res.Resources.images('app/dark.png'),
                            click = Theme.toggleTheme
                        }
                    }
                }
            }
        },
        {
            label = "&Help",
            submenu = {
                { label = "About Limer", click = AboutPage.show }
            }
        }
    }

    local menubar = buildMenubar(menubarItems)

    return {
        menubar = menubar
    }
end

return MainMenu
