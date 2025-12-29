-- PythonUtilsDock Module
-- Displays available Python utility functions

local PythonUtilsDock = {}

function PythonUtilsDock.create()
    local pythonUtils = require "data.python_utils"

    local utilsList = ListBox()

    for _, name in ipairs(pythonUtils) do
        utilsList:addImageItem(name, images("py.png"))
    end

    local dock = Dockable("Python utils")
    dock:setChild(utilsList)

    return dock
end

return PythonUtilsDock
