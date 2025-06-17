function changeTheme(obj)
    theme_ = obj:getText() -- gets the text available on the button clicked

    if theme_ == 'Light' then
        theme:setTheme('light')
        obj:setText('Dark')
        obj:setIcon(images('app/dark.png')) -- corresponding icon for dark theme
        currentTheme = 'light'

        setUserProjectsListTheme()

        appTabsLightTheme()
    elseif theme_ == 'Dark' then
        theme:setTheme('dark')
        obj:setText('Light')
        obj:setIcon(images('app/light.png')) -- corresponding icon for light theme
        currentTheme = 'dark'

        setUserProjectsListTheme()

        appTabsDarkTheme()
    end
end

currentTheme = 'light'

theme = app.Theme('darklight')
theme:setTheme(currentTheme)

return {
    [changeTheme] = changeTheme,
}
