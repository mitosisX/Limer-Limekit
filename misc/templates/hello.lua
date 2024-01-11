window = Window{title = '{} - Limekit', icon = images('app.png') size={{}, {}}}

mainLay = VLayout()
label = Label("")

button = Button('Click me!')
button:setOnClick(function()
	label:setText('Hello Limekit!')
end)

mainLay:addChild(label)
mainLay:addChild(button)

window:setLayout(mainLay)
window:show()