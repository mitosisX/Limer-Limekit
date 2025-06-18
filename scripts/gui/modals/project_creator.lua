-- Project Creator Dialog
-- This creates a window for making new Limekit projects
-- local json = require 'json'
local Console = require "gui.views.console.console"
local Paths = require "app.core.config.paths"
local ProjectManager = require "app.core.project_manager"

local ProjectCreator = {}
ProjectCreator.SELECTED_PROJECT_ICON = nil

function ProjectCreator.show()
    --------------------------------------------
    -- 1. SETUP THE MODAL WINDOW
    --------------------------------------------
    local modal = Modal(limekitWindow, "Create New Project")
    modal:setMinSize(550, 400)

    -- Main layout splits into left and right sections
    local main_layout = HLayout()

    --------------------------------------------
    -- 2. LEFT SIDE: FEATURE LIST
    --------------------------------------------
    local features_panel = GroupBox()
    features_panel:setBackgroundColor('#307DE1') -- Blue background

    local features_layout = VLayout()
    features_layout:setContentAlignment('center')

    -- Feature 1: Quick Setup
    local feature1_title = Label("Quick setup")
    feature1_title:setBold(true)
    feature1_title:setTextColor('white')

    local feature1_desc = Label("Takes seconds to get an app running\n")
    feature1_desc:setTextColor('white')

    -- Feature 2: Cross-platform
    local feature2_title = Label("Cross-platform")
    feature2_title:setBold(true)
    feature2_title:setTextColor('white')

    local feature2_desc = Label("Same code for Windows, Linux and macOS\n")
    feature2_desc:setTextColor('white')

    -- Feature 3: Intuitive UI
    local feature3_title = Label("Intuitive API")
    feature3_title:setBold(true)
    feature3_title:setTextColor('white')

    local feature3_desc = Label("Easy to adapt to\n")
    feature3_desc:setTextColor('white')

    -- Feature 4: Cross-platform
    local feature4_title = Label("Cross-platform")
    feature4_title:setBold(true)
    feature4_title:setTextColor('white')

    local feature4_desc = Label("Same code for Windows, Linux and macOS\n")
    feature4_desc:setTextColor('white')

    -- Add all features to the layout
    features_layout:addChild(feature1_title)
    features_layout:addChild(feature1_desc)

    features_layout:addChild(feature2_title)
    features_layout:addChild(feature2_desc)

    features_layout:addChild(feature3_title)
    features_layout:addChild(feature3_desc)

    features_layout:addChild(feature4_title)
    features_layout:addChild(feature4_desc)

    features_panel:setLayout(features_layout)
    main_layout:addChild(features_panel)

    --------------------------------------------
    -- 3. RIGHT SIDE: PROJECT FORM
    --------------------------------------------
    local form_layout = VLayout()
    form_layout:setMargins(10, 0, 0, 0) -- Add some spacing

    -- Project Icon Preview
    local icon_preview = Image(images('create_project/package.png'))
    icon_preview:setImageAlignment('center')
    form_layout:addChild(icon_preview)

    -- Project Name Field
    local name_label = Label("Project Name:")
    name_label:setBold(true)
    form_layout:addChild(name_label)

    local name_input = LineEdit()
    form_layout:addChild(name_input)

    -- Project Version Field
    local version_label = Label("Version:")
    version_label:setBold(true)
    form_layout:addChild(version_label)

    local version_input = LineEdit()
    version_input:setText("1.0") -- Default version
    form_layout:addChild(version_input)

    -- Icon Selection
    local icon_label = Label("App Icon:")
    icon_label:setBold(true)
    form_layout:addChild(icon_label)

    local icon_button = Label()
    icon_button:setImage(images('create_project/icon.png'))
    icon_button:setCursor('pointinghand') -- Shows hand cursor on hover

    -- When clicked, opens file dialog to pick an image
    icon_button:setOnClick(function()
        local icon_path = app.openFileDialog(
            modal,
            "Choose App Icon",
            "",
            { ["Image Files"] = { ".png" } }
        )

        if icon_path ~= nil then
            ProjectCreator.SELECTED_PROJECT_ICON = app.normalPath(icon_path)

            icon_button:setImage(ProjectCreator.SELECTED_PROJECT_ICON)
            icon_button:resizeImage(50, 50)
        end
    end)
    form_layout:addChild(icon_button)

    -- Create Project Button
    local create_button = Button("Create Project")
    create_button:setIcon(images('homepage/create_project/done_white.png'))

    -- When clicked, validates and creates the project
    create_button:setOnClick(function()
        local project_name = name_input:getText()
        local version = version_input:getText()

        -- Basic validation
        if project_name == "" then
            app.alert(modal, "Oops!", "Please enter a project name")
            return
        end

        if version == "" then
            version = "1.0" -- Default if empty
        end

        if ProjectCreator.SELECTED_PROJECT_ICON == nil then
            question = app.questionAlertDialog(limekitWindow, "Heads up!",
                "You have not selected an icon for your app, use default icon?")

            if question then
                ProjectCreator.SELECTED_PROJECT_ICON = images('app/lime.png')
            else
                return
            end
        end

        -- Actually create the project (see next function)
        ProjectCreator.create_project_files(project_name, version, ProjectCreator.SELECTED_PROJECT_ICON)
    end)
    form_layout:addChild(create_button)

    -- Add the form to main layout
    main_layout:addLayout(form_layout)
    modal:setLayout(main_layout)

    --------------------------------------------
    -- 4. PROJECT CREATION FUNCTION
    --------------------------------------------
    function ProjectCreator.create_project_files(name, version, icon_path)
        -- Create project folder path
        local projects_folder = Paths.limekitProjectsFolder

        local project_folder = app.joinPaths(projects_folder, name)

        -- Check if project exists
        if app.exists(project_folder) then
            app.alert(modal, "Exists!", "A project with this name already exists")
            return
        end

        -- Create all needed folders
        app.createFolder(project_folder)
        app.createFolder(app.joinPaths(project_folder, "scripts"))
        app.createFolder(app.joinPaths(project_folder, "images"))
        app.createFolder(app.joinPaths(project_folder, "misc"))

        -- Create basic project files
        local main_lua = [[
            -- Welcome to your new Limekit project!
            local window = Window{
                title = "]] .. name .. [[ - Limekit",
                icon = images('app.png'),
                size = {800, 600}
            }
            window:show()
        ]]

        -- Write the main.lua file
        app.writeFile(
            app.joinPaths(project_folder, "scripts", "main.lua"),
            main_lua
        )

        -- Create basic project config
        local project_config = {
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

        local json_formatted = app.formatJSON(json.stringify(project_config))

        -- write the require (package.path) file
        app.createFile(app.joinPaths(project_folder, '.require'))

        local appJSON = app.joinPaths(project_folder, "app.json")
        -- Write the config file
        app.writeFile(
            appJSON,
            json_formatted
        )

        -- Copy the icon if one was selected
        if icon_path ~= "" then
            app.copyFile(
                icon_path,
                app.joinPaths(project_folder, "images", "app.png")
            )
        end

        -- Close the creator window
        modal:dismiss()

        -- Notify success
        app.alert(parent_window, "Success!", "Project created successfully!")

        Console.log('Created at ' .. project_folder)


        -- Open the new project
        ProjectManager.loadProject(appJSON)
    end

    -- Show the modal window
    modal:show()
end

return ProjectCreator
