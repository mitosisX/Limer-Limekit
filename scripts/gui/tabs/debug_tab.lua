-- DebugTab Module
-- Contains console and code injection tabs

local DebugTab = {}

function DebugTab.create(console, codeInjector)
    local self = {
        tabWidget = Tab()
    }

    self.tabWidget:addTab(console.view, 'Console')
    self.tabWidget:addTab(codeInjector.view, 'Code Injection')

    return {
        tabWidget = self.tabWidget,

        getTabWidget = function()
            return self.tabWidget
        end
    }
end

return DebugTab
