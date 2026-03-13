-- ProjectWorkspace Module
-- Container for project-related tabs (Application, Properties)

local ProjectWorkspace = {}

function ProjectWorkspace.create(appTab, propertiesTab)
    local self = {
        tabs = Tab()
    }

    local function initTabs()
        self.tabs:addTab(appTab.view, "Application")
        self.tabs:addTab(propertiesTab.view, "Properties")
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
