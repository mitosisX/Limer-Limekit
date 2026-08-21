-- ProjectManager Module
-- Handles all creation, loading and opening of all projects

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")

local json = require "json"
local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"
local App = require "app.core.app"
local Navigation = require "gui.navigation"

local ProjectManager = {
    PROJECTS_FOLDER = Paths.limekitProjectsFolder,
    PROJECT_CONFIG = nil,
    _projectData = nil
}

function ProjectManager.openProject()
    if AppState.projectIsRunning then
        ui.Dialogs.critical(App.window, "Error!",
            "Please stop the app first before opening another project")
        return
    end

    local file = ui.Dialogs.openFile(App.window, "Open a project", Paths.limekitProjectsFolder, {
        ["Limekit app"] = { ".json" }
    })

    if file then
        ProjectManager.loadProject(fs.FileSystem.normalPath(file))
    end
end

function ProjectManager.loadProject(projectFile)
    local fileFolderLocation = fs.FileSystem.getDirName(projectFile)
    AppState.activeProjectPath = fileFolderLocation
    ProjectManager.PROJECT_CONFIG = json.parse(fs.FileSystem.readFile(projectFile))

    ProjectManager._projectData = {
        folder = fileFolderLocation,
        json = ProjectManager.PROJECT_CONFIG
    }

    ProjectManager._projectData.scripts = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'scripts')
    ProjectManager._projectData.images = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'images')
    ProjectManager._projectData.misc = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'misc')

    Navigation.showWorkspace()
    ProjectManager._updateUI(App.appTab)
    ProjectManager._updateDirectoryTree()

    App.toolbar.enableProjectActions()

    if App.propertiesTab and App.propertiesTab.refresh then
        App.propertiesTab.refresh()
    end
end

--- Closes the open project and returns to the empty state.
--
-- This is what the "Home Page" button used to be, expressed as the action it
-- actually was. Refusing while the project runs matches openProject: a
-- running child process outlives the page that started it, and orphaning it
-- behind a splash screen leaves no way to stop it.
function ProjectManager.closeProject()
    if AppState.projectIsRunning then
        ui.Dialogs.critical(App.window, "Error!",
            "Please stop the app first before closing the project")
        return
    end

    AppState.activeProjectPath = nil
    ProjectManager.PROJECT_CONFIG = nil
    ProjectManager._projectData = nil

    App.dockables.projectFilesDock.tree:clear()
    App.toolbar.disableProjectActions()
    -- Re-read the folder on the way out: a project may have been created
    -- since the last time the empty state was on screen.
    ProjectManager.listAvailableProjects()
    Navigation.showHome()
end

function ProjectManager._updateUI(appTabInstance)
    local project = ProjectManager._projectData.json.project

    local propertyFields = appTabInstance.getPropertyFields()
    local appNameLabel = appTabInstance.getAppNameLabel()
    local appIcon = appTabInstance.getAppIcon()

    appNameLabel:setText(string.format('App: <strong>%s</strong>', project.name))

    for key, widget in pairs(propertyFields) do
        if project[key] then
            widget:setText(project[key])
        end
    end

    local iconPath = fs.FileSystem.joinPaths(ProjectManager._projectData.images, 'app.png')
    if fs.FileSystem.exists(iconPath) then
        appIcon:setImage(iconPath)
        appIcon:setImageSize(50, 50)
    end
end

function ProjectManager._updateDirectoryTree()
    local appDirectoryTree = App.dockables.projectFilesDock.tree
    appDirectoryTree:clear()

    ProjectManager._showDirectory(appDirectoryTree, ProjectManager._projectData.folder, true)
end

-- `node` is the TreeView at the top level and a TreeViewItem below it. 1.x's
-- addRow worked on both; 2.0 distinguishes them -- addTopItem puts a row on
-- the tree, addChild nests it under an item -- so the caller says which.
function ProjectManager._showDirectory(node, path, isRoot)
    local function attach(item)
        if isRoot then
            node:addTopItem(item)
        else
            node:addChild(item)
        end
    end

    local folders = {}
    local files = {}

    for _, entry in ipairs(fs.FileSystem.listFolder(path)) do
        local fullPath = fs.FileSystem.joinPaths(path, entry)
        if fs.FileSystem.isFolder(fullPath) then
            table.insert(folders, { entry, fullPath })
        else
            table.insert(files, { entry, fullPath })
        end
    end

    for _, folder in ipairs(folders) do
        local item = ProjectManager.createTreeItem(folder[1], App.window:getStandardIcon('SP_DirIcon'))
        attach(item)
        ProjectManager._showDirectory(item, folder[2], false)
    end

    for _, file in ipairs(files) do
        local item = ProjectManager.createTreeItem(file[1], App.window:getStandardIcon('SP_FileIcon'))
        attach(item)
    end
end

function ProjectManager.createTreeItem(name, icon)
    local treeItem = ui.TreeViewItem(name)
    treeItem:setEditable(false)
    treeItem:setIcon(1, icon)
    return treeItem
end

-- Both the dock and the empty state show your projects, and they are filled
-- from here so they cannot disagree about what exists.
function ProjectManager.listAvailableProjects()
    local projects = ProjectManager._getVisibleProjectFolders()

    local dockList = App.dockables.userProjectsListDock.userProjectsList
    dockList:clear()
    dockList:addItems(projects)

    local WelcomeView = require "gui.views.homepage.welcome"
    local homeList = WelcomeView.getProjectsList()
    if homeList then
        homeList:clear()
        homeList:addItems(projects)
    end

    return projects
end

function ProjectManager._getVisibleProjectFolders()
    local projectItems = fs.FileSystem.listFolder(ProjectManager.PROJECTS_FOLDER)
    local projectFolders = {}

    for _, item in ipairs(projectItems) do
        if ProjectManager._isValidProjectFolder(item) then
            table.insert(projectFolders, item)
        end
    end

    return projectFolders
end

function ProjectManager._isValidProjectFolder(itemName)
    local fullPath = fs.FileSystem.joinPaths(ProjectManager.PROJECTS_FOLDER, itemName)
    return fs.FileSystem.isFolder(fullPath) and not ProjectManager._isHiddenFolder(itemName)
end

function ProjectManager._isHiddenFolder(folderName)
    return folderName:sub(1, 1) == '.'
end

function ProjectManager.getProjectData()
    return ProjectManager._projectData
end

return ProjectManager
