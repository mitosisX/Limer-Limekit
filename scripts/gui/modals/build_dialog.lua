-- BuildDialog Module
-- Modal dialog for building projects into executables with live progress

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

-- UI elements (need to be accessible for callbacks)
local outputText = nil
local progressBar = nil
local buildButton = nil
local cancelButton = nil
local closeButton = nil
local statusLabel = nil

-- Load app.json from project
local function loadAppConfig(projectPath)
    local appJsonPath = fs.FileSystem.joinPaths(projectPath, "app.json")
    local content = fs.FileSystem.readFile(appJsonPath)
    if content then
        local config = json.parse(content)
        return config and config.project or {}
    end
    return {}
end

-- Check if icon exists
local function getIconPath(projectPath)
    local icoPath = fs.FileSystem.joinPaths(projectPath, "images", "app.ico")
    if fs.FileSystem.exists(icoPath) then
        return icoPath
    end
    local pngPath = fs.FileSystem.joinPaths(projectPath, "images", "app.png")
    if fs.FileSystem.exists(pngPath) then
        return pngPath
    end
    return ""
end

-- Append text to output
local function appendOutput(text, isError)
    if outputText then
        local prefix = isError and "[ERROR] " or ""
        outputText:appendText(prefix .. text)
        -- Scroll to bottom
        outputText:scrollToEnd()
    end
end

-- Update UI state based on building status
local function updateBuildingState(building)
    isBuilding = building

    if buildButton then
        buildButton:setEnabled(not building)
    end
    if cancelButton then
        cancelButton:setEnabled(building)
        cancelButton:setVisible(building)
    end
    if closeButton then
        closeButton:setEnabled(not building)
    end
    if progressBar then
        if building then
            progressBar:setVisible(true)
            progressBar:setRange(0, 0) -- Indeterminate
        else
            progressBar:setVisible(false)
        end
    end
end

-- Handle build completion
local function handleBuildComplete(success, outputPath)
    updateBuildingState(false)
    buildProcess = nil

    if statusLabel then
        if success then
            statusLabel:setText("Build completed successfully!")
            statusLabel:setStyleSheet("color: green; font-weight: bold;")
            appendOutput("========================================")
            appendOutput("BUILD SUCCESSFUL")
            if outputPath then
                appendOutput("Output: " .. outputPath)
            end
            appendOutput("========================================")
        else
            statusLabel:setText("Build failed - see output for details")
            statusLabel:setStyleSheet("color: red; font-weight: bold;")
            appendOutput("========================================")
            appendOutput("BUILD FAILED", true)
            appendOutput("========================================")
        end
    end
end

-- Start the build process
local function startBuild(projectPath, options)
    if isBuilding then
        appendOutput("Build already in progress...", true)
        return
    end

    -- Clear previous output
    if outputText then
        outputText:clear()
    end
    if statusLabel then
        statusLabel:setText("Building...")
        statusLabel:setStyleSheet("color: #666;")
    end

    updateBuildingState(true)
    appendOutput("Starting build process...")
    appendOutput("Project: " .. projectPath)
    appendOutput("----------------------------------------")

    buildProcess = sys.ProjectBuilder(projectPath, options)

    buildProcess:setOnBuildOutput(function(data)
        appendOutput(data)
    end)

    buildProcess:setOnBuildStarted(function()
        appendOutput("Build started - this may take a few minutes...")
    end)

    buildProcess:setOnBuildFinished(function(success, outputPath)
        handleBuildComplete(success, outputPath)
    end)

    buildProcess:setOnBuildError(function(error)
        appendOutput("Error: " .. tostring(error), true)
    end)

    buildProcess:build()
end

-- Stop the build
local function stopBuild()
    if buildProcess and isBuilding then
        buildProcess:stop()
        appendOutput("Build cancelled by user", true)
        updateBuildingState(false)
        buildProcess = nil

        if statusLabel then
            statusLabel:setText("Build cancelled")
            statusLabel:setStyleSheet("color: orange; font-weight: bold;")
        end
    end
end

