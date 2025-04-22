currentTabIndex = 1
stateLogic = {}

-- returns the current tab editor in use
function getCurrentTabEditor()
    local child = codeEditorMainTab:getChildAt(
        codeEditorMainTab:getCurrentIndex())

    return child
end

function handleTabClose()
    local editor = getCurrentTabEditor()

    local mainFilePath = app.joinPaths(userScriptsFolder, 'main.lua')

    if editor:isModified() then
        local item = stateLogic[editor]

        if item.filePath == nil then
            local tabText = codeEditorMainTab:getTabText(currentTabIndex)
            local reply = app.questionAlertDialog(limekitWindow,
                'Unsaved Changes',
                string.format(
                    'Do you want to save changes to %s?',
                    tabText)
            -- { 'Save', 'Discard', 'Cancel' }
            )

            if reply then
                saveFileContent(item.filePath, editor:getText())

                editor:setModified(false)
                showSavedIcon()
            elseif reply == nil then
                print('X pressed')
            end
        else
            saveFileContent(item.filePath, editor:getText())

            editor:setModified(false)
            showSavedIcon()
        end
    end

    -- By all means, never close the main file in the root folder of user project
    if mainFilePath == stateLogic[editor].filePath then
        writeToConsole('You cannot close the main.lua file')
        return
    end

    codeEditorMainTab:removeTab(currentTabIndex)
end

-- Sets content from file to the editor
function setTabContent(content) getCurrentTabEditor():setText(content) end

-- Deals with reading the file and populating content in editor
function loadFileContent(path)
    local fileContent = app.readFile(path)

    setTabContent(fileContent)
end

-- Only called from menu or shortcut (Ctrl+O)
function openFile()
    local fileName = app.openFileDialog(limekitWindow, 'Open File',
        'F:\\research area\\side6\\side6 api\\watch',
        { ['lua files'] = { '.lua' } })

    if fileName ~= nil then fileOpener(app.normalPath(fileName)) end
end

-- Can be called from anywhere to open a file
function fileOpener(path)
    local index = 1
    -- Let's check if the particular is already open in the editor
    for editor, item in pairs(stateLogic) do
        -- Check if the file's path equals to that being opened
        if item.filePath ~= nil and item.filePath == path then
            codeEditorMainTab:setCurrentChild(editor)
            return
        end

        -- index = index + 1
    end

    local editor, _path = addNewTab(app.getFileName(path), '', path)

    setState(editor, _path)

    loadFileContent(path)
end

-- Sets the current tab index, for tracking tabs
function setTabIndex(index) currentTabIndex = index end

-- Switches icon from red to blue
function showSavedIcon()
    codeEditorMainTab:setTabIcon(currentTabIndex, images('editor/normal.png'))
end

function showUnsavedIcon()
    codeEditorMainTab:setTabIcon(currentTabIndex, images('editor/modified.png'))
end

function saveFileContent(fileName, content) app.writeFile(fileName, content) end

function setTabFileName(index, name)
    local editor = getCurrentTabEditor()
    stateLogic[editor].filePath = name
    codeEditorMainTab:setTabText(index, name)
end

-- Handles all the saving file logic
function saveFile()
    local editor = getCurrentTabEditor()
    local item = stateLogic[editor]

    if item.filePath == nil then
        local savedName = app.saveFileDialog(window, 'Save your file', '',
            { ['lua file'] = { '.lua' } })

        if savedName ~= nil then
            saveFileContent(savedName, editor:getText())

            local fileName = app.getFileName(savedName)

            setTabFileName(currentTabIndex, fileName)

            codeEditorMainTab:setTabText(currentTabIndex, fileName)
            editor:setModified(false)

            showSavedIcon()
        end
    else
        local savePath = item.filePath
        local saveContent = editor:getText()

        print('#### ', saveContent)

        app.writeFile(savePath, saveContent)
        editor:setModified(false)

        showSavedIcon()
    end
end

function createMenu()
    menuStruct = {
        {
            label = '&File', -- Accelerator for letter F
            submenu = {
                {
                    name = 'new',
                    label = 'New',
                    -- icon = images('toolbar/new_project.png'),
                    shortcut = "Ctrl+N",
                    click = newFile
                }, {
                name = 'open',
                label = 'Open',
                -- icon = images('toolbar/open_project.png'),
                shortcut = "Ctrl+O",
                click = openFile
            }, {
                name = 'save',
                label = 'Save',
                shortcut = 'Ctrl+S',
                -- icon = images('exit.png'),
                click = saveFile
            }, {
                name = 'close_tab',
                label = 'Close Tab'
                -- icon = images('exit.png'),
                -- click = function()
                --     app.exit()
                -- end
            }, {
                name = 'exit',
                label = 'Exit',
                -- icon = images('exit.png'),
                click = function() app.exit() end
            }
            }
        }, {
        label = '&Edit',
        name = 'edit_menu',
        submenu = {
            {
                name = 'undo',
                label = "Undo"
                -- click = returnHomePage,
                -- shortcut = "Ctrl+H"
            }, {
            name = 'redo',
            label = "Redo"
            -- click = showAppLog -- Added missing click handler
        }, { label = "-" }, { name = 'cut', label = "Cut" },
            { name = 'copy',  label = "Copy" },
            { name = 'Paste', label = "Paste" }
        }
    }
    }

    menubar = Menubar()
    menubar:buildFromTemplate(menuStruct)
    window:setMenubar(menubar)
