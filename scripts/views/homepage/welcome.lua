require 'scripts.views.dialogs.create_project'

-- There are two addStretch() to push children to center and then to push the "made with love" text to the bottom
welcomeView = VLayout()
welcomeView:setContentAlignment('vcenter', 'center')

welcomeView:addStretch() -- first stretch

welcomePageGIF = GifPlayer(images(app.randomChoice({
    'homepage/sheep.gif', 'homepage/cat.gif'
})))
welcomePageGIF:setSize(120, 120)
welcomeView:addChild(welcomePageGIF)

welcomeText = Label('<strong>Limer</strong> -')
-- welcomeText:setBold(true)
welcomeText:setTextSize(32)

welcomeView:addChild(welcomeText)

welcomeContentLay = HLayout()

function makeHomepageCards(image_path, text, blue)
    local group = GroupBox()

    local lay = VLayout()

    local image = Image(image_path)
    image:setImageAlignment('center')
    image:resizeImage(80, 80)

    local label = Label(text)
    label:setTextSize(9)

    if blue then label:setTextColor('#307DE1') end

    label:setTextAlignment('center')

    lay:addChild(image)
    lay:addChild(label)
    group:setLayout(lay)

    welcomeContentLay:addChild(group)
end

homePageItems = {
    { images('homepage/modern.png'),   'Develop modern UI' },
    { images('homepage/lua_logo.png'), 'Developed in lua' },
    { images('homepage/hundred.png'),  'Free for everyone' },
    { images('homepage/battery.png'),  'Batteries Included' },
    { images('homepage/bug.png'),      'Please report bugs' },
    { images('homepage/support.png'),  '<strong>Support this project', true }
}

for _, item in ipairs(homePageItems) do
    local image_path, text, blue = item[1], item[2], item[3]
    makeHomepageCards(image_path, text, blue)
end

welcomeView:addLayout(welcomeContentLay)

commandLay = HLayout()
commandLay:setContentAlignment('right')

commandCreateProject = CommandButton('Create a project')
commandCreateProject:setResizeRule('fixed', 'fixed')
commandCreateProject:setOnClick(projectCreator)

commandLay:addChild(commandCreateProject)

welcomeView:addLayout(commandLay)

welcomeView:addStretch() -- final stretch

madeWithLoveText = Label('Built with LOVE from Malawi')
madeWithLoveText:setBold(true)
madeWithLoveText:setTextColor('#2979FF')
madeWithLoveText:setTextSize(10)
madeWithLoveText:setTextAlignment('hcenter', 'bottom')

welcomeView:addChild(madeWithLoveText)
