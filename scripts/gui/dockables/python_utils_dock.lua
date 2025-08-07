local pythonUtils = require("data/python_utils")

pyUtilsList = ListBox()

for _, name in ipairs(pythonUtils) do
    pyUtilsList:addImageItem(name, images("py.png"))
end

pyUtilsDock = Dockable("Python utils")
pyUtilsDock:setChild(pyUtilsList)

return pyUtilsDock
