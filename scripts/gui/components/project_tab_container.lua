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
        -- The browser scrolls on its own and wants the full height.
        local ImagesTab = require "gui.tabs.images_tab"
        self.imagesTab = ImagesTab.create()
        self.tabs:addTab(self.imagesTab.view, "Images")
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
