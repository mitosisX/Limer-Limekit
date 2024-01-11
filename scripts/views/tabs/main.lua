app.execute(scripts('views/tabs/app/apptab.lua'))
app.execute(scripts('views/tabs/app/properties.lua'))
-- app.execute(scripts('views/app/database.lua'))

allAppTabs = Tab() -- The tab holding all tab items

appTab = TabItem()
appTab:setLayout(appTabMainLay)

browseDataTab = TabItem()
browseDataTab:setLayout(browseLay)

editPragramsTab = TabItem()

appPropertiesTab = TabItem()
appPropertiesTab:setLayout(propsTabMainLay)

allAppTabs:addTab(appTab, "App", images('tabs/app.png'))

-- allAppTabs:addTab(editPragramsTab, "Assets", images('tabs/resources.png'))
allAppTabs:addTab(appPropertiesTab, "Properties", images('tabs/properties.png'))