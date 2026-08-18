-- AboutPage Module
-- Modal dialog showing application information

local ui  = require("limekit.ui")
local res = require("limekit.res")

local App = require "app.core.app"

local AboutPage = {}

function AboutPage.show()
    local modal = ui.Modal("About Limer", App.window)
    modal:setMinSize(550, 400)
    modal:setMaxSize(550, 400)

    local mainLayout = ui.HLayout()

    local groupBox = ui.GroupBox()
    groupBox:setBackgroundColor('#307DE1')

    local groupLayout = ui.HLayout()

    local gifs = { 'homepage/sheep.gif', 'homepage/cat.gif' }
    local randomGif = gifs[math.random(#gifs)]

    local gifPlayer = ui.GifPlayer(res.Resources.images(randomGif))
    gifPlayer:setSize(120, 120)
    gifPlayer:setResizeRule('fixed', 'fixed')
    gifPlayer:setMargins(90, 0, 0, 0)

    groupLayout:addChild(gifPlayer)
    groupLayout:addChild(ui.VLine())

    local infoLayout = ui.VLayout()
    infoLayout:setContentAlignment('center')

    local infoItems = {
        { title = 'Name',           value = 'Limekit\n' },
        { title = 'Version',        value = '1.0 (Debbie)\n' },
        { title = 'Chief Developer', value = 'Omega Msiska\n' },
        { title = 'Company',        value = 'Rézolu\n' },
        { title = 'GitHub',         value = 'mitosisx' }
    }

    for _, item in ipairs(infoItems) do
        local titleLabel = ui.Label(item.title)
        titleLabel:setBold(true)
        titleLabel:setTextColor('white')

        local valueLabel = ui.Label(item.value)
        valueLabel:setTextColor('white')

        infoLayout:addChild(titleLabel)
        infoLayout:addChild(valueLabel)
    end

    groupLayout:addLayout(infoLayout)
    groupBox:setLayout(groupLayout)
    mainLayout:addChild(groupBox)

    modal:setLayout(mainLayout)
    modal:show()
end

return AboutPage
