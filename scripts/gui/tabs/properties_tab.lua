-- PropertiesTab Module
-- Manages package.path and route aliases for projects

local PathManager = require "app.core.path_manager"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local PropertiesTab = {}

function PropertiesTab.create()
    local self = {
        view = Container(),
        mainLayout = VLayout(),
        contentLayout = HLayout(),
        pathsList = nil,
        routesTable = nil
    }

    local function setupMainContainer()
        local groupBox = GroupBox()
        groupBox:setFixedSize(500, 400)
        DropShadow(groupBox)
        groupBox:setLayout(self.contentLayout)
        self.mainLayout:addChild(groupBox)
    end

    local function refreshPathList()
        PathManager.load()
        self.pathsList:clear()
        self.pathsList:addItem('default folders: misc & scripts')

        for _, path in ipairs(PathManager.getPaths()) do
            self.pathsList:addItem(path)
        end
    end

    local function onAddPath()
        local selectedPath = app.folderPickerDialog(
            App.window,
            'Select a directory to add to package.path'
        )

        if not selectedPath or selectedPath == "" then return end

        selectedPath = app.normalPath(selectedPath)

        local protectedFolders = {
            app.joinPaths(AppState.activeProjectPath, 'misc'),
            app.joinPaths(AppState.activeProjectPath, 'scripts'),
        }

        for _, protectedPath in ipairs(protectedFolders) do
            if selectedPath == protectedPath then
                app.criticalAlertDialog(
                    App.window,
                    'Invalid Directory',
                    "The 'misc' and 'scripts' folders are automatically included."
                )
                return
            end
        end

        PathManager.addPath(selectedPath)
        self.pathsList:addItem(selectedPath)
        App.console.log("Added package.path: " .. selectedPath)
    end

    local function onRemovePath()
        local question = app.questionAlertDialog(App.window, "Confirm!",
            "Are you sure you want to remove the selected path?")

        if question then
            local row = self.pathsList:getCurrentRow()
            if row == 0 then return end

            self.pathsList:removeItem(row)
            PathManager.removePath(row)
            App.console.log("Removed from package.path")
        end
    end

    local function setupPathsSection()
        local pathsLayout = VLayout()

        local header = Label('package.path')
        header:setTextAlignment('center')

        self.pathsList = ListBox()
        self.pathsList:addItem('default folders: misc & scripts')

        local buttonGroup = HLayout()
        buttonGroup:setContentAlignment('right')

        local addPathButton = Button('Add')
        addPathButton:setIcon(images('app/add.png'))
        addPathButton:setOnClick(onAddPath)

        local removePathButton = Button('Remove')
        removePathButton:setIcon(images('app/cross.png'))
        removePathButton:setOnClick(onRemovePath)

        buttonGroup:addChild(addPathButton)
        buttonGroup:addChild(removePathButton)

        pathsLayout:addChild(header)
        pathsLayout:addChild(self.pathsList)
        pathsLayout:addLayout(buttonGroup)
        self.contentLayout:addLayout(pathsLayout)
    end

    local function setupRoutesSection()
        local routesLayout = VLayout()
        routesLayout:setMargins(20, 0, 0, 0)

        local header = Label('aliases')
        header:setTextAlignment('center')

        self.routesTable = Table()

        local buttonGroup = HLayout()
        buttonGroup:setContentAlignment('right')

        local addRouteButton = Button('Add')
        addRouteButton:setIcon(images('app/add.png'))

        local removeRouteButton = Button('Remove')
        removeRouteButton:setIcon(images('app/cross.png'))

        buttonGroup:addChild(addRouteButton)
        buttonGroup:addChild(removeRouteButton)

        routesLayout:addChild(header)
        routesLayout:addChild(self.routesTable)
        routesLayout:addLayout(buttonGroup)
        self.contentLayout:addLayout(routesLayout)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        self.mainLayout:setContentAlignment('vcenter', 'center')
        setupMainContainer()
        setupPathsSection()
        setupRoutesSection()
    end

    initComponents()

    return {
        view = self.view,

        refresh = function()
            refreshPathList()
        end,

        addPath = function(path)
            local success = PathManager.addPath(path)
            if success then refreshPathList() end
            return success
        end,

        removePath = function(index)
            local success = PathManager.removePath(index)
            if success then refreshPathList() end
            return success
        end,

        getPaths = function()
            return PathManager.getPaths()
        end
    }
end

return PropertiesTab
