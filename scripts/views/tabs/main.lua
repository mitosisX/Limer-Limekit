app.executeFile(scripts('views/editor/main.lua'))
app.executeFile(scripts('views/tabs/app/apptab.lua'))
app.executeFile(scripts('views/tabs/app/properties.lua'))

allAppTabs = Tab() -- The tab holding all tab items
allAppTabs:setStyle(appTabLightStyle)
allAppTabs:setMovable(true)

appTab = Container()
appTab:setLayout(appTabMainLay)

browseDataTab = Container()
browseDataTab:setLayout(browseLay)

editPragramsTab = Container()

appPropertiesTab = Container()
appPropertiesTab:setLayout(propsTabMainLay)

appCodeEditorTab = Container()
appCodeEditorTab:setLayout(codeEditorTabMainLay)

allAppTabs:addTab(appTab, "App", images('tabs/app.png'))

-- allAppTabs:addTab(editPragramsTab, "Assets", images('tabs/resources.png'))
allAppTabs:addTab(appPropertiesTab, "Properties", images('tabs/properties.png'))

allAppTabs:addTab(appCodeEditorTab, "Code Editor", images('tabs/properties.png'))