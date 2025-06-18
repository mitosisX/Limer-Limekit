local Styles = require("gui.styles.init")

local Theme = {
    current = "light", -- Default theme
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
    Theme.current = themeName
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

    -- Find which theme corresponds to the button's current text
    -- for themeName, theme in pairs(Theme.themes) do
    --     if theme.displayName == buttonText then
    --         local nextTheme = Theme.themes[theme.next]
    --         button:setText(nextTheme.displayName)
    --         button:setIcon(images(nextTheme.icon))
    --         Theme.apply(nextTheme.style)
    --         return
    --     end
    -- end
end

-- Initialize
Theme.themeEngine:setTheme(Theme.current)

return {
    apply = Theme.apply,
    toggleTheme = Theme.toggleTheme,
    currentTheme = Theme.current
}
