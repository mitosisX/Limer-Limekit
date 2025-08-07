function aboutPage()
    modal = Modal(limekitWindow, "About Limer")
    modal:setMinSize(550, 400)
    modal:setMaxSize(550, 400)

    createMainLayout = HLayout()

    groupB = GroupBox()
    groupB:setBackgroundColor('#307DE1')

    theGroupLay = HLayout()

    local gifs = { 'homepage/sheep.gif', 'homepage/cat.gif' }
    local randomIndex = math.random(1, #gifs)
    local randomFruit = gifs[randomIndex]

    gi = GifPlayer(images(randomFruit))
    gi:setSize(120, 120)
    gi:setResizeRule('fixed', 'fixed')
    gi:setMargins(90, 0, 0, 0)

    theGroupLay:addChild(gi)

    theGroupLay:addChild(VLine())

    gBLayo = VLayout()
    gBLayo:setContentAlignment('center')

    aboutNameTitle = Label('Name')
    aboutNameTitle:setBold(true)
    aboutNameTitle:setTextColor('white')

    aboutName = Label('Limekit\n')
    aboutName:setTextColor('white')

    gBLayo:addChild(aboutNameTitle)
    gBLayo:addChild(aboutName)

    aboutVersionTitle = Label('Version')
    aboutVersionTitle:setBold(true)
    aboutVersionTitle:setTextColor('white')

    aboutVersion = Label('1.0 (Debbie)\n')
    aboutVersion:setTextColor('white')

    gBLayo:addChild(aboutVersionTitle)
    gBLayo:addChild(aboutVersion)

    aboutChiefTitle = Label('Chief Developer')
    aboutChiefTitle:setBold(true)
    aboutChiefTitle:setTextColor('white')

    aboutChief = Label('Omega Msiska\n')
    aboutChief:setTextColor('white')

    gBLayo:addChild(aboutChiefTitle)
    gBLayo:addChild(aboutChief)

    title3 = Label('Company')
    title3:setBold(true)
    title3:setTextColor('white')
    subTitle3 = Label('Rézolu\n')
    subTitle3:setTextColor('white')

    gBLayo:addChild(title3)
    gBLayo:addChild(subTitle3)

    title4 = Label('github')
    title4:setBold(true)
    title4:setTextColor('white')
    subTitle4 = Label('mitosisx')
    subTitle4:setTextColor('white')

    gBLayo:addChild(title4)
    gBLayo:addChild(subTitle4)

    theGroupLay:addLayout(gBLayo)
    groupB:setLayout(theGroupLay)
    createMainLayout:addChild(groupB)

    -- buttons = modal:getButtons({'ok', 'cancel'})
    -- v:addChild(buttons)

    modal:setLayout(createMainLayout)

    modal:show()
end

return aboutPage
