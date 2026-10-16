-- BuildDialog Module
-- Packages the open project into a program people can run without Python
-- or Limekit installed, with the build's output shown live.
--
-- Three sections -- what the app is called, its icon, where the result
-- goes and how -- then the build's progress and log. While a build runs
-- nothing above it can be changed: the build has already read it, and an
-- edit made mid-build would silently not be in the result. Stopping a
-- build, by its button or by closing the window, asks first.

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local sys = require("limekit.sys")

local json = require "json"
local AppState = require "app.core.app_state"
local App = require "app.core.app"

local BuildDialog = {}

-- State
local currentModal = nil
local buildProcess = nil
local isBuilding = false
local lastOutput = nil

-- Widgets the callbacks reach
local outputText, progressBar, statusLabel = nil, nil, nil
local buildButton, cancelButton, closeButton, openButton = nil, nil, nil, nil
local inputs = {}           -- everything locked while a build runs

local function loadAppConfig(projectPath)
    local ok, config = pcall(function()
        return json.parse(fs.FileSystem.readFile(fs.FileSystem.joinPaths(projectPath, "app.json")))
    end)
    return ok and type(config) == "table" and config.project or {}
end

-- images/app.ico, then app.png: what a build picks up on its own.
local function defaultIcon(projectPath)
    for _, name in ipairs({ "app.ico", "app.png" }) do
        local path = fs.FileSystem.joinPaths(projectPath, "images", name)
        if fs.FileSystem.exists(path) then return path end
    end
    return ""
end

local function appendOutput(text, isError)
    if outputText then
        outputText:appendText((isError and "[ERROR] " or "") .. text)
        outputText:scrollToEnd()
    end
end

local function setStatus(text, colour)
    if statusLabel then
        statusLabel:setText(text)
        statusLabel:setTextColor(colour or "#6B7280")
    end
end

local function updateBuildingState(building)
    isBuilding = building
    for _, input in ipairs(inputs) do input:setEnabled(not building) end
    buildButton:setVisible(not building)
    cancelButton:setVisible(building)
    closeButton:setEnabled(not building)
    progressBar:setVisible(building)
    if building then
        progressBar:setRange(0, 0)       -- indeterminate
        openButton:setVisible(false)
    end
end

local function handleBuildComplete(success, outputPath)
    updateBuildingState(false)
    buildProcess = nil
    appendOutput("----------------------------------------")
    if success then
        lastOutput = outputPath
        setStatus("Built.  " .. (outputPath or ""), "#16A34A")
        appendOutput("BUILD SUCCESSFUL" .. (outputPath and ("  ->  " .. outputPath) or ""))
        openButton:setVisible(outputPath ~= nil)
    else
        setStatus("The build failed -- the log below says why.", "#DC2626")
        appendOutput("BUILD FAILED", true)
    end
end

local function startBuild(projectPath, options)
    if isBuilding then return end
    outputText:clear()
    setStatus("Building -- this can take a few minutes...", "#2563EB")
    updateBuildingState(true)
    appendOutput("Project: " .. projectPath)
    appendOutput("Output:  " .. options.output_dir)
    appendOutput(options.onefile and "Packing into a single file" or "Building a folder")
    appendOutput("----------------------------------------")

    buildProcess = sys.ProjectBuilder(projectPath, options)
    buildProcess:setOnBuildOutput(function(data) appendOutput(data) end)
    buildProcess:setOnBuildStarted(function() appendOutput("Build started.") end)
    buildProcess:setOnBuildFinished(function(success, outputPath) handleBuildComplete(success, outputPath) end)
    buildProcess:setOnBuildError(function(err) appendOutput("Error: " .. tostring(err), true) end)
    buildProcess:build()
end

local function stopBuild()
    if buildProcess and isBuilding then
        buildProcess:stop()
        appendOutput("Build cancelled.", true)
        updateBuildingState(false)
        buildProcess = nil
        setStatus("Build cancelled.", "#D97706")
    end
end

--- True if the build should stop: asked, since a stopped build has to
--- start again from the beginning.
local function confirmStop()
    return ui.Dialogs.question(currentModal, "Cancel the build?",
        "Stop the build now? It will have to start from the beginning next time.") == true
