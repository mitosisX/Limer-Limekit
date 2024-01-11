propsTabMainLay = VLayout()
propsTabMainLay:setContentAlignment('vcenter', 'center')

propsTabGroup = GroupBox()
propsTabGroup:setMinHeight(400) -- Height
propsTabGroup:setMaxHeight(400)

propsTabGroup:setMinWidth(500) -- Width
propsTabGroup:setMaxWidth(500)

DropShadow(propsTabGroup)

propsContentLay = HLayout() -- This is where everything inside the GroupBox will reside

pathsLay = VLayout()
pathsHeader = Label('package.path')
pathsHeader:setTextAlign('center')

pathsList = ListBox()
pathsList:addItem('default: misc') -- Only showing that the misc folder is automatically added to path

pathsGroupLay = HLayout()
pathsGroupLay:setContentAlignment('right')

pathsGroupLay.setEnabled(false)

addPathButton = Button('add')

addPathButton:setOnClick(function()
    packagePath = app.folderPickerDialog(window, 'Select a path')

    if packagePath ~= miscFolder and packagePath ~= scriptsFolder and packagePath ~= imagesFolder then
        table.insert(allRequirePathsTable, packagePath)

        pathsList:addItem(packagePath)

        packagePathsWriter()
    else
        app.criticalAlertDialog(window, 'Error!',
            "Please do not pick the 'misc, images, scripts' folders from your project")
    end
end)

addPathButton:setIcon(images('app/add.png'))
addPathButton:setResizeRule('fixed', 'fixed')

removePathButton = Button('remove')
removePathButton:setIcon(images('app/cross.png'))
removePathButton:setResizeRule('fixed', 'fixed')
removePathButton:setOnClick(function()
    row = pathsList:getCurrentRow()

    if row ~= 0 then -- That's where the "default: misc" is
        table.remove(allRequirePathsTable, row) -- ListBox indexing starts at 0
        pathsList:removeItem(row)

        packagePathsWriter()
    end
end)

pathsGroupLay:addChild(addPathButton)
pathsGroupLay:addChild(removePathButton)

pathsLay:addChild(pathsHeader)
pathsLay:addChild(pathsList)
pathsLay:addLayout(pathsGroupLay) -- Holding the remove and add path buttons

propsContentLay:addLayout(pathsLay)

routesLay = VLayout()
routesLay:setMargins(20, 0, 0, 0)
routesHeader = Label('routes')
routesHeader:setTextAlign('center')

routesList = Table()

routesGrouperLay = HLayout()
routesGrouperLay:setContentAlignment('right')

addRouteButton = Button('add')
addRouteButton:setIcon(images('app/add.png'))
addRouteButton:setResizeRule('fixed', 'fixed')

removeRouteButton = Button('remove')
removeRouteButton:setIcon(images('app/cross.png'))
removeRouteButton:setResizeRule('fixed', 'fixed')

routesGrouperLay:addChild(addRouteButton)
routesGrouperLay:addChild(removeRouteButton)

routesLay:addChild(routesHeader)
routesLay:addChild(routesList)
routesLay:addLayout(routesGrouperLay)

propsContentLay:addLayout(routesLay)

propsTabGroup:setLayout(propsContentLay)

propsTabMainLay:addChild(propsTabGroup)
