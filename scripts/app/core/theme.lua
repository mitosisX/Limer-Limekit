-- Theme Module
-- Handles application theme switching (light/dark)

local Theme = {
    active = "light",
    themes = {
        Light = {
            displayName = "Light",
            next = "Dark",
            icon = "app/dark.png",
            style = "light"
        },
        Dark = {
            displayName = "Dark",
            next = "Light",
            icon = "app/light.png",
            style = "dark"
        }
    },
    themeEngine = nil,
    styles = nil
}

function Theme.init(styles)
    Theme.styles = styles
    Theme.themeEngine = app.Theme("darklight")
    Theme.themeEngine:setTheme(Theme.active)
end

function Theme.apply(themeName)
    Theme.active = themeName
    Theme.themeEngine:setTheme(themeName)
    if Theme.styles then
        Theme.styles.applyProjectListBoxStyles(themeName)
    end
end

function Theme.toggleTheme(button)
    local buttonText = button:getText()
    local activeTheme = Theme.themes[buttonText]

    if activeTheme and activeTheme.displayName == buttonText then
        button:setText(activeTheme.next)
        button:setIcon(images(activeTheme.icon))
        Theme.apply(activeTheme.style)
    end
end

function Theme.getActive()
    return Theme.active
end

return Theme
