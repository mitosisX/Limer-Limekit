local ConsoleTab = require "gui.views.console.console"
local tabWidget  = Tab()

tabWidget:addTab(ConsoleTab.view, 'Console')
tabWidget:addTab(CodeInjectorTab.view, 'Code Injection')

return { tabWidget = tabWidget }
