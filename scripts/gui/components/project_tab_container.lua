-- ProjectWorkspace Module
-- Container for project-related tabs (Application, Properties). The
-- designer is a window of its own -- see gui/views/designer/view.lua.

local ui  = require("limekit.ui")

local ProjectWorkspace = {}

function ProjectWorkspace.create(appTab, propertiesTab)
    local self = {
        tabs = ui.Tab()
    }

    -- Each page scrolls when the window is smaller than it, rather than
    -- being cropped -- or, worse, holding the window at its own size.
    local function scrolling(view)
        local scroller = ui.Scroller()
        scroller:setChild(view)
        scroller:setResizable(true)
        return scroller
    end

    local function initTabs()
        self.tabs:addTab(scrolling(appTab.view), "Application")
        self.tabs:addTab(scrolling(propertiesTab.view), "Properties")
        -- Images are managed in the designer, where they are used; see
        -- gui/views/designer/view.lua.
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
