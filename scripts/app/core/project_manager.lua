--- Handles all creation, loading and opening of all projects

local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"

local ProjectManager = {}
ProjectManager.PROJECTS_FOLDER = Paths.limekitProjectsFolder

function ProjectManager.openProject()
    local file = app.openFileDialog(limekitWindow, "Open a project", Paths.limekitProjectsFolder, {
        ["Limekit app"] = { ".json" }
    })

    if file then
        ProjectManager.loadProject(app.normalPath(file))
    end
end

-- This takes in the app.json file path for a project and proceeds to initalize it
function ProjectManager.loadProject(projectFile)
    -- Initialize project structure

    local fileFolderLocation = app.getDirName(projectFile) -- obtain full location of file (except the file name)
    AppState.currentProjectPath = fileFolderLocation

    ProjectManager._projectData = {
        folder = fileFolderLocation,
        json = json.parse(app.readFile(projectFile))
    }

    -- Set up paths
    ProjectManager._projectData.scripts = app.joinPaths(ProjectManager._projectData.folder, 'scripts')
    ProjectManager._projectData.images = app.joinPaths(ProjectManager._projectData.folder, 'images')
    ProjectManager._projectData.misc = app.joinPaths(ProjectManager._projectData.folder, 'misc')

    -- Update UI
    homeStackedWidget:slideNext()
    ProjectManager._updateUI(AppTab)
    ProjectManager._updateDirectoryTree()

    -- Enable project toolbar
    Toolbar.switchToProjectToolbarButton:setEnabled(true)
    -- switchToProjectToolbarButton:setEnabled(AppState.projectIsRunningfalse and true or false)
end

-- After reading the app.json file, the app properties are loaded into corresponding fileds
function ProjectManager._updateUI(appTabInstance)
    local project = ProjectManager._projectData.json.project

    -- Get references to the widgets through the AppTab API
    local propertyFields = appTabInstance.getPropertyFields()
    local appNameLabel = appTabInstance.getAppNameLabel()
    local appIcon = appTabInstance.getAppIcon()

    -- Update form fields
    appNameLabel:setText(string.format('App: <strong>%s</strong>', project.name))

    -- Update all property fields
    for key, widget in pairs(propertyFields) do
        if project[key] then
            widget:setText(project[key])
        end
    end

    -- Update icon
    local iconPath = app.joinPaths(ProjectManager._projectData.images, 'app.png')
    if app.exists(iconPath) then
        appIcon:setImage(iconPath)
        appIcon:resizeImage(50, 50)
    end
end

-- The project directory is updated upon every project init
function ProjectManager._updateDirectoryTree()
    local appDirectoryTree = Dockables.appFolderDock.appProjectDirTree
    appDirectoryTree:clear()

    ProjectManager._showDirectory(appDirectoryTree, ProjectManager._projectData.folder)
end

function ProjectManager._showDirectory(treeView, path)
    local folders = {}
    local files = {}

    -- Separate folders and files
    for _, entry in ipairs(app.listFolder(path)) do
        local fullPath = app.joinPaths(path, entry)
        if app.isFolder(fullPath) then
            table.insert(folders, { entry, fullPath })
        else
            table.insert(files, { entry, fullPath })
        end
    end

    -- Add folders first
    for _, folder in ipairs(folders) do
        local item = ProjectManager.createTreeItem(folder[1], limekitWindow:getStandardIcon('SP_DirIcon'))
        treeView:addRow(item)
        ProjectManager._showDirectory(item, folder[2])
    end

    -- Then add files
    for _, file in ipairs(files) do
        local item = ProjectManager.createTreeItem(file[1], limekitWindow:getStandardIcon('SP_FileIcon'))
        treeView:addRow(item)
    end
end

function ProjectManager.createTreeItem(name, icon)
    local treeItem = TreeViewItem(name)
    treeItem:setEditable(false)

    treeItem:setIcon(icon)
    -- item.setData({
    --     'full_path': f"/project/{name}",
    --     'last_modified': "2023-11-15"
    -- }, Qt.UserRole)
    return treeItem
end

-- Loads all user projects to the screen
function ProjectManager.listAvailableProjects()
    local projects = ProjectManager._getVisibleProjectFolders()
    Dockables.userProjectsListDock.userProjectsList:addItems(projects)
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

-- ignore all hidden directory
function ProjectManager._isHiddenFolder(folderName)
    return folderName:sub(1, 1) == '.'
end

function ProjectManager.getProjectData()
    return ProjectManager._projectData
end

return ProjectManager
