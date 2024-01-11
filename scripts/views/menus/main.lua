function changeTheme(obj)
    theme_ = obj:getText()

    if theme_ == 'Light' then
        theme:setTheme('light')
        obj:setText('Dark')
        obj:setIcon(images('app/dark.png'))

    elseif theme_ == 'Dark' then
        theme:setTheme('dark')
        obj:setText('Light')
        obj:setIcon(images('app/light.png'))

    end

end

appMenubarItems = {{
    label = '&File',
    submenu = {{
        name = 'create_project',
        label = 'New Project',
        icon = images('toolbar/new_project.png'),
        shortcut = "Ctrl+N",
        click = projectCreator
    }, {
        label = 'Open Project',
        icon = images('toolbar/open_project.png'),
        shortcut = "Ctrl+O",
        click = projectOpener
    }, {
        label = '-'
    }, -- {
    --     label = 'New Database...',
    --     icon = images('database_add.png')
    --     -- shortcut = "Ctrl+N"
    -- }, 
    {
        label = 'Exit',
        icon = images('exit.png'),
        click = function()
            app.exit()
        end
    }}
}, {
    label = '&View',
    name = 'view',
    submenu = {{
        label = "Home Page",
        click = returnHomePage,
        shortcut = "Ctrl+H"
    }, {
        label = "Application Log"
    }, {
        label = "Theme",
        submenu = {{
            name = 'light_theme',
            label = 'Dark',
            icon = images('app/dark.png'),
            click = changeTheme
        }}
    }}
}, {
    label = "&App",
    submenu = {{
        label = "Run",
        shortcut = "Ctrl+R",
        click = runApp
    }, {
        label = "Stop",
        shortcut = "Ctrl+X",
        click = function(obj)
            if projectRunnerProcess then
                projectRunnerProcess:stop()
            end
        end
    }, {
        label = "-"
    }, {
        label = "Build",
        shortcut = 'Ctrl+B'
    }}
}, {
    label = "&Help",
    submenu = {{
        label = 'Register'
    }, {
        label = "About Limekit",
        click = aboutPage
    }}
}}
