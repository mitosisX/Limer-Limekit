local CodeInjector = require 'gui.views.codeinjection.injection'.create()

local codeInjectionTab = Tab()
codeInjectionTab:addTab(CodeInjector.view, 'Code Injection')

return { codeInjectionTab = codeInjectionTab }
