-- scripts/gui/tabs/paths_tab.lua
local PropertiesTab = {
}

local PathManager = require "app.core.path_manager"
-- local AppState = require "app.core.app_state"

function PropertiesTab.create()
    local self = {
        view = Container(),
        mainLayout = VLayout(),
        contentLayout = HLayout(),
    }

    -- Initialize UI components
    function self:_initUI()
        self.view:setLayout(self.mainLayout)
        self.mainLayout:setContentAlignment('vcenter', 'center')
        self:_setupMainContainer()
        self:_setupPathsSection()
        self:_setupRoutesSection()
    end

    function self:_setupMainContainer()
        local groupBox = GroupBox()
        groupBox:setFixedSize(500, 400)
        DropShadow(groupBox)
        groupBox:setLayout(self.contentLayout)
        self.mainLayout:addChild(groupBox)
    end

    function self:_setupPathsSection()
        local pathsLay = VLayout()

        -- Header
        local header = Label('package.path')
        header:setTextAlignment('center')

        -- Path List
        self.pathsList = ListBox()
        self.pathsList:addItem('default folders: misc & scripts')
        -- self:_refreshPathList()

        -- Buttons
        local buttonGroup = HLayout()
        buttonGroup:setContentAlignment('right')

        self.addPathButton = Button('Add')
        self.addPathButton:setIcon(images('app/add.png'))
        -- self.addPathButton:setFixedSize()
        self.addPathButton:setOnClick(function() self:_onAddPath() end)

        self.removePathButton = Button('Remove')
        self.removePathButton:setIcon(images('app/cross.png'))
        -- self.removePathButton:setFixedSize()
        self.removePathButton:setOnClick(function() self:_onRemovePath() end)

        buttonGroup:addChild(self.addPathButton)
        buttonGroup:addChild(self.removePathButton)

        -- Assembly
        pathsLay:addChild(header)
        pathsLay:addChild(self.pathsList)
        pathsLay:addLayout(buttonGroup)
        self.contentLayout:addLayout(pathsLay)
    end

    function self:_setupRoutesSection()
        local routesLay = VLayout()
        routesLay:setMargins(20, 0, 0, 0)

        -- Header
        local header = Label('aliases')
        header:setTextAlignment('center')

        -- Routes Table
        self.routesTable = Table()
        -- self.routesTable:setColumnCount(2)
        -- self.routesTable:setHorizontalHeaderLabels({ "Route", "Path" })

        -- Buttons
        local buttonGroup = HLayout()
        buttonGroup:setContentAlignment('right')

        self.addRouteButton = Button('Add')
        self.addRouteButton:setIcon(images('app/add.png'))
        -- self.addRouteButton:setFixedSize()
        self.addRouteButton:setOnClick(function() self:_onAddRoute() end)

        self.removeRouteButton = Button('Remove')
        self.removeRouteButton:setIcon(images('app/cross.png'))
        -- self.removeRouteButton:setFixedSize()
        self.removeRouteButton:setOnClick(function() self:_onRemoveRoute() end)

        buttonGroup:addChild(self.addRouteButton)
        buttonGroup:addChild(self.removeRouteButton)

        -- Assembly
        routesLay:addChild(header)
        routesLay:addChild(self.routesTable)
        routesLay:addLayout(buttonGroup)
        self.contentLayout:addLayout(routesLay)
    end

    function self:_refreshPathList()
        PathManager:load()
        self.pathsList:clear()
        self.pathsList:addItem('default folders: misc & scripts')
        -- print(PathManager:getPaths())
        -- for _, path in ipairs(PathManager:getPaths()) do
        --     self.pathsList:addItem(path)
        -- end
    end

    function self:_onAddPath()
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
        local success, err = PathManager:addPath(selectedPath)
        if not success then
            app.criticalAlertDialog(
                limekitWindow,
                'Error Adding Path',
                "Failed to add path:\n" .. tostring(err)
            )
            return
        end

        -- Update UI
        self.pathsList:addItem(selectedPath)
        self.pathsList:setCurrentRow(self.pathsList:count() - 1)
        Console.log("Added package.path: " .. selectedPath)
    end

    function self:_onRemovePath()
        local row = self.pathsList:getCurrentRow()
        if row <= 0 then return end -- Skip default item

        local path = self.pathsList:getItem(row)
        local success, err = PathManager:removePath(row)

        if success then
            self.pathsList:removeItem(row)
            Console.log("Removed package.path: " .. path)
        else
            app.criticalAlertDialog(
                limekitWindow,
                'Error Removing Path',
                "Failed to remove path:\n" .. tostring(err)
            )
        end
    end

    function self:_onAddRoute()
        -- Implementation for adding routes
        -- (To be implemented based on your requirements)
    end

    function self:_onRemoveRoute()
        -- Implementation for removing routes
        -- (To be implemented based on your requirements)
    end

    -- Initialize the UI
    self:_initUI()

    return {
        view = self.view,
        refresh = function()
            self:_refreshPathList()
        end,
        -- Public methods for external access
        addPath = function(path)
            local success = PathManager:addPath(path)
            if success then self:_refreshPathList() end
            return success
        end,
        removePath = function(index)
            local success = PathManager:removePath(index)
            if success then self:_refreshPathList() end
            return success
        end,
        getPaths = function()
            return PathManager:getPaths()
        end
    }
end

return PropertiesTab
