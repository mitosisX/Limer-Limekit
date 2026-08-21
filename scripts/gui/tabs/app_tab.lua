-- AppTab Module
-- Main application properties tab with project info and run controls

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local res = require("limekit.res")
local sys = require("limekit.sys")

local json = require "json"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local AppTab = {}

function AppTab.create()
    local self = {
        view = ui.Container(),
        mainLayout = ui.VLayout(),
        contentLayout = ui.VLayout(),
        propertyFields = {}
    }

    local function initRunnerUI()
        local ProjectRunner = require "app.core.project_runner"
        ProjectRunner.observe(function(isRunning)
            self.runButton:setText(isRunning and 'Stop' or 'Run')
            self.runButton:setIcon(res.Resources.images(isRunning and 'app/stop.png' or 'app/run.png'))
            self.runProgress:setVisible(isRunning)
        end)
    end

    local function createAppInfoSection()
        self.appInfoGroup = ui.GroupBox()
        ui.DropShadow(self.appInfoGroup)
        self.appInfoGroup:setMinWidth(520)

        self.detailsGroup = ui.GroupBox()
        self.detailsLayout = ui.HLayout()

        self.appIcon = ui.Image(res.Resources.images('app/image.png'))
        self.appIcon:setResizeRule('fixed', 'fixed')
        self.appIcon:setImageSize(50, 50)

        self.detailsRightLayout = ui.VLayout()
        self.detailsRightLayout:setContentAlignment('bottom')

        self.appNameLabel = ui.Label("App:")
        self.osLabel = ui.Label(string.format('Your OS: <strong>%s</strong>', sys.System.getOSName()))

        self.runButton = ui.Button('Run')
        self.runButton:setResizeRule('fixed', 'fixed')
        self.runButton:setIcon(res.Resources.images('app/run.png'))
        self.runButton:setOnClick(function()
            local ProjectRunner = require "app.core.project_runner"
            if AppState.projectIsRunning then
                ProjectRunner.stop()
            else
                ProjectRunner.run(AppState.activeProjectPath)
            end
        end)

        self.runProgress = ui.ProgressBar()
        self.runProgress:setRange(0, 0)
        self.runProgress:setMaxHeight(5)
        self.runProgress:setResizeRule('maximum', 'maximum')
        self.runProgress:setVisible(false)

        self.detailsRightLayout:addChild(self.appNameLabel)
        self.detailsRightLayout:addChild(self.osLabel)
        self.detailsRightLayout:addChild(self.runButton)
        self.detailsRightLayout:addChild(self.runProgress)

        self.detailsLayout:addChild(self.appIcon)
        self.detailsLayout:addLayout(self.detailsRightLayout)
        self.detailsGroup:setLayout(self.detailsLayout)

        self.contentLayout:addChild(self.detailsGroup)
        self.appInfoGroup:setLayout(self.contentLayout)
        self.mainLayout:addChild(self.appInfoGroup)
    end

    local function createPropertiesSection()
        self.propertiesGrid = ui.GridLayout()
        self.propertiesGrid:setMargins(0, 40, 0, 0)

        local fieldDefinitions = {
            { label = "App name",    widget = ui.LineEdit(), key = "name",        row = 1, col = 1 },
            { label = "Version",     widget = ui.LineEdit(), key = "version",     row = 1, col = 3 },
            { label = "Description", widget = ui.LineEdit(), key = "description", row = 1, col = 5 },
            { label = "Author",      widget = ui.LineEdit(), key = "author",      row = 2, col = 1 },
            { label = "Copyright",   widget = ui.LineEdit(), key = "copyright",   row = 2, col = 3 },
            { label = "Email",       widget = ui.LineEdit(), key = "email",       row = 2, col = 5 }
        }

        for _, def in ipairs(fieldDefinitions) do
            self.propertiesGrid:addChild(ui.Label(def.label), def.col, def.row)
            self.propertiesGrid:addChild(def.widget, def.col + 1, def.row)
            self.propertyFields[def.key] = def.widget
        end

        self.contentLayout:addLayout(self.propertiesGrid)
    end

    local function onSaveClicked()
        local confirm = ui.Dialogs.question(App.window, 'Confirm Save',
            'Are you sure you want to save the modifications?')

        if confirm then
            local ProjectManager = require "app.core.project_manager"
            local updatedProject = {
                name = self.propertyFields.name:getText(),
                version = self.propertyFields.version:getText(),
                description = self.propertyFields.description:getText(),
                author = self.propertyFields.author:getText(),
                copyright = self.propertyFields.copyright:getText(),
                email = self.propertyFields.email:getText()
            }

            ProjectManager.PROJECT_CONFIG.project = updatedProject

            local success, err = pcall(function()
                local formattedJSON = fs.FileSystem.formatJSON(json.stringify(ProjectManager.PROJECT_CONFIG))
                fs.FileSystem.writeFile(
                    fs.FileSystem.joinPaths(AppState.activeProjectPath, 'app.json'), formattedJSON
                )
            end)

            if success then
                self.appNameLabel:setText(string.format('App: <strong>%s</strong>', updatedProject.name))
                ui.Dialogs.alert(App.window, "Success", "Project saved successfully")
                App.console.log("Project saved successfully")
            else
                ui.Dialogs.alert(App.window, "Error",
                    string.format("Failed to save project: %s", tostring(err)))
            end
        end
    end

    local function createActionButtons()
        self.buttonLayout = ui.HLayout()
        self.buttonLayout:addStretch()

        self.saveButton = ui.Button('Save')
        self.saveButton:setIcon(res.Resources.images('editor/normal.png'))
        self.saveButton:setOnClick(onSaveClicked)

        self.revertButton = ui.Button('Revert')
        self.revertButton:setIcon(res.Resources.images('homepage/create_project/cancel.png'))
        self.revertButton:setOnClick(function()
            local confirm = ui.Dialogs.question(App.window, 'Confirm Revert',
                'Are you sure you want to revert all modifications?')

            if confirm then
                local ProjectManager = require "app.core.project_manager"
                local appConfig = fs.FileSystem.joinPaths(AppState.activeProjectPath, 'app.json')
                ProjectManager.loadProject(appConfig)
            end
        end)

        self.buttonLayout:addChild(self.saveButton)
        self.buttonLayout:addChild(self.revertButton)
        self.contentLayout:addLayout(self.buttonLayout)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        -- Top, not centre. Centring a fixed-width card inside a maximised
        -- window put a small form in the middle of a large empty page and
        -- made the whole workspace look unfinished; anchoring it to the top
        -- reads as a settings page, which is what it is.
        self.mainLayout:setContentAlignment('top', 'hcenter')
        self.mainLayout:setMargins(24, 24, 24, 24)
        createAppInfoSection()
        createPropertiesSection()
        createActionButtons()
    end

    local function updateProjectDisplay(projectData)
        if not projectData then return end

        self.appNameLabel:setText(string.format('App: <strong>%s</strong>', projectData.project.name))

        local iconPath = fs.FileSystem.joinPaths(projectData.images, 'app.png')
        if fs.FileSystem.exists(iconPath) then
            self.appIcon:setImage(iconPath)
        end

        for key, widget in pairs(self.propertyFields) do
            if projectData.project[key] then
                widget:setText(projectData.project[key])
            end
        end
    end

    initRunnerUI()
    initComponents()

    return {
        view = self.view,

        progress = {
            show = function()
                self.runProgress:setVisible(true)
            end,
            hide = function()
                self.runProgress:setVisible(false)
            end
        },

        updateProjectInfo = function(projectData)
            updateProjectDisplay(projectData)
        end,

        setRunHandler = function(handler)
            self.runButton:setOnClick(handler)
        end,

        getPropertyFields = function()
            return self.propertyFields
        end,

        getAppNameLabel = function()
            return self.appNameLabel
        end,

        getAppIcon = function()
            return self.appIcon
        end
    }
end

return AppTab
