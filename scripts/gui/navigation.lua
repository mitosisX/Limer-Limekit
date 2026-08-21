-- Navigation Module
-- Moves between the home page and the open project.
--
-- These were two toolbar buttons, one of which was always a no-op: the
-- stack has exactly two pages and is clamped at both ends, so whichever
-- page you were on, one of the buttons did nothing. It is one button now,
-- and it names where it will take you.

local App = require "app.core.app"

local HOME = 1

local Navigation = {}

local listeners = {}

--- Called with `true` when the home page becomes the visible one.
function Navigation.observe(handler)
    listeners[#listeners + 1] = handler
end

--- Which page is showing. Mid-slide this already reports the destination,
--- so a handler that runs during the animation still agrees with what the
--- user is about to see.
function Navigation.isOnHome()
    return App.homeStackedWidget:getCurrentIndex() == HOME
end

local function announce()
    for _, handler in ipairs(listeners) do
        handler(Navigation.isOnHome())
    end
end

-- A slide already in flight swallows anything asked of it, while
-- getCurrentIndex reports where it is heading. Acting on a request that is
-- about to be dropped would relabel the button for a page it never reached,
-- so requests during the animation are refused here instead -- which is what
-- the widget does anyway, only visibly consistent.
local function busy()
    return App.homeStackedWidget:isSliding()
end

function Navigation.returnHomePage()
    if busy() then return end
    App.homeStackedWidget:slidePrev()
    announce()
end

function Navigation.returnToMyProject()
    if busy() then return end
    App.homeStackedWidget:slideNext()
    announce()
end

--- Whichever page you are not on.
function Navigation.toggle()
    if Navigation.isOnHome() then
        Navigation.returnToMyProject()
    else
        Navigation.returnHomePage()
    end
end

return Navigation
