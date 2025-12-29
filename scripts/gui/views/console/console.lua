-- Console Module
-- Provides logging functionality for the application

local Console = {}

function Console.create()
    local self = {
        view = Container(),
        logConsole = TextField()
    }

    local function initUI()
        local consoleLayout = VLayout()
        self.logConsole:setReadOnly(true)
        consoleLayout:addChild(self.logConsole)
        self.view:setLayout(consoleLayout)
    end

    initUI()

    return {
        view = self.view,

        log = function(message)
            self.logConsole:appendText(">> " .. message)
        end,

        logstream = function(message)
            self.logConsole:appendText(">> <span style='color:blue;'>" .. message .. '</span>')
        end,

        error = function(message)
            self.logConsole:appendText(">> <span style='color:red;'>" .. message .. '</span>')
        end,

        clear = function()
            self.logConsole:setText("")
        end,

        getView = function()
            return self.view
        end
    }
end

return Console