end

function updateTabIcon(editor)
    local index = codeEditorMainTab:getIndexOf(editor)

    if index >= 1 then
        -- Check if the document content have indeed been modified
        if editor:isModified() then
            showUnsavedIcon()
        else
            showSavedIcon()
        end
    end
end

function handleContentChange(s, position, chars_removed, chars_added)
    -- Handle actual content change
    if chars_removed > 0 or chars_added > 0 then
        stateLogic[currentTabIndex].hasUnsavedChanges = true
        -- print('###### Qt thinks really changed')
    end
end

function addSyntaxHighlight(editor)
    highlightingRules = {}
    keywords = {
        "and", "break", "do", "else", "elseif", "end", "false", "for",
        "function", "if", "in", "local", "nil", "not", "or", "repeat",
        "return", "then", "true", "until", "while", "goto"

    }

    keyword_format = TextFormat()
    keyword_format:setForegroundColor(0, 0, 255) --blue
    keyword_format:setFontWeight('bold')

    for _, keyword in pairs(keywords) do
        pattern = "\\b" .. keyword .. "\\b"
        table.insert(highlightingRules, { RegularExpression(pattern), keyword_format })
    end

    string_format = TextFormat()
    string_format.setForegroundColor(163, 21, 21) -- Red

    table.insert(highlightingRules, { RegularExpression('\\".*?\"'), string_format })
    table.insert(highlightingRules, { RegularExpression('\'.*?\''), string_format })


    comment_format = TextFormat()
    comment_format:setForegroundColor(0, 128, 0) -- green

    table.insert(highlightingRules, { RegularExpression('--.*'), comment_format })
    table.insert(highlightingRules, { RegularExpression("--\\[\\[.*?\\]\\]"), comment_format })

    number_format = TextFormat()
    number_format:setForegroundColor(128, 0, 128) -- Purple
    table.insert(highlightingRules, { RegularExpression('\'.*?\''), number_format })

    function_format = TextFormat()
    function_format:setForegroundColor(42, 0, 255) -- Darker blue
    function_format:setFontWeight('bold')
    table.insert(highlightingRules, { RegularExpression('\\b[A-Za-z0-9_]+(?=\\()'), function_format })


    editorSyntaxHighliter = SyntaxHighlighter(editor)
    editorSyntaxHighliter:setOnHighlighBlock(function(sender, text)
        for _, rules in ipairs(highlightingRules) do
            local pattern, format = rules[1], rules[2]

            -- The following code is a workaround, the code still uses python syntax
            -- but the regex is Lua. The regex engine is not the same as Python's.

            local match_iterator = pattern.globalMatch(text)

            while match_iterator.hasNext() do
                local match = match_iterator.next()
                sender:setFormat(match.capturedStart(),
                    match.capturedLength(), format)
            end
        end
    end)
end

-- Handles creation of a new tab
function addNewTab(title, content, path)
    local editor = TextField()
    editor:setTextSize(12)

    addSyntaxHighlight(editor)

    -- editor:setWrapMode('nowrap')
    editor:setPlainText(content)

    editor:setModified(false)

    -- editor:setOnKeyPress(function(s, event)
    -- end)

    editor:setOnModificationChanged(function() updateTabIcon(editor) end)

    index = codeEditorMainTab:addTab(editor, title, images('editor/normal.png'))
    codeEditorMainTab:setCurrentIndex(index)
    editor:setFocus()

    return editor, path
end

-- Appends to the logic state
function setState(editor, filePath) stateLogic[editor] = { filePath = filePath } end

function newFile()
    local editor, path = addNewTab('Untitled', '', nil)

    setState(editor, path)
end

codeEditorTabMainLay = VLayout()

editorHLay = HLayout()

editorSideVLay = VLayout()

-- editorHLay:addLayout(editorSideVLay)
-- codeEditorTabGroup:setMinWidth(500)
-- codeEditorTabGroup:setMaxWidth(500)

-- codeEditorTabGroup:setMinHeight(700)

codeEditorMainTab = Tab()
codeEditorMainTab:setMovable(true)

