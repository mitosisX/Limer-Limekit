welcomeView = VLayout()
welcomeView:setContentAlignment('vcenter', 'center')

gif = GifPlayer(images(app.randomChoice({'homepage/sheep.gif', 'homepage/cat.gif'})))
gif:setSize(120, 120)
welcomeView:addChild(gif)

welcomeText = Label('<strong>Limekit</strong> -')
welcomeText:setTextSize(25)

welcomeView:addChild(welcomeText)

welcomeContentLay = HLayout()

function makeHomepageCards(image_path, text, blue)
    local group = GroupBox()

    local lay = VLayout()

    local image = Image(image_path)
    image:setImageAlign('center')
    image:resizeImage(80, 80)

    local label = Label(text)
    if blue then
        label:setTextColor('#307DE1')
    end
    label:setTextAlign('center')

    lay:addChild(image)
    lay:addChild(label)
    group:setLayout(lay)

    welcomeContentLay:addChild(group)
end

-- welcomeView:addChild(GifPlayer(images('homepage/mo.GIF')))

makeHomepageCards(images('homepage/modern.png'), 'Develop modern UI')
makeHomepageCards(images('homepage/hundred.png'), 'Free for all users')
makeHomepageCards(images('homepage/battery.png'), 'Batteries Included')
makeHomepageCards(images('homepage/bug.png'), 'Please report bugs')
makeHomepageCards(images('homepage/support.png'), '<strong>Support this project', true)

welcomeView:addLayout(welcomeContentLay)

commandLay = HLayout()
commandLay:setContentAlignment('right')

commandCreateProject = CommandButton('Create a project')
commandCreateProject:setResizeRule('fixed', 'fixed')
commandCreateProject:setOnClick(projectCreator)

commandLay:addChild(commandCreateProject)

welcomeView:addLayout(commandLay)
