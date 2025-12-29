-- AppTab Module
-- Main application properties tab with project info and run controls

local json = require "json"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local AppTab = {}

function AppTab.create()
    local self = {
        view = Container(),
        mainLayout = VLayout(),
        contentLayout = VLayout(),
        propertyFields = {}
    }

    local function initRunnerUI()
        local ProjectRunner = require "app.core.project_runner"
        ProjectRunner.init({
            ui = {
                updateRunState = function()
                    local isRunning = AppState.projectIsRunning
                    self.runButton:setText(isRunning and 'Stop' or 'Run')
                    self.runButton:setIcon(images(isRunning and 'app/stop.png' or 'app/run.png'))
                    self.runProgress:setVisibility(isRunning)
                end
            }
        })
    end

    local function createAppInfoSection()
        self.appInfoGroup = GroupBox()
        DropShadow(self.appInfoGroup)
        self.appInfoGroup:setMinWidth(500)
        self.appInfoGroup:setMaxWidth(500)

        self.detailsGroup = GroupBox()
        self.detailsLayout = HLayout()

        self.appIcon = Image(images('app/image.png'))
        self.appIcon:setResizeRule('fixed', 'fixed')
        self.appIcon:resizeImage(50, 50)

        self.detailsRightLayout = VLayout()
        self.detailsRightLayout:setContentAlignment('bottom')

        self.appNameLabel = Label("App:")
        self.osLabel = Label(string.format('Your OS: <strong>%s</strong>', app.getOSName()))

        self.runButton = Button('Run')
        self.runButton:setResizeRule('fixed', 'fixed')
        self.runButton:setIcon(images('app/run.png'))
        self.runButton:setOnClick(function()
            local ProjectRunner = require "app.core.project_runner"
            if AppState.projectIsRunning then
                ProjectRunner.stop()
            else
                ProjectRunner.run(AppState.activeProjectPath)
            end
        end)

        self.runProgress = ProgressBar()
        self.runProgress:setRange(0, 0)
        self.runProgress:setMaxHeight(5)
        self.runProgress:setResizeRule('maximum', 'maximum')
        self.runProgress:setVisibility(false)

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
        self.propertiesGrid = GridLayout()
        self.propertiesGrid:setMargins(0, 40, 0, 0)

        local fieldDefinitions = {
            { label = "App name",    widget = LineEdit(), key = "name",        row = 0, col = 0 },
            { label = "Version",     widget = LineEdit(), key = "version",     row = 0, col = 2 },
            { label = "Description", widget = LineEdit(), key = "description", row = 0, col = 4 },
            { label = "Author",      widget = LineEdit(), key = "author",      row = 1, col = 0 },
            { label = "Copyright",   widget = LineEdit(), key = "copyright",   row = 1, col = 2 },
            { label = "Email",       widget = LineEdit(), key = "email",       row = 1, col = 4 }
        }

        for _, def in ipairs(fieldDefinitions) do
            self.propertiesGrid:addChild(Label(def.label), def.col, def.row)
            self.propertiesGrid:addChild(def.widget, def.col + 1, def.row)
            self.propertyFields[def.key] = def.widget
        end

        self.contentLayout:addLayout(self.propertiesGrid)
    end

    local function onSaveClicked()
        local confirm = app.questionAlertDialog(App.window, 'Confirm Save',
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
                local formattedJSON = app.formatJSON(json.stringify(ProjectManager.PROJECT_CONFIG))
                app.writeFile(
                    app.joinPaths(AppState.activeProjectPath, 'app.json'), formattedJSON
                )
            end)

            if success then
                self.appNameLabel:setText(string.format('App: <strong>%s</strong>', updatedProject.name))
                app.alert(App.window, "Success", "Project saved successfully")
                App.console.log("Project saved successfully")
            else
                app.alert(App.window, "Error",
                    string.format("Failed to save project: %s", tostring(err)))
            end
        end
    end

    local function createActionButtons()
        self.buttonLayout = HLayout()
        self.buttonLayout:addStretch()

        self.saveButton = Button('Save')
        self.saveButton:setIcon(images('editor/normal.png'))
        self.saveButton:setOnClick(onSaveClicked)

        self.revertButton = Button('Revert')
        self.revertButton:setIcon(images('homepage/create_project/cancel.png'))
        self.revertButton:setOnClick(function()
            local confirm = app.questionAlertDialog(App.window, 'Confirm Revert',
                'Are you sure you want to revert all modifications?')

            if confirm then
                local ProjectManager = require "app.core.project_manager"
                local appConfig = app.joinPaths(AppState.activeProjectPath, 'app.json')
                ProjectManager.loadProject(appConfig)
            end
        end)

        self.buttonLayout:addChild(self.saveButton)
        self.buttonLayout:addChild(self.revertButton)
        self.contentLayout:addLayout(self.buttonLayout)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        self.mainLayout:setContentAlignment('vcenter', 'center')
        createAppInfoSection()
        createPropertiesSection()
        createActionButtons()
    end

    local function updateProjectDisplay(projectData)
        if not projectData then return end

        self.appNameLabel:setText(string.format('App: <strong>%s</strong>', projectData.project.name))

        local iconPath = app.joinPaths(projectData.images, 'app.png')
        if app.exists(iconPath) then
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
                self.runProgress:setVisibility(true)
            end,
            hide = function()
                self.runProgress:setVisibility(false)
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
