-- WidgetsDock Module
-- Displays available Limekit widgets

local ui  = require("limekit.ui")

local WidgetsDock = {}

function WidgetsDock.create()
    local widgetMap = require "data.widgets"

    local function countItems(t)
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end

    local widgetsList = ui.ListBox()
    widgetsList:addImageItems(widgetMap)

    local totalWidgets = "(" .. countItems(widgetMap) .. ")"

    local dock = ui.Dockable("widgets " .. totalWidgets)
    dock:setMinWidth(300)
    dock:setChild(widgetsList)

    return dock
end

return WidgetsDock
