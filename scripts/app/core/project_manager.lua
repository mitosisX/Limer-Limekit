-- ProjectManager Module
-- Handles all creation, loading and opening of all projects

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local res = require("limekit.res")

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

-- What a project's app.json starts as: the same shape the New Project
-- dialog writes. `api` only for a project known to be written for 2.0 --
-- a repaired one is left without it, so the engine is chosen from the
-- code, as it always was for that project.
function ProjectManager.defaultConfig(name, api)
    return {
        api = api,
        project = { name = name, author = "", description = "", copyright = "", version = "1.0", email = "" },
        files = { aliases = {} },
    }
end

--- The project's app.json as a table, or nil and what is wrong with it.
function ProjectManager.readConfig(projectFile)
    if not fs.FileSystem.exists(projectFile) then return nil, "missing" end
    local ok, config = pcall(function() return json.parse(fs.FileSystem.readFile(projectFile)) end)
    -- The parser's error starts with its own file and line; only what is
    -- wrong with the JSON means anything to the person reading it.
    if not ok then return nil, "unreadable: " .. (tostring(config):gsub("^.-:%d+: ", "")) end
    if type(config) ~= "table" or type(config.project) ~= "table" then
        return nil, "unreadable: it has no \"project\" section"
    end
    return config
end

-- A project whose app.json is missing or broken is not opened as it is --
-- everything after this point reads it. Say what is wrong and offer to
-- write a fresh one; a broken file is kept beside it as app.json.bak.
local function repairConfig(projectFile, why)
    local folder = fs.FileSystem.getDirName(projectFile)
    local name = fs.FileSystem.getFileName(folder)
    local missing = why == "missing"
    local message = missing
        and ("'" .. name .. "' has no app.json, which every Limekit project needs: it holds the "
            .. "app's name, version and settings.\n\nCreate one now?")
        or ("The app.json in '" .. name .. "' cannot be read (" .. why:gsub("^unreadable: ", "") .. ").\n\n"
            .. "Replace it with a fresh one? The current file is kept as app.json.bak.")
    if ui.Dialogs.question(App.window, missing and "No app.json" or "Broken app.json", message) ~= true then
        return nil
    end
    if not missing then
        pcall(fs.FileSystem.copyFile, projectFile, projectFile .. ".bak")
    end
    local config = ProjectManager.defaultConfig(name)
    local written = pcall(fs.FileSystem.writeFile, projectFile,
        fs.FileSystem.formatJSON(json.stringify(config)))
    if not written then
        ui.Dialogs.critical(App.window, "Could not write app.json",
            "Limer could not write " .. projectFile .. ". Check the folder is writable.")
        return nil
    end
    return config
end

function ProjectManager.loadProject(projectFile)
    local config, why = ProjectManager.readConfig(projectFile)
    if not config then
        config = repairConfig(projectFile, why)
        if not config then return false end
    end

    local fileFolderLocation = fs.FileSystem.getDirName(projectFile)
    AppState.activeProjectPath = fileFolderLocation
    ProjectManager.PROJECT_CONFIG = config

    ProjectManager._projectData = {
        folder = fileFolderLocation,
        json = ProjectManager.PROJECT_CONFIG
    }

    ProjectManager._projectData.scripts = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'scripts')
    ProjectManager._projectData.images = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'images')
    ProjectManager._projectData.misc = fs.FileSystem.joinPaths(ProjectManager._projectData.folder, 'misc')

    -- Through Navigation, not the stack directly, so the toolbar button
    -- knows it is now offering the way back rather than the way in.
    Navigation.returnToMyProject()
    ProjectManager._updateUI(App.appTab)
    ProjectManager._updateDirectoryTree()

    -- From here the tree follows the folder rather than a snapshot of it.
    local ProjectWatcher = require "app.core.project_watcher"
    local Images = require "app.core.images"
    -- The images module follows the folder too: an image dropped in from
    -- Explorer or Finder is in images.lua a moment later.
    ProjectWatcher.start(fileFolderLocation, function()
        ProjectManager.refreshDirectoryTree()
        Images.refresh(fileFolderLocation)
    end)
    Images.refresh(fileFolderLocation)

    App.toolbar.enableProjectActions()

    if App.propertiesTab and App.propertiesTab.refresh then
        App.propertiesTab.refresh()
    end
    if App.designer and App.designer.onProjectOpened then
        App.designer.onProjectOpened(fileFolderLocation)
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

    local iconPath = fs.FileSystem.joinPaths(ProjectManager._projectData.images, 'app.png')
    if fs.FileSystem.exists(iconPath) then
        appIcon:setImage(iconPath)
        appIcon:setImageSize(50, 50)
    end
