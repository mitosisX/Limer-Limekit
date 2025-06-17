local Console = require 'gui.views.console.console'

local consoleTab = Tab()
consoleTab:addTab(Console.view, 'Console Log')

return { consoleTab = consoleTab }
