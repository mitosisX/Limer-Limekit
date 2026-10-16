-- Theme Module
-- Handles application theme switching (light/dark)

local ui  = require("limekit.ui")

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

-- Called with the theme's name after every switch. For things a palette
-- change does not reach on its own, such as icons drawn for one background.
local observers = {}

function Theme.observe(fn)
    observers[#observers + 1] = fn
end

function Theme.apply(themeName)
    Theme.active = themeName
    ui.Theme.setTheme(FAMILY, themeName)
    if Theme.styles then
        Theme.styles.applyProjectListBoxStyles(themeName)
    end
    for _, fn in ipairs(observers) do fn(themeName) end
end

--- Light to dark, or dark to light. Every switch -- menu, Limer's toolbar,
--- the designer's toolbar -- comes through here, and everything showing
--- the theme repaints through Theme.observe, so none of them can disagree.
function Theme.toggle()
    Theme.apply(Theme.active == "dark" and "light" or "dark")
end

--- What a theme switch should offer while `active` is on: the label and
--- icon of the other theme.
function Theme.offer()
    if Theme.active == "dark" then return "Light", "app/light.png" end
    return "Dark", "app/dark.png"
end

--- The menu entry's click handler. The entry follows through observe.
function Theme.toggleTheme()
    Theme.toggle()
end

function Theme.getActive()
    return Theme.active
end

return Theme