codeEditorMainTab:setOnTabChange(function(s, index) setTabIndex(index) end)
codeEditorMainTab:setOnTabClose(handleTabClose)
codeEditorMainTab:setTabsCloseable(true)
codeEditorMainTab:setStyle([[
Tab:tab-bar{
    alignment: left;
}
]])

editorHLay:addChild(codeEditorMainTab)

codeEditorTabMainLay:addLayout(editorHLay)
-- codeEditorTabMainLay:addChild(aa)

cornerEditorContainer = Container()
codeEditorMainTab:setCornerChild(cornerEditorContainer)

cornerEditorContainerLayout = HLayout()
addNewTabCornerButton = Button("")
addNewTabCornerButton:setIcon(images('editor/new_tab.png'))
addNewTabCornerButton:setFixedSize(30, 30)
addNewTabCornerButton:setOnClick(newFile)
cornerEditorContainerLayout:addChild(addNewTabCornerButton)

cornerEditorContainer:setLayout(cornerEditorContainerLayout)

newFile()

-- Now for the bottom layout, just after the code editor
editorBottomLay = HLayout()
editorBottomLay:setContentAlignment('center') -- the center look does it

-- Only for decor. We want that smooth round edge look
nestedBottomVLay = VLayout()
editorBottomLay:addLayout(nestedBottomVLay)

codeEditorBottomGroupBox = GroupBox()
codeEditorBottomGroupBox:setResizeRule('fixed', 'fixed')

-- Make sure everything goes horizontal inside the groupbox
bottomGroupBoxLay = HLayout()

-- runAppButton:setOnClick(runApp)

codeEditDecorBar = Image(images('editor/bar_dark.png')) -- That cool looking
-- codeEditDecorBar:setImage()
codeEditDecorBar:setImageSize(15, 15)

codeEditorRunAppButton = Button('Run')
codeEditorRunAppButton:setResizeRule('fixed', 'fixed')
codeEditorRunAppButton:setIcon(images('app/run.png'))
codeEditorRunAppButton:setOnClick(runApp)

bottomGroupBoxLay:addChild(codeEditDecorBar)
bottomGroupBoxLay:addChild(codeEditorRunAppButton)
-- bottomGroupBoxLay:addChild(Separator('vertical'))
bottomGroupBoxLay:addSpacer(Spacer(25, 5))
bottomGroupBoxLay:addChild(Separator('vertical'))

codeEditorNewButton = Button('New')
codeEditorNewButton:setOnClick(newFile)
codeEditorNewButton:setIcon(images('editor/new1.png'))

codeEditorCloseTabButton = Button("Close")
codeEditorCloseTabButton:setIcon(images('editor/close.png'))

codeEditorSaveButton = Button("Save")
codeEditorSaveButton:setOnClick(saveFile)
codeEditorSaveButton:setIcon(images('editor/normal.png'))

codeEditorOpenButton = Button("Open")
codeEditorOpenButton:setOnClick(openFile)
codeEditorOpenButton:setIcon(images('editor/open.png'))

codeEditorRedoButton = Button("Redo")
codeEditorRedoButton:setIcon(images('editor/redo.png'))

codeEditorUndoButton = Button("Undo")
codeEditorUndoButton:setIcon(images('editor/undo.png'))

codeEditorCutButton = Button("Cut")
codeEditorCutButton:setIcon(images('editor/cut2.png'))

codeEditorCopyButton = Button("Copy")
codeEditorCopyButton:setIcon(images('editor/copy.png'))

codeEditorPasteButton = Button("Paste")
codeEditorPasteButton:setIcon(images('editor/paste.png'))

bottomGroupBoxLay:addChild(codeEditorNewButton)
bottomGroupBoxLay:addChild(codeEditorCloseTabButton)
bottomGroupBoxLay:addChild(codeEditorSaveButton)
bottomGroupBoxLay:addChild(codeEditorOpenButton)
bottomGroupBoxLay:addSpacer(Spacer(25, 5))

bottomGroupBoxLay:addChild(Separator('vertical'))

bottomGroupBoxLay:addChild(codeEditorUndoButton)
bottomGroupBoxLay:addChild(codeEditorRedoButton)
bottomGroupBoxLay:addChild(codeEditorCutButton)
bottomGroupBoxLay:addChild(codeEditorCopyButton)
bottomGroupBoxLay:addChild(codeEditorPasteButton)

codeEditorBottomGroupBox:setLayout(bottomGroupBoxLay)

nestedBottomVLay:addChild(codeEditorBottomGroupBox)

codeEditorTabMainLay:addLayout(editorBottomLay)

codeEditorRunProgress = ProgressBar()
codeEditorRunProgress:setRange(0, 0)
codeEditorRunProgress:setMaxHeight(5)
-- runProgress:setMaxWidth(20)
codeEditorRunProgress:setResizeRule('minimum', 'fixed')
codeEditorRunProgress:setVisibility(false)

nestedBottomVLay:addChild(codeEditorRunProgress)
