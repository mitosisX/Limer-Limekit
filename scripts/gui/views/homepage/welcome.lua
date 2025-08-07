local WelcomeView = {}

local ProjectCreator = require "gui.modals.project_creator"
-- local images = require 'app.utils.images'
-- local ProjectCreator = require 'app.modals.project_creator'

function WelcomeView.create()
    local layout = VLayout()
    layout:setContentAlignment('vcenter', 'center')

    -- Add top spacing
    layout:addStretch()

    -- Add animated GIF
    local gif_paths = {
        'homepage/sheep.gif',
        'homepage/cat.gif'
    }

    local welcome_gif = GifPlayer(images(gif_paths[math.random(#gif_paths)]))
    welcome_gif:setSize(120, 120)
    layout:addChild(welcome_gif)

    -- Add title
    local title = Label('<strong>Limer</strong> -')
    title:setTextSize(32)
    layout:addChild(title)

    -- Add feature cards
    local features = WelcomeView.create_feature_cards()
    layout:addLayout(features)

    -- Add create project button
    -- local create_btn = CommandButton('Create a project')
    -- create_btn:setResizeRule('fixed', 'fixed')
    -- -- create_btn:setOnClick(ProjectCreator.show)
    -- layout:addChild(create_btn)

    commandLay = HLayout()
    commandLay:setContentAlignment('right')

    commandCreateProject = CommandButton('Create a project')
    commandCreateProject:setResizeRule('fixed', 'fixed')
    commandCreateProject:setOnClick(ProjectCreator.show)

    commandLay:addChild(commandCreateProject)

    layout:addLayout(commandLay)

    -- Add bottom spacing and footer
    layout:addStretch()
    layout:addChild(WelcomeView.create_footer())

    return layout
end

function WelcomeView.create_feature_cards()
    local features_layout = HLayout()
    local feature_items = {
        { image = 'homepage/modern.png',   text = 'Develop modern UI' },
        { image = 'homepage/lua_logo.png', text = 'Developed in lua' },
        { image = 'homepage/hundred.png',  text = 'Free for everyone' },
        { image = 'homepage/battery.png',  text = 'Batteries Included' },
        { image = 'homepage/bug.png',      text = 'Please report bugs' },
        { image = 'homepage/support.png',  text = '<strong>Support this project', highlight = true }
    }

    for _, item in ipairs(feature_items) do
        features_layout:addChild(WelcomeView.create_feature_card(
            images(item.image),
            item.text,
            item.highlight
        ))
    end

    return features_layout
end

function WelcomeView.create_feature_card(image_path, text, highlight)
    local card = GroupBox()
    local card_layout = VLayout()

    local image = Image(image_path)
    image:setImageAlignment('center')
    image:resizeImage(80, 80)

    local label = Label(text)
    label:setTextSize(9)
    label:setTextAlignment('center')

    if highlight then
        label:setTextColor('#307DE1')
    end

    card_layout:addChild(image)
    card_layout:addChild(label)
    card:setLayout(card_layout)

    return card
end

function WelcomeView.create_footer()
    local footer = Label('Built with LOVE from Malawi (warm heart of Africa)')
    footer:setBold(true)
    footer:setTextColor('#2979FF')
    footer:setTextSize(10)
    footer:setTextAlignment('hcenter', 'bottom')
    return footer
end

return WelcomeView
