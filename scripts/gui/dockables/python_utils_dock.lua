-- PythonUtilsDock Module
-- Displays available Python utility functions

local ui  = require("limekit.ui")
local res = require("limekit.res")

local PythonUtilsDock = {}

function PythonUtilsDock.create()
    local pythonUtils = require "data.python_utils"

    local utilsList = ui.ListBox()

    for _, name in ipairs(pythonUtils) do
        utilsList:addImageItem(name, res.Resources.images("py.png"))
    end

    local dock = ui.Dockable("Python utils")
    dock:setChild(utilsList)

    return dock
end

return PythonUtilsDock
