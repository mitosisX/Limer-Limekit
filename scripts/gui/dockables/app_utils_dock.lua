local appUtils = require("data/app_utils")

appUtilsList = ListBox()

for _, name in ipairs(appUtils) do
    appUtilsList:addImageItem(name, images("widgets/method.png"))
end

appUtilsDock = Dockable("app utils")
appUtilsDock:setChild(appUtilsList)

return appUtilsDock