end

-- A label above a field, the way every section lays its fields out.
local function field(grid, row, column, label, widget, span)
    local caption = ui.Label(label)
    caption:setTextColor("#6B7280")
    grid:addChild(caption, row, column, 1, span or 1)
    grid:addChild(widget, row + 1, column, 1, span or 1)
    return widget
end

local function section(title)
    local box = ui.GroupBox(title)
    return box
end

function BuildDialog.show()
    if not AppState.activeProjectPath then
        ui.Dialogs.alert(App.window, "No project", "Open a project first.")
        return
    end
    local project = AppState.activeProjectPath
    local config = loadAppConfig(project)
    inputs = {}
    lastOutput = nil

    currentModal = ui.Modal("Build " .. (config.name or "app"), App.window)
    currentModal:setMinSize(620, 640)

    local main = ui.VLayout()
    main:setMargins(18, 18, 18, 14)
    main:setSpacing(12)

    -- Header: the app's icon beside what this does.
    local header = ui.HLayout()
    header:setSpacing(12)
    local headerIcon = ui.Label("")
    headerIcon:setFixedSize(48, 48)
    local function showIcon(path)
        if path ~= "" and fs.FileSystem.exists(path) then
            headerIcon:setImage(path)
            headerIcon:setImageSize(48, 48)
        else
            headerIcon:setText("")
        end
    end
    header:addChild(headerIcon)
    local titles = ui.VLayout()
    titles:setSpacing(2)
    local title = ui.Label("Build " .. (config.name or "your app"))
    title:setTextSize(15)
    title:setBold(true)
    titles:addChild(title)
    local blurb = ui.Label("Packages the app into a program that runs without Python or Limekit installed.")
    blurb:setTextColor("#6B7280")
    blurb:setWordWrap(true)
    titles:addChild(blurb)
    header:addLayout(titles, 1)
    main:addLayout(header)

    -- App details
    local details = section("App details")
    local grid = ui.GridLayout()
    grid:setSpacing(6)
    local function input(text, hint)
        local edit = ui.LineEdit()
        edit:setText(text or "")
        edit:setHint(hint)
        inputs[#inputs + 1] = edit
        return edit
    end
    local nameInput = field(grid, 1, 1, "Name", input(config.name or "MyApp", "App name"))
    local versionInput = field(grid, 1, 2, "Version", input(config.version or "1.0", "1.0.0"))
    local authorInput = field(grid, 3, 1, "Author", input(config.author, "Who made it"))
    local copyrightInput = field(grid, 3, 2, "Copyright", input(config.copyright, "(c) 2026 ..."))
    local descriptionInput = field(grid, 5, 1, "Description", input(config.description, "What it does, briefly"), 2)
    details:setLayout(grid)
    main:addChild(details)

    -- Icon: chosen, not typed -- a typo here would only show up as a
    -- build with the default icon.
    local iconBox = section("Icon")
    local iconRow = ui.HLayout()
    iconRow:setSpacing(8)
    local iconPreview = ui.Label("")
    iconPreview:setFixedSize(32, 32)
    local iconPath = ui.LineEdit()
    iconPath:setReadOnly(true)
    iconPath:setHint("images/app.ico or app.png is used when none is chosen")
    local function setIcon(path)
        iconPath:setText(path)
        if path ~= "" and fs.FileSystem.exists(path) then
            iconPreview:setImage(path)
            iconPreview:setImageSize(32, 32)
        else
            iconPreview:setText("")
        end
        showIcon(path ~= "" and path or defaultIcon(project))
    end
    local iconBrowse = ui.Button("Browse...")
    iconBrowse:setOnClick(function()
        local file = ui.Dialogs.openFile(currentModal, "Choose an icon",
            fs.FileSystem.joinPaths(project, "images"), { ["Icons"] = { "ico", "png" } })
        if file and file ~= "" then setIcon(file) end
    end)
    local iconClear = ui.Button("Clear")
    iconClear:setOnClick(function() setIcon("") end)
    inputs[#inputs + 1] = iconBrowse
    inputs[#inputs + 1] = iconClear
    iconRow:addChild(iconPreview)
    iconRow:addChild(iconPath, 1)
    iconRow:addChild(iconBrowse)
    iconRow:addChild(iconClear)
    iconBox:setLayout(iconRow)
    main:addChild(iconBox)
    setIcon(defaultIcon(project))

    -- Output: where, and in what shape.
    local outBox = section("Output")
    local outLayout = ui.VLayout()
    outLayout:setSpacing(8)
    local folderRow = ui.HLayout()
    folderRow:setSpacing(8)
    local outputInput = ui.LineEdit()
    outputInput:setReadOnly(true)
    outputInput:setText(fs.FileSystem.joinPaths(project, "dist"))
    local folderBrowse = ui.Button("Browse...")
    folderBrowse:setOnClick(function()
        local folder = ui.Dialogs.pickFolder(currentModal, "Where should the build go?", outputInput:getText())
        if folder and folder ~= "" then outputInput:setText(folder) end
    end)
    inputs[#inputs + 1] = folderBrowse
    folderRow:addChild(ui.Label("Folder"))
    folderRow:addChild(outputInput, 1)
    folderRow:addChild(folderBrowse)
    outLayout:addLayout(folderRow)

    -- Off by default: a folder build starts faster and is easier to
    -- inspect; one file is for handing someone a single .exe.
    local singleFile = ui.CheckBox("Pack into a single file")
    singleFile:setChecked(false)
    singleFile:setToolTip("One portable program file. Off: a folder holding the program and "
        .. "its files, which starts faster.")
    local console = ui.CheckBox("Show a console window")
    console:setChecked(true)
    console:setToolTip("A terminal beside the app showing print() output and errors -- "
        .. "useful while testing, usually off for release.")
    inputs[#inputs + 1] = singleFile
    inputs[#inputs + 1] = console
    local checks = ui.HLayout()
    checks:setSpacing(20)
    checks:addChild(singleFile)
    checks:addChild(console)
    checks:addStretch()
    outLayout:addLayout(checks)
    outBox:setLayout(outLayout)
    main:addChild(outBox)

    -- Progress and log
    statusLabel = ui.Label("")
    statusLabel:setWordWrap(true)
    setStatus("Ready.")
    main:addChild(statusLabel)
    progressBar = ui.ProgressBar()
    progressBar:setMaxHeight(8)
    progressBar:setVisible(false)
    main:addChild(progressBar)
    outputText = ui.TextField()
    outputText:setReadOnly(true)
    outputText:setMinHeight(120)
    outputText:setFont("Consolas", 9)
    outputText:setStyleSheet("background-color: #1e1e1e; color: #dcdcdc; padding: 6px; border-radius: 4px;")
    main:addChild(outputText, 1)

    -- Buttons
    local buttons = ui.HLayout()
    buttons:setSpacing(8)
    openButton = ui.Button("Open output folder")
    openButton:setVisible(false)
    openButton:setOnClick(function()
        if lastOutput then pcall(sys.System.openPath, fs.FileSystem.getDirName(lastOutput)) end
    end)
    buttons:addChild(openButton)
    buttons:addStretch()
    cancelButton = ui.Button("Cancel build")
    cancelButton:setVisible(false)
    cancelButton:setOnClick(function()
        if confirmStop() then stopBuild() end
    end)
    buttons:addChild(cancelButton)
    closeButton = ui.Button("Close")
    closeButton:setOnClick(function() currentModal:dismiss() end)
    buttons:addChild(closeButton)
    buildButton = ui.Button("Build")
    buildButton:setOnClick(function()
        startBuild(project, {
            console = console:isChecked(),
            onefile = singleFile:isChecked(),
            output_dir = outputInput:getText(),
            name = nameInput:getText(),
            version = versionInput:getText(),
            author = authorInput:getText(),
            copyright = copyrightInput:getText(),
            description = descriptionInput:getText(),
            icon = iconPath:getText(),
        })
    end)
    buttons:addChild(buildButton)
    main:addLayout(buttons)

    -- Closing the window mid-build asks too, and stays open on "no".
    currentModal:setOnClose(function(_, event)
        if not isBuilding then return end
        if confirmStop() then stopBuild() else event.ignore() end
    end)

    currentModal:setLayout(main)
    currentModal:show()
end

return BuildDialog
