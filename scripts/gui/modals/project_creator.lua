-- ProjectCreator Module
-- Modal dialog for creating new Limekit projects

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local res = require("limekit.res")

local json = require "json"
local Paths = require "app.core.config.paths"
local App = require "app.core.app"

local ProjectCreator = {
    selectedIcon = nil
}

function ProjectCreator.show()
    local ProjectManager = require "app.core.project_manager"

    ProjectCreator.selectedIcon = nil

    local modal = ui.Modal(App.window, "Create New Project")
    modal:setMinSize(550, 400)

    local mainLayout = ui.HLayout()

    local featuresPanel = ui.GroupBox()
    featuresPanel:setBackgroundColor('#307DE1')

    local featuresLayout = ui.VLayout()
    featuresLayout:setContentAlignment('center')

    local features = {
        { title = "Quick setup",     desc = "Takes seconds to get an app running\n" },
        { title = "Cross-platform",  desc = "Same code for Windows, Linux and macOS\n" },
        { title = "Intuitive API",   desc = "Easy to adapt to\n" },
        { title = "Batteries included", desc = "Everything you need out of the box\n" }
    }

    for _, feature in ipairs(features) do
        local title = ui.Label(feature.title)
        title:setBold(true)
        title:setTextColor('white')

        local desc = ui.Label(feature.desc)
        desc:setTextColor('white')

        featuresLayout:addChild(title)
        featuresLayout:addChild(desc)
    end

    featuresPanel:setLayout(featuresLayout)
    mainLayout:addChild(featuresPanel)

    local formLayout = ui.VLayout()
    formLayout:setMargins(10, 0, 0, 0)

    local iconPreview = ui.Image(res.Resources.images('create_project/package.png'))
    iconPreview:setImageAlignment('center')
    formLayout:addChild(iconPreview)

    local nameLabel = ui.Label("Project Name:")
    nameLabel:setBold(true)
    formLayout:addChild(nameLabel)

    local nameInput = ui.LineEdit()
    formLayout:addChild(nameInput)

    local versionLabel = ui.Label("Version:")
    versionLabel:setBold(true)
    formLayout:addChild(versionLabel)

    local versionInput = ui.LineEdit()
    versionInput:setText("1.0")
    formLayout:addChild(versionInput)

    local iconLabel = ui.Label("App Icon:")
    iconLabel:setBold(true)
    formLayout:addChild(iconLabel)

    local iconButton = ui.Label()
    iconButton:setImage(res.Resources.images('create_project/icon.png'))
    iconButton:setCursor('pointinghand')

    iconButton:setOnClick(function()
        local iconPath = ui.Dialogs.openFile(
            modal,
            "Choose App Icon",
            "",
            { ["Image Files"] = { ".png" } }
        )

        if iconPath ~= nil then
            ProjectCreator.selectedIcon = fs.FileSystem.normalPath(iconPath)
            iconButton:setImage(ProjectCreator.selectedIcon)
            iconButton:setImageSize(50, 50)
        end
    end)
    formLayout:addChild(iconButton)

    local createButton = ui.Button("Create Project")
    createButton:setIcon(res.Resources.images('homepage/create_project/done_white.png'))

    createButton:setOnClick(function()
        local projectName = nameInput:getText()
        local version = versionInput:getText()

        if projectName == "" then
            ui.Dialogs.alert(modal, "Oops!", "Please enter a project name")
            return
        end

        if version == "" then
            version = "1.0"
        end

        if ProjectCreator.selectedIcon == nil then
            local question = ui.Dialogs.question(App.window, "Heads up!",
                "You have not selected an icon for your app, use default icon?")

            if question then
                ProjectCreator.selectedIcon = res.Resources.images('app/lime.png')
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

    local projectFolder = fs.FileSystem.joinPaths(Paths.limekitProjectsFolder, name)

    if fs.FileSystem.exists(projectFolder) then
        ui.Dialogs.alert(modal, "Exists!", "A project with this name already exists")
        return
    end

    fs.FileSystem.createFolder(projectFolder)
    fs.FileSystem.createFolder(fs.FileSystem.joinPaths(projectFolder, "scripts"))
    fs.FileSystem.createFolder(fs.FileSystem.joinPaths(projectFolder, "images"))
    fs.FileSystem.createFolder(fs.FileSystem.joinPaths(projectFolder, "misc"))

    local mainLua = "-- Welcome to the new era for modern lua gui development\n\nwindow = Window{title='New app - Limekit', icon = images('app.png'), size={400, 400}}\nwindow:show()"

    fs.FileSystem.writeFile(
        fs.FileSystem.joinPaths(projectFolder, "scripts", "main.lua"),
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

    local jsonFormatted = fs.FileSystem.formatJSON(json.stringify(projectConfig))

    fs.FileSystem.createFile(fs.FileSystem.joinPaths(projectFolder, '.require'))

    local appJSON = fs.FileSystem.joinPaths(projectFolder, "app.json")
    fs.FileSystem.writeFile(appJSON, jsonFormatted)

    if iconPath ~= "" then
        fs.FileSystem.copyFile(
            iconPath,
            fs.FileSystem.joinPaths(projectFolder, "images", "app.png")
        )
    end

    modal:dismiss()

    ui.Dialogs.alert(App.window, "Success!", "Project created successfully!")
    App.console.log('Created at ' .. projectFolder)

    ProjectManager.loadProject(appJSON)
end

return ProjectCreator
