-- DebugTab Module
-- The console, and the inspector for whatever is running

local ui  = require("limekit.ui")

local DebugTab = {}

function DebugTab.create(console, inspectorView)
    local self = {
        tabWidget = ui.Tab()
    }

    self.tabWidget:addTab(console.view, 'Console')
    -- Not "Code Injection" any more: it is a widget tree first and a code
    -- box second, because a chunk on its own cannot see anything a project
    -- declared local.
    self.tabWidget:addTab(inspectorView.view, 'Inspector')

    return {
        tabWidget = self.tabWidget,

        getTabWidget = function()
            return self.tabWidget
        end
    }
end

return DebugTab
