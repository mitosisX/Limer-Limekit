-- AppUtilsDock Module
-- Displays available app utility functions

local ui  = require("limekit.ui")
local res = require("limekit.res")

local AppUtilsDock = {}

function AppUtilsDock.create()
    local appUtils = require "data.app_utils"

    local utilsList = ui.ListBox()

    for _, name in ipairs(appUtils) do
        utilsList:addImageItem(name, res.Resources.images("widgets/method.png"))
    end

    local dock = ui.Dockable("app utils")
    dock:setChild(utilsList)

    return dock
end

return AppUtilsDock
