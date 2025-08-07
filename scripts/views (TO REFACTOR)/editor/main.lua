--[[
                NOTE

- The previous project code was a BIG mess, so I am still refactoring the it,
that's why files are this, look spaghetti.

]]



currentTabIndex = 1
stateLogic = {}

-- returns the current tab editor in use
function getCurrentTabEditor()
    local groupBox = codeEditorMainTab:getChildAt(
        codeEditorMainTab:getCurrentIndex())

    local groupBoxLayout = groupBox:getLayout()
    local lineNumbers = groupBoxLayout:getChildAt(1)
    local editor = groupBoxLayout:getChildAt(2)

    return editor, lineNumbers
end

function handleTabClose()
    local editor, lineNumbers = getCurrentTabEditor()

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
            --     ,
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
        writeToConsole('You can not close the main.lua file')
        return
    end

    if codeEditorMainTab:getCount() == 1 then
        writeToConsole('You can not close the only remaining tab')
        return
    end


    stateLogic[editor] = nil -- remove the editor object from the state logic
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

    if item then
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

            app.writeFile(savePath, saveContent)
            editor:setModified(false)

            showSavedIcon()
        end
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

function updateLineNumbers()
    local editor, lineNumbers = getCurrentTabEditor()
    lineNumbers:clear()
    local line_count = editor:getLineCount()

    local p = ""
    for i = 1, line_count do
        p = p .. tostring(i) .. (i < line_count and "\n" or "")
    end

    lineNumbers:setText(p)
end

function updateTabIcon(container)
    local index = codeEditorMainTab:getIndexOf(container)

    if index >= 1 then
        local editor = getCurrentTabEditor()
        -- Check if the document content have indeed been modified
        if editor:isModified() then
            showUnsavedIcon()
        else
            showSavedIcon()
        end

        updateLineNumbers()
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

    -- Highlights strings
    string_format = TextFormat()
    string_format.setForegroundColor(163, 21, 21) -- Red

    table.insert(highlightingRules, { RegularExpression('\\".*?\"'), string_format })
    table.insert(highlightingRules, { RegularExpression('\'.*?\''), string_format })

    -- Highlights comments
    comment_format = TextFormat()
    comment_format:setForegroundColor(0, 128, 0) -- green

    table.insert(highlightingRules, { RegularExpression('--.*'), comment_format })
    table.insert(highlightingRules, { RegularExpression("--\\[\\[.*?\\]\\]"), comment_format })

    -- Highlights numbers
    number_format = TextFormat()
    number_format:setForegroundColor(128, 0, 128) -- Purple
    table.insert(highlightingRules, { RegularExpression('\'.*?\''), number_format })

    -- Highlights functions
    function_format = TextFormat()
    function_format:setForegroundColor(42, 0, 255) -- Darker blue
    function_format:setFontWeight('bold')
    table.insert(highlightingRules, { RegularExpression('\\b[A-Za-z0-9_]+(?=\\()'), function_format })


    editorSyntaxHighliter = SyntaxHighlighter(editor)
    editorSyntaxHighliter:setOnHighlighBlock(function(sender, text)
        for _, rules in ipairs(highlightingRules) do
            local pattern, format = rules[1], rules[2]

            -- The following code is a workaround, the code uses python syntax
            -- but the regex is lua. The regex engine is not the same as python's.

            local match_iterator = pattern.globalMatch(text)

            while match_iterator.hasNext() do
                local match = match_iterator.next()
                sender:setFormat(match.capturedStart(),
                    match.capturedLength(), format)
            end
        end
    end)
end

--Handles creation of a new tab
-- Consists if an HLay that holds a linenumber Label and the editor

function addNewTab(title, content, path)
    local editorLineContainer = Container()

    local editorLineHLay = HLayout()
    editorLineHLay:setMargins(0, 0, 0, 0)
    editorLineHLay:setSpacing(0)
    editorLineContainer:setLayout(editorLineHLay)

    local editor = TextField()
    editor:setTabSize(8)
    editor:setTextSize(10)

    local lineNumbers = TextField()
    -- lineNumbers:setStyle([[
    --     TextField {{
    --         background: #f0f0f0;
    --         border: none;
    --         color: #888;
    --         font: 11pt;
    --         padding-right: 5px;
    --     }}
    -- ]])
    lineNumbers:setTextInteraction('none')
    lineNumbers:setTextSize(10)
    lineNumbers:setFixedWidth(40)
    lineNumbers:setVerticalScrollBarBehavior('hidden')
    lineNumbers:setReadOnly(true)
    lineNumbers:setFrameShape('none')

    -- lineNumbers:setMinHeight(100)
    -- lineNumbers:setResizeRule('fixed', 'minimum')
    -- lineNumbers:setTextSize(10)
    -- lineNumbers:setMargins(0, 3, 0, 0)



    function updateLineNumberss()
        local text = ''
        local blockCount = editor:getBlockCount()

        for i = 1, blockCount do
            text = text .. string.format("%d\n", i)
        end

        if text:sub(-1) == '\n' then
            text = text:sub(1, -2)
        end

        lineNumbers:setText(text)
    end

    function updateLineNumbersf()
        lineNumbers:clear()
        local line_count = editor:getLineCount()

        local p = ""
        for i = 1, line_count do
            p = p .. tostring(i) .. (i < line_count and "\n" or "")
        end

        lineNumbers:setText(p)
    end

    addSyntaxHighlight(editor)

    -- editor:setWrapMode('nowrap')
    editor:setPlainText(content)
    editor:setModified(false)

    -- editor:setOnKeyPress(function(s, event)
    -- end)

    editor:setOnVerticalScrollBarValueChange(function(sender, value)
        lineNumbers:setVerticalScrollBarValue(value)
    end)
    editor:setOnModificationChanged(function() updateTabIcon(editorLineContainer) end)
    editor:setOnCursorPositionChanged(updateLineNumbers)

    editorLineHLay:addChild(lineNumbers)
    editorLineHLay:addChild(editor)

    index = codeEditorMainTab:addTab(editorLineContainer, title, images('editor/normal.png'))
    codeEditorMainTab:setCurrentIndex(index)
    editor:setFocus()

    updateLineNumbers()

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
