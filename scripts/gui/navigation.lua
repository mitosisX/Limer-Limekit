-- Navigation Module
-- Handles view navigation within the application

local App = require "app.core.app"

local Navigation = {}

function Navigation.returnHomePage()
    App.homeStackedWidget:slidePrev()
end

function Navigation.returnToMyProject()
    App.homeStackedWidget:slideNext()
end

return Navigation
