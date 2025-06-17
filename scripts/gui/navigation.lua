local Navigation = {}

function Navigation.returnHomePage()
    homeStackedWidget:slidePrev()
end

function Navigation.returnToMyProject()
    homeStackedWidget:slideNext()
end

return Navigation
