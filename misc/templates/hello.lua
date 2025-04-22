limekitWindow = limekitWindow{title = '{} - Limekit', icon = images('app.png') size={{}, {}}}

mainLay = VLayout()
label = Label("")

button = Button('Click me!')
button:setOnClick(function()
	label:setText('Hello Limekit!')
end)

mainLay:addChild(label)
mainLay:addChild(button)

limekitWindow:setLayout(mainLay)
limekitWindow:show()