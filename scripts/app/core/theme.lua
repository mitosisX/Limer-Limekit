local Styles = require("gui.styles.init")

local Theme = {
    active = "light", -- Default theme
    themes = {
        Light = {
            displayName = "Light", -- Text shown on the
            next = "Dark",
            icon = "app/dark.png", -- Icon for the opposite theme
            style = "light"        -- Internal theme ID
        },
        Dark = {
            displayName = "Dark",
            next = "Light",
            icon = "app/light.png",
            style = "dark"
        }
    },
    themeEngine = app.Theme("darklight") -- Theme engine (e.g., for UI components)
}

--- Applies a theme and updates styles.
function Theme.apply(themeName)
    Theme.active = themeName
    Theme.themeEngine:setTheme(themeName)
    Styles.applyProjectListBoxStyles(themeName)
end

--- Toggles the theme based on the button's current text.
function Theme.toggleTheme(button)
    local buttonText = button:getText() -- Gets "Light" or "Dark"

    local activeTheme = Theme.themes[buttonText]

    if activeTheme.displayName == buttonText then
        button:setText(activeTheme.next)
        button:setIcon(images(activeTheme.icon))
        Theme.apply(activeTheme.style)
        return
    end
end

-- Initialize
Theme.themeEngine:setTheme(Theme.active)

return {
    apply = Theme.apply,
    toggleTheme = Theme.toggleTheme,
    activeTheme = Theme.active
}
