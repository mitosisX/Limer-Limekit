local widgetMap = require("data/widgets")

widgetsList = ListBox()
widgetsList:addImageItems(widgetMap)

local totalWidgets = "(" .. (function(t)
    local c = 0; for _ in pairs(t) do c = c + 1 end; return c
end)(widgetMap) .. ")"

widgetsDock = Dockable("widgets " .. totalWidgets)
widgetsDock:setMinWidth(300)
widgetsDock:setChild(widgetsList)

return widgetsDock