function BuildDialog.show()
    if not AppState.activeProjectPath then
        ui.Dialogs.alert(App.window, "No Project", "Please load a project first")
        return
    end

    -- Load existing configuration
    local config = loadAppConfig(AppState.activeProjectPath)
    local iconPath = getIconPath(AppState.activeProjectPath)

    currentModal = ui.Modal("Build Project", App.window)
    currentModal:setMinSize(600, 650)

    local mainLayout = ui.VLayout()
    mainLayout:setMargins(20, 20, 20, 20)
    mainLayout:setSpacing(8)

    -- Header
    local headerLabel = ui.Label("Build Executable")
    headerLabel:setFont("Segoe UI", 14)
    headerLabel:setBold(true)
    mainLayout:addChild(headerLabel)

    local descLabel = ui.Label("Package your Limekit app into a standalone executable.")
    mainLayout:addChild(descLabel)

    mainLayout:addChild(ui.Separator())

    -- App Details Section (collapsible-style with smaller font)
    local detailsLabel = ui.Label("Application Details")
    detailsLabel:setBold(true)
    mainLayout:addChild(detailsLabel)

    -- Two-column layout for app details
    local detailsGrid = ui.GridLayout()
    detailsGrid:setSpacing(8)

    -- Row 0: Name and Version
    local nameLabel = ui.Label("Name:")
    local nameInput = ui.LineEdit()
    nameInput:setText(config.name or "MyApp")
    nameInput:setHint("App name")

    local versionLabel = ui.Label("Version:")
    local versionInput = ui.LineEdit()
    versionInput:setText(config.version or "1.0")
    versionInput:setHint("1.0.0")

    detailsGrid:addChild(nameLabel, 1, 1)
    detailsGrid:addChild(nameInput, 1, 2)
    detailsGrid:addChild(versionLabel, 1, 3)
    detailsGrid:addChild(versionInput, 1, 4)

    -- Row 1: Author and Copyright
    local authorLabel = ui.Label("Author:")
    local authorInput = ui.LineEdit()
    authorInput:setText(config.author or "")
    authorInput:setHint("Developer")

    local copyrightLabel = ui.Label("Copyright:")
    local copyrightInput = ui.LineEdit()
    copyrightInput:setText(config.copyright or "")
    copyrightInput:setHint("Copyright")

    detailsGrid:addChild(authorLabel, 2, 1)
    detailsGrid:addChild(authorInput, 2, 2)
    detailsGrid:addChild(copyrightLabel, 2, 3)
    detailsGrid:addChild(copyrightInput, 2, 4)

    -- Row 2: Description (full width)
    local descriptionLabel = ui.Label("Description:")
    local descriptionInput = ui.LineEdit()
    descriptionInput:setText(config.description or "")
    descriptionInput:setHint("Brief description")

    detailsGrid:addChild(descriptionLabel, 3, 1)
    detailsGrid:addChild(descriptionInput, 3, 2, 1, 3) -- span 3 columns

    -- Row 3: Icon with preview
    local iconLabel = ui.Label("Icon:")
    local iconInput = ui.LineEdit()
    iconInput:setText(iconPath)
    iconInput:setHint("Path to .ico or .png")

    -- Icon preview
    local iconPreview = ui.Label("")
    iconPreview:setFixedSize(32, 32)
    iconPreview:setStyleSheet("border: 1px solid #ccc; background: #f5f5f5;")

    -- Function to update icon preview
    local function updateIconPreview(path)
        if path and path ~= "" and fs.FileSystem.exists(path) then
            iconPreview:setImage(path)
            iconPreview:setImageSize(32, 32)
        end
    end

    -- Set initial preview
    updateIconPreview(iconPath)

    local iconBrowseBtn = ui.Button("...")
    iconBrowseBtn:setFixedSize(30, 26)
    iconBrowseBtn:setOnClick(function()
        local file = ui.Dialogs.openFile(currentModal, "Select Icon", "",
            { Images = { "ico", "png" } })
        if file and file ~= "" then
            iconInput:setText(file)
            updateIconPreview(file)
        end
    end)

    detailsGrid:addChild(iconLabel, 4, 1)
    detailsGrid:addChild(iconPreview, 4, 2)
    detailsGrid:addChild(iconInput, 4, 3)
    detailsGrid:addChild(iconBrowseBtn, 4, 4)

    mainLayout:addLayout(detailsGrid)

    mainLayout:addChild(ui.Separator())

    -- Build Options Section
    local optionsLabel = ui.Label("Build Options")
    optionsLabel:setBold(true)
    mainLayout:addChild(optionsLabel)

    local optionsLayout = ui.HLayout()
    optionsLayout:setSpacing(16)

    -- Console mode checkbox - DEFAULT TO TRUE
    local consoleCheck = ui.CheckBox("Show console window")
    consoleCheck:setChecked(true)
    optionsLayout:addChild(consoleCheck)

    -- Output directory
    local outputDirLayout = ui.HLayout()
    outputDirLayout:setSpacing(8)
    local outputLabel = ui.Label("Output:")
    outputDirLayout:addChild(outputLabel)
    local outputInput = ui.LineEdit()
    local defaultOutput = fs.FileSystem.joinPaths(AppState.activeProjectPath, "dist")
    outputInput:setText(defaultOutput)
    outputDirLayout:addChild(outputInput)
    local browseDirBtn = ui.Button("...")
    browseDirBtn:setFixedSize(30, 26)
    browseDirBtn:setOnClick(function()
        local folder = ui.Dialogs.pickFolder(currentModal, "Select Output Directory", "")
        if folder and folder ~= "" then
            outputInput:setText(folder)
        end
    end)
    outputDirLayout:addChild(browseDirBtn)
    optionsLayout:addLayout(outputDirLayout)

    mainLayout:addLayout(optionsLayout)

    mainLayout:addChild(ui.Separator())

    -- Build Output Section
    local outputLabel2 = ui.Label("Build Output")
    outputLabel2:setBold(true)
    mainLayout:addChild(outputLabel2)

    -- Progress bar (hidden initially)
    progressBar = ui.ProgressBar()
    progressBar:setVisible(false)
    progressBar:setMinHeight(20)
    mainLayout:addChild(progressBar)

    -- Status label
    statusLabel = ui.Label("Ready to build")
    statusLabel:setStyleSheet("color: #666;")
    mainLayout:addChild(statusLabel)

    -- Output text area
    outputText = ui.TextField()
    outputText:setReadOnly(true)
    outputText:setMinHeight(150)
    outputText:setFont("Consolas", 9)
    outputText:setStyleSheet("background-color: #1e1e1e; color: #dcdcdc; padding: 8px;")
    mainLayout:addChild(outputText)

    -- Buttons row
    local buttonLayout = ui.HLayout()
    buttonLayout:setSpacing(8)
    buttonLayout:setContentAlignment('right')

    -- Cancel build button (hidden initially)
    cancelButton = ui.Button("Cancel Build")
    cancelButton:setVisible(false)
    cancelButton:setOnClick(function()
        stopBuild()
    end)
    buttonLayout:addChild(cancelButton)

    -- Close button
    closeButton = ui.Button("Close")
    closeButton:setOnClick(function()
        if isBuilding then
            local confirm = ui.Dialogs.question(
                currentModal,
                "Build in Progress",
                "A build is in progress. Cancel it and close?",
                {"yes", "no"}
            )
            if confirm then
                stopBuild()
                currentModal:dismiss()
            end
        else
            currentModal:dismiss()
        end
    end)
    buttonLayout:addChild(closeButton)

    -- Build button
    buildButton = ui.Button("Build")
    buildButton:setOnClick(function()
        local options = {
            console = consoleCheck:isChecked(),
            output_dir = outputInput:getText(),
            name = nameInput:getText(),
            version = versionInput:getText(),
            author = authorInput:getText(),
            copyright = copyrightInput:getText(),
            description = descriptionInput:getText(),
            icon = iconInput:getText()
        }

        startBuild(AppState.activeProjectPath, options)
    end)
    buttonLayout:addChild(buildButton)

    mainLayout:addLayout(buttonLayout)

    -- Handle modal close
    currentModal:setOnClose(function(modal, event)
        if isBuilding then
            stopBuild()
        end
    end)

    currentModal:setLayout(mainLayout)
    currentModal:show()
end

return BuildDialog
