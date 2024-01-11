function fectchData()
    db:execute('SELECT * FROM Fruits;')
    data = db:fetchAll()

    return data
end

database = nil
function openDBFile()
    file = app.openFileDialog(window, "Choose a database file", "D:/sandbox", {
        ["SQLite database files"] = {".db", ".sqlite", ".sqlite3", ".db3"}
    })

    database = Sqlite3(file)

    getTables()
end

function getTables()
    tables = database:fetchTables()

    for index = 1, #tables do
        item = tables[index]
        tablesCombo:addItem(item)
    end
end

browseLay = VLayout()
browseOptionsLay = HLayout()

tableText = Label('Text:')
tableText:setResizeRule('fixed', 'fixed')

tablesCombo = ComboBox()
-- tablesCombo:setResizeRule('fixed','fixed')

refreshDataButton = Button('')
refreshDataButton:setFlat(true)
refreshDataButton:setResizeRule('fixed', 'fixed')
refreshDataButton:setIcon(images('arrow_refresh_small.png'))

clearFiltersButton = Button('')
clearFiltersButton:setFlat(true)
clearFiltersButton:setResizeRule('fixed', 'fixed')
clearFiltersButton:setIcon(images('funnel_delete.png'))

saveTableButton = Button('')
saveTableButton:setFlat(true)
saveTableButton:setResizeRule('fixed', 'fixed')
saveTableButton:setIcon(images('table_save.png'))

printButton = Button('')
printButton:setFlat(true)
printButton:setResizeRule('fixed', 'fixed')
printButton:setIcon(images('print.png'))

addRecordButton = Button('')
addRecordButton:setFlat(true)
addRecordButton:setResizeRule('fixed', 'fixed')
addRecordButton:setIcon(images('table_add.png'))

deleteRecordButton = Button('')
deleteRecordButton:setFlat(true)
deleteRecordButton:setResizeRule('fixed', 'fixed')
deleteRecordButton:setIcon(images('table_delete.png'))

browseOptionsLay:addChild(tableText)
browseOptionsLay:addChild(tablesCombo)
browseOptionsLay:addChild(refreshDataButton)
browseOptionsLay:addChild(clearFiltersButton)
browseOptionsLay:addChild(VLine())
browseOptionsLay:addChild(saveTableButton)
browseOptionsLay:addChild(printButton)
browseOptionsLay:addChild(addRecordButton)
browseOptionsLay:addChild(deleteRecordButton)

browseLay:addLayout(browseOptionsLay)

browseDataTable = Table(10, 10)
browseDataTable:setColumnHeaders({"One", "Two", "Three"})

browseLay:addChild(browseDataTable)
