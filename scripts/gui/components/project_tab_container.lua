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

        -- The Designer tab is hidden for now. The view is still built and
        -- wired (files, project-open hook, shortcuts), so showing it again
        -- is this one line plus the title setter below it.
        local SHOW_DESIGNER = false
        if SHOW_DESIGNER then
            self.tabs:addTab(designerTab.view, "Designer")
            -- The designer marks its tab with the design's name and a *
            -- while it has unsaved changes; only this module knows the
            -- tab's index.
            if designerTab.setTabTitleSetter then
                designerTab.setTabTitleSetter(function(title)
                    self.tabs:setTabText(3, title)
                end)
            end
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
