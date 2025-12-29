-- ProjectManager Module
-- Handles all creation, loading and opening of all projects

local json = require "json"
local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local ProjectManager = {
    PROJECTS_FOLDER = Paths.limekitProjectsFolder,
    PROJECT_CONFIG = nil,
    _projectData = nil
}

function ProjectManager.openProject()
    if AppState.projectIsRunning then
        app.criticalAlertDialog(App.window, "Error!",
            "Please stop the app first before opening another project")
        return
    end

    local file = app.openFileDialog(App.window, "Open a project", Paths.limekitProjectsFolder, {
        ["Limekit app"] = { ".json" }
    })

    if file then
        ProjectManager.loadProject(app.normalPath(file))
    end
end

function ProjectManager.loadProject(projectFile)
    local fileFolderLocation = app.getDirName(projectFile)
    AppState.activeProjectPath = fileFolderLocation
    ProjectManager.PROJECT_CONFIG = json.parse(app.readFile(projectFile))

    ProjectManager._projectData = {
        folder = fileFolderLocation,
        json = ProjectManager.PROJECT_CONFIG
    }

    ProjectManager._projectData.scripts = app.joinPaths(ProjectManager._projectData.folder, 'scripts')
    ProjectManager._projectData.images = app.joinPaths(ProjectManager._projectData.folder, 'images')
    ProjectManager._projectData.misc = app.joinPaths(ProjectManager._projectData.folder, 'misc')

    App.homeStackedWidget:slideNext()
    ProjectManager._updateUI(App.appTab)
    ProjectManager._updateDirectoryTree()

    App.toolbar.switchToProjectToolbarButton:setEnabled(true)

    if App.propertiesTab and App.propertiesTab.refresh then
        App.propertiesTab.refresh()
    end
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

    local iconPath = app.joinPaths(ProjectManager._projectData.images, 'app.png')
    if app.exists(iconPath) then
        appIcon:setImage(iconPath)
        appIcon:resizeImage(50, 50)
    end
end

function ProjectManager._updateDirectoryTree()
    local appDirectoryTree = App.dockables.appFolderDock.appProjectDirTree
    appDirectoryTree:clear()

    ProjectManager._showDirectory(appDirectoryTree, ProjectManager._projectData.folder)
end

function ProjectManager._showDirectory(treeView, path)
    local folders = {}
    local files = {}

    for _, entry in ipairs(app.listFolder(path)) do
        local fullPath = app.joinPaths(path, entry)
        if app.isFolder(fullPath) then
            table.insert(folders, { entry, fullPath })
        else
            table.insert(files, { entry, fullPath })
        end
    end

    for _, folder in ipairs(folders) do
        local item = ProjectManager.createTreeItem(folder[1], App.window:getStandardIcon('SP_DirIcon'))
        treeView:addRow(item)
        ProjectManager._showDirectory(item, folder[2])
    end

    for _, file in ipairs(files) do
        local item = ProjectManager.createTreeItem(file[1], App.window:getStandardIcon('SP_FileIcon'))
        treeView:addRow(item)
    end
end

function ProjectManager.createTreeItem(name, icon)
    local treeItem = TreeViewItem(name)
    treeItem:setEditable(false)
    treeItem:setIcon(icon)
    return treeItem
end

function ProjectManager.listAvailableProjects()
    local projects = ProjectManager._getVisibleProjectFolders()
    App.dockables.userProjectsListDock.userProjectsList:addItems(projects)
end

function ProjectManager._getVisibleProjectFolders()
    local projectItems = app.listFolder(ProjectManager.PROJECTS_FOLDER)
    local projectFolders = {}

    for _, item in ipairs(projectItems) do
        if ProjectManager._isValidProjectFolder(item) then
            table.insert(projectFolders, item)
        end
    end

    return projectFolders
end

function ProjectManager._isValidProjectFolder(itemName)
    local fullPath = app.joinPaths(ProjectManager.PROJECTS_FOLDER, itemName)
    return app.isFolder(fullPath) and not ProjectManager._isHiddenFolder(itemName)
end

function ProjectManager._isHiddenFolder(folderName)
    return folderName:sub(1, 1) == '.'
end

function ProjectManager.getProjectData()
    return ProjectManager._projectData
end

return ProjectManager
