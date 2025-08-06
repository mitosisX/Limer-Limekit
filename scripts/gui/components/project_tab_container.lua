local ProjectWorkspace = {}

-- Module-level imports
local PropertiesTab    = require "gui.tabs.properties_tab";
PropertiesTab.create()

function ProjectWorkspace.create()
    local self = {
        _tabs = Tab()
    }

    -- Private initialization method
    function self:_initTabs()
        self._tabs:addTab(AppTab.view, "Application")
        self._tabs:addTab(PropertiesTab.view, "Properties")
    end

    -- Public method to access tab widget
    function self:getView()
        return self._tabs
    end

    -- Public method to get tab instance
    function self:getTab(tabName)
        return self._registeredTabs[tabName]
    end

    -- Initialize
    self:_initTabs()

    return {
        view = self:getView(),
        tabs = self._tabs
    }
end

return ProjectWorkspace
