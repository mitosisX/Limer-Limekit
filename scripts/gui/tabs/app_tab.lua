local AppTab = {}
-- local json = require 'json'

function AppTab.create()
    local self = {
        mainLayout = VLayout(),
        contentLayout = VLayout(),
        propertyFields = {}
    }

    -- Initialize UI components
    function self:_initComponents()
        self.mainLayout:setContentAlignment('vcenter', 'center')
        self:_createAppInfoSection()
        self:_createPropertiesSection()
        self:_createActionButtons()
    end

    -- App Info Section (Top part with icon and run button)
    function self:_createAppInfoSection()
        self.appInfoGroup = GroupBox()
        DropShadow(self.appInfoGroup)
        self.appInfoGroup:setMinWidth(500)
        self.appInfoGroup:setMaxWidth(500)

        -- App details section
        self.detailsGroup = GroupBox()
        self.detailsLayout = HLayout()

        -- App icon
        self.appIcon = Image(images('app/image.png'))
        self.appIcon:setResizeRule('fixed', 'fixed')
        self.appIcon:resizeImage(50, 50)

        -- Right side details
        self.detailsRightLayout = VLayout()
        self.detailsRightLayout:setContentAlignment('bottom')

        self.appNameLabel = Label("App:")
        self.osLabel = Label(string.format('Your OS: <strong>%s</strong>', app.getOSName()))

        -- Run button and progress bar
        self.runButton = Button('Run')
        self.runButton:setResizeRule('fixed', 'fixed')
        self.runButton:setIcon(images('app/run.png'))

        self.runProgress = ProgressBar()
        self.runProgress:setRange(0, 0)
        self.runProgress:setMaxHeight(5)
        self.runProgress:setResizeRule('maximum', 'maximum')
        self.runProgress:setVisibility(false)

        -- Assemble right layout
        self.detailsRightLayout:addChild(self.appNameLabel)
        self.detailsRightLayout:addChild(self.osLabel)
        self.detailsRightLayout:addChild(self.runButton)
        self.detailsRightLayout:addChild(self.runProgress)

        -- Assemble details section
        self.detailsLayout:addChild(self.appIcon)
        self.detailsLayout:addLayout(self.detailsRightLayout)
        self.detailsGroup:setLayout(self.detailsLayout)

        -- Add to main content
        self.contentLayout:addChild(self.detailsGroup)
        self.appInfoGroup:setLayout(self.contentLayout)
        self.mainLayout:addChild(self.appInfoGroup)
    end

    -- Properties Section (Editable fields)
    function self:_createPropertiesSection()
        self.propertiesGrid = GridLayout()
        self.propertiesGrid:setMargins(0, 40, 0, 0)

        -- Define all property fields to match original 6-column, 2-row layout
        local fieldDefinitions = {
            -- Row 0
            { label = "App name",    widget = LineEdit(), key = "name",        row = 0, col = 0 },
            { label = "Version",     widget = LineEdit(), key = "version",     row = 0, col = 2 },
            { label = "Description", widget = LineEdit(), key = "description", row = 0, col = 4 },
            -- Row 1
            { label = "Author",      widget = LineEdit(), key = "author",      row = 1, col = 0 },
            { label = "Copyright",   widget = LineEdit(), key = "copyright",   row = 1, col = 2 },
            { label = "Email",       widget = LineEdit(), key = "email",       row = 1, col = 4 }
        }

        -- Create and store fields
        for _, def in ipairs(fieldDefinitions) do
            self.propertiesGrid:addChild(Label(def.label), def.col, def.row)
            self.propertiesGrid:addChild(def.widget, def.col + 1, def.row)
            self.propertyFields[def.key] = def.widget
        end

        self.contentLayout:addLayout(self.propertiesGrid)
    end

    -- Action Buttons (Save/Revert)
    function self:_createActionButtons()
        self.buttonLayout = HLayout()
        self.buttonLayout:addStretch()

        self.saveButton = Button('Save')
        self.saveButton:setIcon(images('editor/normal.png'))
        self.saveButton:setOnClick(function()
            self:_onSaveClicked()
        end)

        self.revertButton = Button('Revert')
        self.revertButton:setIcon(images('homepage/create_project/cancel.png'))

        self.buttonLayout:addChild(self.saveButton)
        self.buttonLayout:addChild(self.revertButton)

        self.contentLayout:addLayout(self.buttonLayout)
    end

    -- Save button handler
    function self:_onSaveClicked()
        local confirm = app.questionAlertDialog(limekitWindow, 'Confirm',
            'Are you sure you want to save the modifications?')

        if confirm then
            -- Get all current field values
            local updatedProject = {
                name = self.propertyFields.name:getText(),
                version = self.propertyFields.version:getText(),
                description = self.propertyFields.description:getText(),
                author = self.propertyFields.author:getText(),
                copyright = self.propertyFields.copyright:getText(),
                email = self.propertyFields.email:getText()
            }

            -- Save to file
            local success, err = pcall(function()
                -- Pretty-print JSON
                local formatedJSON = app.formatJSON(json.stringify(updatedProject))
                app.writeFile(
                    app.joinPaths(userProjectFolder, 'app.json'), formatedJSON
                )
            end)

            if success then
                -- Update UI to reflect saved state
                local newName = updatedProject.name
                self.appNameLabel:setText(string.format('App: <strong>%s</strong>', newName))

                -- Optional: Show success message
                app.alert(limekitWindow, "Success", "Project saved successfully")
                Console.log("Project saved successfully")
            else
                -- Show error message if save failed
                app.alert(limekitWindow, "Error",
                    string.format("Failed to save project: %s", tostring(err)))
            end
        end
    end

    -- Update project display
    function self:_updateProjectDisplay(projectData)
        if not projectData then return end

        -- Update app info
        self.appNameLabel:setText(string.format('App: <strong>%s</strong>', projectData.project.name))

        -- Update icon if available
        local iconPath = app.joinPaths(projectData.images, 'app.png')
        if app.exists(iconPath) then
            self.appIcon:setImage(iconPath)
        end

        -- Update property fields
        for key, widget in pairs(self.propertyFields) do
            if projectData.project[key] then
                widget:setText(projectData.project[key])
            end
        end
    end

    -- Initialize and return public API
    self:_initComponents()

    return {
        view = self.mainLayout,
        updateProjectInfo = function(projectData)
            self:_updateProjectDisplay(projectData)
        end,
        setRunHandler = function(handler)
            self.runButton:setOnClick(handler)
        end,

        getPropertyFields = function() return self.propertyFields end,
        getAppNameLabel = function() return self.appNameLabel end,
        getAppIcon = function() return self.appIcon end
    }
end

return AppTab
