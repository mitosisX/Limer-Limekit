-- PropertiesTab Module
-- Manages package.path and route aliases for projects

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local res = require("limekit.res")

local PathManager = require "app.core.path_manager"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local PropertiesTab = {}

function PropertiesTab.create()
    local self = {
        view = ui.Container(),
        mainLayout = ui.VLayout(),
        contentLayout = ui.HLayout(),
        pathsList = nil,
        routesTable = nil
    }

    local function setupMainContainer()
        local groupBox = ui.GroupBox()
        groupBox:setFixedSize(500, 400)
        ui.DropShadow(groupBox)
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
        local selectedPath = ui.Dialogs.pickFolder(
            App.window,
            'Select a directory to add to package.path'
        )

        if not selectedPath or selectedPath == "" then return end

        selectedPath = fs.FileSystem.normalPath(selectedPath)

        local protectedFolders = {
            fs.FileSystem.joinPaths(AppState.activeProjectPath, 'misc'),
            fs.FileSystem.joinPaths(AppState.activeProjectPath, 'scripts'),
        }

        for _, protectedPath in ipairs(protectedFolders) do
            if selectedPath == protectedPath then
                ui.Dialogs.critical(
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
        local question = ui.Dialogs.question(App.window, "Confirm!",
            "Are you sure you want to remove the selected path?")

        if question then
            local row = self.pathsList:getCurrentRow()
            if row == 0 then return end

            self.pathsList:removeItemAt(row)
            PathManager.removePath(row)
            App.console.log("Removed from package.path")
        end
    end

    local function setupPathsSection()
        local pathsLayout = ui.VLayout()

        local header = ui.Label('package.path')
        header:setTextAlignment('center')

        self.pathsList = ui.ListBox()
        self.pathsList:addItem('default folders: misc & scripts')

        local buttonGroup = ui.HLayout()
        buttonGroup:setContentAlignment('right')

        local addPathButton = ui.Button('Add')
        addPathButton:setIcon(res.Resources.images('app/add.png'))
        addPathButton:setOnClick(onAddPath)

        local removePathButton = ui.Button('Remove')
        removePathButton:setIcon(res.Resources.images('app/cross.png'))
        removePathButton:setOnClick(onRemovePath)

        buttonGroup:addChild(addPathButton)
        buttonGroup:addChild(removePathButton)

        pathsLayout:addChild(header)
        pathsLayout:addChild(self.pathsList)
        pathsLayout:addLayout(buttonGroup)
        self.contentLayout:addLayout(pathsLayout)
    end

    local function setupRoutesSection()
        local routesLayout = ui.VLayout()
        routesLayout:setMargins(20, 0, 0, 0)

        local header = ui.Label('aliases')
        header:setTextAlignment('center')

        self.routesTable = ui.Table()

        local buttonGroup = ui.HLayout()
        buttonGroup:setContentAlignment('right')

        local addRouteButton = ui.Button('Add')
        addRouteButton:setIcon(res.Resources.images('app/add.png'))

        local removeRouteButton = ui.Button('Remove')
        removeRouteButton:setIcon(res.Resources.images('app/cross.png'))

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
