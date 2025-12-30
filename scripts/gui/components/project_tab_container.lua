-- ProjectWorkspace Module
-- Container for project-related tabs (Application, Properties, Inspector)

local ProjectWorkspace = {}

function ProjectWorkspace.create(appTab, propertiesTab, inspectorTab)
    local self = {
        tabs = Tab(),
        inspectorTab = inspectorTab
    }

    local function initTabs()
        self.tabs:addTab(appTab.view, "Application")
        self.tabs:addTab(propertiesTab.view, "Properties")
        if inspectorTab then
            self.tabs:addTab(inspectorTab.view, "Inspector")
        end
    end

    initTabs()

    return {
        view = self.tabs,
        tabs = self.tabs,
        inspectorTab = inspectorTab,

        getView = function()
            return self.tabs
        end,

        getInspectorTab = function()
            return self.inspectorTab
        end
    }
end

return ProjectWorkspace
