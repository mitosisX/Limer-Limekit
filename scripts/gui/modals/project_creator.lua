-- ProjectCreator Module
-- Modal dialog for creating new Limekit projects

local json = require "json"
local Paths = require "app.core.config.paths"
local App = require "app.core.app"

local ProjectCreator = {
    selectedIcon = nil
}

function ProjectCreator.show()
    local ProjectManager = require "app.core.project_manager"

    ProjectCreator.selectedIcon = nil

    local modal = Modal(App.window, "Create New Project")
    modal:setMinSize(550, 400)

    local mainLayout = HLayout()

    local featuresPanel = GroupBox()
    featuresPanel:setBackgroundColor('#307DE1')

    local featuresLayout = VLayout()
    featuresLayout:setContentAlignment('center')

    local features = {
        { title = "Quick setup",     desc = "Takes seconds to get an app running\n" },
        { title = "Cross-platform",  desc = "Same code for Windows, Linux and macOS\n" },
        { title = "Intuitive API",   desc = "Easy to adapt to\n" },
        { title = "Batteries included", desc = "Everything you need out of the box\n" }
    }

    for _, feature in ipairs(features) do
        local title = Label(feature.title)
        title:setBold(true)
        title:setTextColor('white')

        local desc = Label(feature.desc)
        desc:setTextColor('white')

        featuresLayout:addChild(title)
        featuresLayout:addChild(desc)
    end

    featuresPanel:setLayout(featuresLayout)
    mainLayout:addChild(featuresPanel)

    local formLayout = VLayout()
    formLayout:setMargins(10, 0, 0, 0)

    local iconPreview = Image(images('create_project/package.png'))
    iconPreview:setImageAlignment('center')
    formLayout:addChild(iconPreview)

    local nameLabel = Label("Project Name:")
    nameLabel:setBold(true)
    formLayout:addChild(nameLabel)

    local nameInput = LineEdit()
    formLayout:addChild(nameInput)

    local versionLabel = Label("Version:")
    versionLabel:setBold(true)
    formLayout:addChild(versionLabel)

    local versionInput = LineEdit()
    versionInput:setText("1.0")
    formLayout:addChild(versionInput)

    local iconLabel = Label("App Icon:")
    iconLabel:setBold(true)
    formLayout:addChild(iconLabel)

    local iconButton = Label()
    iconButton:setImage(images('create_project/icon.png'))
    iconButton:setCursor('pointinghand')

    iconButton:setOnClick(function()
        local iconPath = app.openFileDialog(
            modal,
            "Choose App Icon",
            "",
            { ["Image Files"] = { ".png" } }
        )

        if iconPath ~= nil then
            ProjectCreator.selectedIcon = app.normalPath(iconPath)
            iconButton:setImage(ProjectCreator.selectedIcon)
            iconButton:resizeImage(50, 50)
        end
    end)
    formLayout:addChild(iconButton)

    local createButton = Button("Create Project")
    createButton:setIcon(images('homepage/create_project/done_white.png'))

    createButton:setOnClick(function()
        local projectName = nameInput:getText()
        local version = versionInput:getText()

        if projectName == "" then
            app.alert(modal, "Oops!", "Please enter a project name")
            return
        end

        if version == "" then
            version = "1.0"
        end

        if ProjectCreator.selectedIcon == nil then
            local question = app.questionAlertDialog(App.window, "Heads up!",
                "You have not selected an icon for your app, use default icon?")

            if question then
                ProjectCreator.selectedIcon = images('app/lime.png')
            else
                return
            end
        end

        ProjectCreator._createProjectFiles(modal, projectName, version, ProjectCreator.selectedIcon)
    end)
    formLayout:addChild(createButton)

    mainLayout:addLayout(formLayout)
    modal:setLayout(mainLayout)

    modal:show()
end

function ProjectCreator._createProjectFiles(modal, name, version, iconPath)
    local ProjectManager = require "app.core.project_manager"

    local projectFolder = app.joinPaths(Paths.limekitProjectsFolder, name)

    if app.exists(projectFolder) then
        app.alert(modal, "Exists!", "A project with this name already exists")
        return
    end

    app.createFolder(projectFolder)
    app.createFolder(app.joinPaths(projectFolder, "scripts"))
    app.createFolder(app.joinPaths(projectFolder, "images"))
    app.createFolder(app.joinPaths(projectFolder, "misc"))

    local mainLua = "-- Welcome to the new era for modern lua gui development\n\nwindow = Window{title='New app - Limekit', icon = images('app.png'), size={400, 400}}\nwindow:show()"

    app.writeFile(
        app.joinPaths(projectFolder, "scripts", "main.lua"),
        mainLua
    )

    local projectConfig = {
        project = {
            name = name,
            author = "",
            description = "",
            copyright = "",
            version = version,
            email = ""
        },
        files = {
            aliases = {}
        }
    }

    local jsonFormatted = app.formatJSON(json.stringify(projectConfig))

    app.createFile(app.joinPaths(projectFolder, '.require'))

    local appJSON = app.joinPaths(projectFolder, "app.json")
    app.writeFile(appJSON, jsonFormatted)

    if iconPath ~= "" then
        app.copyFile(
            iconPath,
            app.joinPaths(projectFolder, "images", "app.png")
        )
    end

    modal:dismiss()

    app.alert(App.window, "Success!", "Project created successfully!")
    App.console.log('Created at ' .. projectFolder)

    ProjectManager.loadProject(appJSON)
end

return ProjectCreator
