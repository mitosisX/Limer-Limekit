local PathManager = require "app.core.path_manager"
local AppState = require "app.core.app_state"

local PropertiesTab = {
    view = Container(),
    mainLayout = VLayout(),
    contentLayout = HLayout()
}

function PropertiesTab.create()
    PropertiesTab.view:setLayout(PropertiesTab.mainLayout) -- Correctly accesses PropertiesTab.view
    PropertiesTab.mainLayout:setContentAlignment('vcenter', 'center')
    PropertiesTab:_setupMainContainer()                    -- Use : to pass PropertiesTab automatically
    PropertiesTab:_setupPathsSection()
    PropertiesTab:_setupRoutesSection()
end

function PropertiesTab._setupMainContainer()
    local groupBox = GroupBox()
    groupBox:setFixedSize(500, 400)
    DropShadow(groupBox)
    groupBox:setLayout(PropertiesTab.contentLayout)
    PropertiesTab.mainLayout:addChild(groupBox)
end

function PropertiesTab._setupPathsSection()
    local pathsLay = VLayout()

    -- Header
    local header = Label('package.path')
    header:setTextAlignment('center')

    -- Path List
    PropertiesTab.pathsList = ListBox()
    PropertiesTab.pathsList:addItem('default folders: misc & scripts')

    -- Buttons
    local buttonGroup = HLayout()
    buttonGroup:setContentAlignment('right')

    PropertiesTab.addPathButton = Button('Add')
    PropertiesTab.addPathButton:setIcon(images('app/add.png'))
    -- PropertiesTab.addPathButton:setFixedSize()
    PropertiesTab.addPathButton:setOnClick(function() PropertiesTab:_onAddPath() end)

    PropertiesTab.removePathButton = Button('Remove')
    PropertiesTab.removePathButton:setIcon(images('app/cross.png'))
    -- PropertiesTab.removePathButton:setFixedSize()
    PropertiesTab.removePathButton:setOnClick(function() PropertiesTab:_onRemovePath() end)

    buttonGroup:addChild(PropertiesTab.addPathButton)
    buttonGroup:addChild(PropertiesTab.removePathButton)

    -- Assembly
    pathsLay:addChild(header)
    pathsLay:addChild(PropertiesTab.pathsList)
    pathsLay:addLayout(buttonGroup)
    PropertiesTab.contentLayout:addLayout(pathsLay)
end

function PropertiesTab._setupRoutesSection()
    local routesLay = VLayout()
    routesLay:setMargins(20, 0, 0, 0)

    -- Header
    local header = Label('aliases')
    header:setTextAlignment('center')

    -- Routes Table
    PropertiesTab.routesTable = Table()
    -- PropertiesTab.routesTable:setColumnCount(2)
    -- PropertiesTab.routesTable:setHorizontalHeaderLabels({ "Route", "Path" })

    -- Buttons
    local buttonGroup = HLayout()
    buttonGroup:setContentAlignment('right')

    PropertiesTab.addRouteButton = Button('Add')
    PropertiesTab.addRouteButton:setIcon(images('app/add.png'))
    -- PropertiesTab.addRouteButton:setFixedSize()
    PropertiesTab.addRouteButton:setOnClick(function() PropertiesTab:_onAddRoute() end)

    PropertiesTab.removeRouteButton = Button('Remove')
    PropertiesTab.removeRouteButton:setIcon(images('app/cross.png'))
    -- PropertiesTab.removeRouteButton:setFixedSize()
    PropertiesTab.removeRouteButton:setOnClick(function() PropertiesTab:_onRemoveRoute() end)

    buttonGroup:addChild(PropertiesTab.addRouteButton)
    buttonGroup:addChild(PropertiesTab.removeRouteButton)

    -- Assembly
    routesLay:addChild(header)
    routesLay:addChild(PropertiesTab.routesTable)
    routesLay:addLayout(buttonGroup)
    PropertiesTab.contentLayout:addLayout(routesLay)
end

function PropertiesTab._refreshPathList()
    PathManager:load()
    PropertiesTab.pathsList:clear()
    PropertiesTab.pathsList:addItem('default folders: misc & scripts')

    for _, path in ipairs(PathManager:getPaths()) do
        PropertiesTab.pathsList:addItem(path)
    end
end

function PropertiesTab._onAddPath()
    local selectedPath = app.folderPickerDialog(
        limekitWindow,
        'Select a directory to add to package.path'
    )

    if not selectedPath or selectedPath == "" then return end

    selectedPath = app.normalPath(selectedPath)

    -- Validate protected folders
    local protectedFolders = {
        app.joinPaths(AppState.activeProjectPath, 'misc'),
        app.joinPaths(AppState.activeProjectPath, 'scripts'),
    }

    for _, protectedPath in ipairs(protectedFolders) do
        if selectedPath == protectedPath then
            app.criticalAlertDialog(
                limekitWindow,
                'Invalid Directory',
                "The 'misc' and 'scripts' folders are automatically included."
            )
            return
        end
    end

    -- Add path through manager
    PathManager:addPath(selectedPath)

    -- Update UI
    PropertiesTab.pathsList:addItem(selectedPath)
    -- PropertiesTab.pathsList:setCurrentRow(PropertiesTab.pathsList:count() - 1)
    Console.log("Added package.path: " .. selectedPath)
end

function PropertiesTab._onRemovePath()
    question = app.questionAlertDialog(limekitWindow, "Confirm!",
        "Are you sure you want to remove the selected path?")

    if question then
        local row = PropertiesTab.pathsList:getCurrentRow()
        if row == 0 then return end -- Skip default item

        PropertiesTab.pathsList:removeItem(row)
        PathManager:removePath(row)

        Console.log("Removed from package.path: ")
    end
end

-- return {
--     view = PropertiesTab.view,
--     refresh = function()
--         PropertiesTab:_refreshPathList()
--     end,
--     -- Public methods for external access
--     addPath = function(path)
--         local success = PathManager:addPath(path)
--         if success then PropertiesTab:_refreshPathList() end
--         return success
--     end,
--     removePath = function(index)
--         local success = PathManager:removePath(index)
--         if success then PropertiesTab:_refreshPathList() end
--         return success
--     end,
--     getPaths = function()
--         return PathManager:getPaths()
--     end
-- }


return {
    view = PropertiesTab.view,
    create = PropertiesTab.create,
    refresh = PropertiesTab._refreshPathList
}
