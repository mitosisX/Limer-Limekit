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
        -- The designer marks its tab with the design's name and a * while
        -- it has unsaved changes; only this module knows the tab's index.
        if designerTab.setTabTitleSetter then
            designerTab.setTabTitleSetter(function(title)
                self.tabs:setTabText(3, title)
            end)
        end
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
