-- ProjectWorkspace Module
-- Container for project-related tabs (Application, Properties, Designer)

local ui  = require("limekit.ui")

local ProjectWorkspace = {}

function ProjectWorkspace.create(appTab, propertiesTab, designerTab)
    local self = {
        tabs = ui.Tab()
    }

    local function initTabs()
        self.tabs:addTab(appTab.view, "Application")
        self.tabs:addTab(propertiesTab.view, "Properties")
        self.tabs:addTab(designerTab.view, "Designer")
    end

    initTabs()

    return {
        view = self.tabs,
        tabs = self.tabs,

        getView = function()
            return self.tabs
        end
    }
end

return ProjectWorkspace
