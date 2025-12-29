-- WelcomeView Module
-- Creates the home/welcome screen layout

local WelcomeView = {}

function WelcomeView.create()
    local ProjectCreator = require "gui.modals.project_creator"

    local layout = VLayout()
    layout:setContentAlignment('vcenter', 'center')

    layout:addStretch()

    local gifPaths = {
        'homepage/sheep.gif',
        'homepage/cat.gif'
    }

    local welcomeGif = GifPlayer(images(gifPaths[math.random(#gifPaths)]))
    welcomeGif:setSize(120, 120)
    layout:addChild(welcomeGif)

    local title = Label('<strong>Limer</strong> -')
    title:setTextSize(32)
    layout:addChild(title)

    local features = WelcomeView._createFeatureCards()
    layout:addLayout(features)

    local commandLayout = HLayout()
    commandLayout:setContentAlignment('right')

    local createProjectButton = CommandButton('Create a project')
    createProjectButton:setResizeRule('fixed', 'fixed')
    createProjectButton:setOnClick(ProjectCreator.show)

    commandLayout:addChild(createProjectButton)
    layout:addLayout(commandLayout)

    layout:addStretch()
    layout:addChild(WelcomeView._createFooter())

    return layout
end

function WelcomeView._createFeatureCards()
    local featuresLayout = HLayout()
    local featureItems = {
        { image = 'homepage/modern.png',   text = 'Develop modern UI' },
        { image = 'homepage/lua_logo.png', text = 'Developed in lua' },
        { image = 'homepage/hundred.png',  text = 'Free for everyone' },
        { image = 'homepage/battery.png',  text = 'Batteries Included' },
        { image = 'homepage/bug.png',      text = 'Please report bugs' },
        { image = 'homepage/support.png',  text = '<strong>Support this project', highlight = true }
    }

    for _, item in ipairs(featureItems) do
        featuresLayout:addChild(WelcomeView._createFeatureCard(
            images(item.image),
            item.text,
            item.highlight
        ))
    end

    return featuresLayout
end

function WelcomeView._createFeatureCard(imagePath, text, highlight)
    local card = GroupBox()
    local cardLayout = VLayout()

    local image = Image(imagePath)
    image:setImageAlignment('center')
    image:resizeImage(80, 80)

    local label = Label(text)
    label:setTextSize(9)
    label:setTextAlignment('center')

    if highlight then
        label:setTextColor('#307DE1')
    end

    cardLayout:addChild(image)
    cardLayout:addChild(label)
    card:setLayout(cardLayout)

    return card
end

function WelcomeView._createFooter()
    local footer = Label('Built with LOVE from Malawi (warm heart of Africa)')
    footer:setBold(true)
    footer:setTextColor('#2979FF')
    footer:setTextSize(10)
    footer:setTextAlignment('hcenter', 'bottom')
    return footer
end

return WelcomeView
