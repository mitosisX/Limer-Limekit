-- Navigation Module
-- Moves between the home page and the open project.
--
-- These were two toolbar buttons, one of which was always a no-op: the
-- stack has exactly two pages and is clamped at both ends, so whichever
-- page you were on, one of the buttons did nothing. It is one button now,
-- and it names where it will take you.

local App = require "app.core.app"

local Navigation = {}

-- Which page is showing, held here rather than read back off the widget.
-- Mid-slide `getCurrentIndex` reports where the stack is heading rather
-- than where it is, so asking it answers a question about the future.
local showingHome = true

local listeners = {}

--- Called with `true` when the home page becomes the visible one.
function Navigation.observe(handler)
    listeners[#listeners + 1] = handler
end

--- Which page is showing.
function Navigation.isOnHome()
    return showingHome
end

local function announce()
    for _, handler in ipairs(listeners) do
        handler(showingHome)
    end
end

-- A slide already in flight swallows anything asked of it. Acting on a
-- request that is about to be dropped would leave the button naming a page
-- it never reached, so those requests are refused here instead.
local function busy()
    return App.homeStackedWidget:isSliding()
end

--- Returns whether the move was accepted.
function Navigation.returnHomePage()
    if showingHome or busy() then return false end

    App.homeStackedWidget:slidePrev()
    showingHome = true
    announce()
    return true
end

--- Returns whether the move was accepted.
function Navigation.returnToMyProject()
    if not showingHome or busy() then return false end

    App.homeStackedWidget:slideNext()
    showingHome = false
    announce()
    return true
end

--- Goes to whichever page you are not on. Returns whether it moved.
function Navigation.toggle()
    if showingHome then
        return Navigation.returnToMyProject()
    end
    return Navigation.returnHomePage()
end

return Navigation
