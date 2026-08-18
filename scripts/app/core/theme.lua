-- Theme Module
-- Handles application theme switching (light/dark)

local ui  = require("limekit.ui")
local res = require("limekit.res")

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
    styles = nil
}

-- 1.x built a theme engine bound to one family: app.Theme("darklight"). 2.0's
-- ui.Theme is static and takes the family per call, so the family lives here
-- instead of in an object.
local FAMILY = "darklight"


function Theme.init(styles)
    Theme.styles = styles
    ui.Theme.setTheme(FAMILY, Theme.active)
end

function Theme.apply(themeName)
    Theme.active = themeName
    ui.Theme.setTheme(FAMILY, themeName)
    if Theme.styles then
        Theme.styles.applyProjectListBoxStyles(themeName)
    end
end

function Theme.toggleTheme(button)
    local buttonText = button:getText()
    local activeTheme = Theme.themes[buttonText]

    if activeTheme and activeTheme.displayName == buttonText then
        button:setText(activeTheme.next)
        button:setIcon(res.Resources.images(activeTheme.icon))
        Theme.apply(activeTheme.style)
    end
end

function Theme.getActive()
    return Theme.active
end

return Theme
