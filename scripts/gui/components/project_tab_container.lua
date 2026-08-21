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

        -- The Designer is built but not shown. What it does today is edit a
        -- tree through buttons and render the result beside it, which is not
        -- what anyone means by a designer: there is no dragging onto the
        -- canvas, nothing can be moved or resized by hand, and there is no
        -- preview of the code it would write. Showing it invites the
        -- comparison with Qt Designer that it loses.
        --
        -- Kept rather than deleted because the parts underneath it are
        -- sound -- ui.DesignSurface, sys.Introspect, and one-way generation
        -- that produces a file that runs. Add the tab back when the canvas
        -- earns it.
        -- self.tabs:addTab(designerTab.view, "Designer")
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
