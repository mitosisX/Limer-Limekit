-- Navigation Module
-- There is one thing to navigate between: the empty state and an open
-- project. Which of the two you see follows from whether a project is open,
-- so nothing calls these except opening and closing one -- and in
-- particular the toolbar no longer carries a pair of buttons for it.

local App = require "app.core.app"

local Navigation = {}

--- Show the open project. Called when one is loaded.
function Navigation.showWorkspace()
    App.homeStackedWidget:slideNext()
end

--- Show the empty state. Called when the project is closed.
function Navigation.showHome()
    App.homeStackedWidget:slidePrev()
end

return Navigation
