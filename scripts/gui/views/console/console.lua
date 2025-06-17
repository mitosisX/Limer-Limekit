-- Console implementation
Console = {}
local view = Container()
Console.view = view

local consoLay = VLayout()
Console.logConsole = TextField()
Console.logConsole:setReadOnly(true)

consoLay:addChild(Console.logConsole)
Console.view:setLayout(consoLay)

function Console.log(message)
    Console.logConsole:appendText(">> " .. message .. "\n")
end

function Console.clear()
    Console.logConsole:setText("")
end

function Console.error(message)
    Console.logConsole:appendText("<span style='color:red;'>" .. message .. '</span>')
end

return Console
