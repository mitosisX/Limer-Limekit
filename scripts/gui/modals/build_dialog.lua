-- BuildDialog Module
-- Modal dialog for building projects into executables

local AppState = require "app.core.app_state"
local App = require "app.core.app"
local BuildManager = require "app.core.build_manager"

local BuildDialog = {}

function BuildDialog.show()
    if not AppState.activeProjectPath then
        app.alert(App.window, "No Project", "Please load a project first")
        return
    end

    local modal = Modal(App.window, "Build Project")
    modal:setMinSize(450, 300)

    local mainLayout = VLayout()
    mainLayout:setMargins(20, 20, 20, 20)
    mainLayout:setSpacing(12)

    -- Header
    local headerLabel = Label("Build Executable")
    headerLabel:setFont("Segoe UI", 14)
    headerLabel:setBold(true)
    mainLayout:addChild(headerLabel)

    local descLabel = Label("Package your Limekit app into a standalone executable.")
    mainLayout:addChild(descLabel)

    -- Separator
    mainLayout:addChild(Separator())

    -- Options section
    local optionsLabel = Label("Build Options")
    optionsLabel:setBold(true)
    mainLayout:addChild(optionsLabel)

    -- Console mode checkbox
    local consoleCheck = CheckBox("Show console window")
    consoleCheck:setCheck(false)
    mainLayout:addChild(consoleCheck)

    -- Output directory
    local outputLabel = Label("Output Directory:")
    mainLayout:addChild(outputLabel)

    local outputLayout = HLayout()
    outputLayout:setSpacing(8)

    local outputInput = LineEdit()
    local defaultOutput = app.joinPaths(AppState.activeProjectPath, "dist")
    outputInput:setText(defaultOutput)
    outputLayout:addChild(outputInput)

    local browseButton = Button("Browse")
    browseButton:setOnClick(function()
        local folder = app.folderPickerDialog(modal, "Select Output Directory", "")
        if folder and folder ~= "" then
            outputInput:setText(folder)
        end
    end)
    outputLayout:addChild(browseButton)

    mainLayout:addLayout(outputLayout)

    -- Buttons row
    local buttonLayout = HLayout()
    buttonLayout:setSpacing(8)
    buttonLayout:setContentAlignment('right')

    local cancelButton = Button("Cancel")
    cancelButton:setOnClick(function()
        modal:dismiss()
    end)
    buttonLayout:addChild(cancelButton)

    local buildButton = Button("Build")
    buildButton:setOnClick(function()
        local options = {
            console = consoleCheck:getCheck(),
            output_dir = outputInput:getText()
        }

        modal:dismiss()
        BuildManager.build(AppState.activeProjectPath, options)
    end)
    buttonLayout:addChild(buildButton)

    mainLayout:addLayout(buttonLayout)

    modal:setLayout(mainLayout)
    modal:show()
end

return BuildDialog
