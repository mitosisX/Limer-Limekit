local widgetMap = require("data/widgets")

widgetsList = ListBox()
widgetsList:addImageItems(widgetMap)

widgetsDock = Dockable("widgets")
widgetsDock:setMinWidth(300)
widgetsDock:setChild(widgetsList)

return widgetsDock