end

function ProjectManager._updateDirectoryTree()
    local ProjectFilesDock = require "gui.dockables.project_files_dock"
    local appDirectoryTree = App.dockables.projectFilesDock.tree

    -- Captured before the rebuild and put back after: this runs on every
    -- change to the project folder now, and a tree that folds itself shut
    -- whenever a file is saved would be unusable.
    local expanded = ProjectFilesDock.captureExpanded(appDirectoryTree)

    appDirectoryTree:clear()
    ProjectManager._showDirectory(appDirectoryTree, ProjectManager._projectData.folder, true)

    ProjectFilesDock.restoreExpanded(appDirectoryTree, expanded)
end

--- Re-reads the project folder. Called by the watcher.
function ProjectManager.refreshDirectoryTree()
    if not ProjectManager._projectData then return end
    ProjectManager._updateDirectoryTree()
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
        local item = ProjectManager.createTreeItem(folder[1], ProjectManager.iconFor(folder[2]))
        attach(item)
        ProjectManager._showDirectory(item, folder[2], false)
    end

    for _, file in ipairs(files) do
        local item = ProjectManager.createTreeItem(file[1], ProjectManager.iconFor(file[2]))
        attach(item)
    end
end

--- A project's icon: app.json's "icon" (a path inside its images folder)
--- if it names one that exists, else images/app.png or app.ico -- what the
--- Application tab and a build use -- else the OS's folder icon.
function ProjectManager.projectIcon(folder)
    local images = fs.FileSystem.joinPaths(folder, "images")
    local candidates = {}
    local ok, config = pcall(function()
        return json.parse(fs.FileSystem.readFile(fs.FileSystem.joinPaths(folder, "app.json")))
    end)
    local named = ok and type(config) == "table" and type(config.project) == "table" and config.project.icon
    if type(named) == "string" and named ~= "" then
        candidates[#candidates + 1] = fs.FileSystem.joinPaths(images, named)
    end
    candidates[#candidates + 1] = fs.FileSystem.joinPaths(images, "app.png")
    candidates[#candidates + 1] = fs.FileSystem.joinPaths(images, "app.ico")
    for _, path in ipairs(candidates) do
        if fs.FileSystem.exists(path) then return path end
    end
    return fs.FileSystem.getFileIcon(folder)
end

--- The icon a file shows in the Project tree: the operating system's own
--- for its type, a thumbnail for an image, and Limer's for a .lua file --
--- which most systems have no association, and so no icon, for.
function ProjectManager.iconFor(path)
    if path:lower():match("%.lua$") then
        return res.Resources.images("files/lua.svg")
    end
    return fs.FileSystem.getFileIcon(path)
end

function ProjectManager.createTreeItem(name, icon)
    local treeItem = ui.TreeViewItem(name)
    treeItem:setEditable(false)
    treeItem:setIcon(1, icon)
    return treeItem
end

-- Cleared first: this is called again after a project is created, and
-- without the clear the new folder would land under a second copy of every
-- folder already listed.
function ProjectManager.listAvailableProjects()
    local projects = ProjectManager._getVisibleProjectFolders()

    local dockList = App.dockables.userProjectsListDock.userProjectsList
    dockList:clear()
    -- Each with its own app icon, so projects are told apart at a glance;
    -- a project without one shows the OS's folder icon.
    for _, name in ipairs(projects) do
        local folder = fs.FileSystem.joinPaths(ProjectManager.PROJECTS_FOLDER, name)
        dockList:addImageItem(name, ProjectManager.projectIcon(folder))
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
