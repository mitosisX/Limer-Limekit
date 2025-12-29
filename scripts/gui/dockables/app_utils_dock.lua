-- AppUtilsDock Module
-- Displays available app utility functions

local AppUtilsDock = {}

function AppUtilsDock.create()
    local appUtils = require "data.app_utils"

    local utilsList = ListBox()

    for _, name in ipairs(appUtils) do
        utilsList:addImageItem(name, images("widgets/method.png"))
    end

    local dock = Dockable("app utils")
    dock:setChild(utilsList)

    return dock
end

return AppUtilsDock
