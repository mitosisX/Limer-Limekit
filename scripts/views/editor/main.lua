
currentTabIndex = 1
stateLogic = {}

function handleTabClose()
	local item = stateLogic[currentTabIndex]

    print(codeEditorMainTab:getCurrentIndex())

	-- if item.editor:isModified() == true then
	-- 	local tabText = codeEditorMainTab:getTabText(currentTabIndex)
	-- 	local reply = app.questionAlertDialog(limekitWindow, 'Unsaved Changes',string.format('Do you want to save changes to %s?', tabText))

	-- 	if reply then
	-- 		print('Pressed Yes')
	-- 	else
	-- 		print('Pressed No')
	-- 	end

	-- 	codeEditorMainTab:removeTab(currentTabIndex)
	-- end

end

-- Sets content from file to the editor
function setTabContent(content)
	stateLogic[currentTabIndex].editor:setText(content)
end

-- Deals with reading the file and populating content in editor
function loadFileContent(path)
	local fileContent = app.readFile(path)

	stateLogic[currentTabIndex].hasUnsavedChanges = false
	setTabContent(fileContent)
end

-- Only called from menu or shortcut (Ctrl+O)
function openFile()
	local fileName = app.openFileDialog(window, 'Open File','F:\\research area\\side6\\side6 api\\watch',{['lua files']={'.lua'}})
	
	if fileName ~= nil then
		fileOpener(fileName)		
	end
end

-- Can be called from anywhere to open a file
function fileOpener(path)
	-- Let's check if the particular is already open in the editor
	for i, item in ipairs(stateLogic) do
		if item.filePath ~= nil then
			-- Check if the file's path equals to that being opened
			if item.filePath == path then

				codeEditorMainTab:setCurrentIndex(i)
				return
			end
		end
	end

	local editor, index, _path = addNewTab(app.getFileName(path), '', path)

	setState(index, editor, _path)

	loadFileContent(path)
end

-- Sets the current tab index, for tracking tabs
function setTabIndex(index)
	currentTabIndex = index
end

-- Switches icon from red to blue
function showSavedIcon()
	codeEditorMainTab:setTabIcon(currentTabIndex, images('editor/normal.png'))
end

function showUnsavedIcon()
	codeEditorMainTab:setTabIcon(currentTabIndex, images('editor/modified.png'))
end

function setTabFileName(index, name)
	stateLogic[currentTabIndex].filePath = name
end

-- Handles all the saving file logic
function saveFile()
	local item = stateLogic[currentTabIndex]

	if not item.filePath then

		local savedName = app.saveFileDialog(window, 'Save your file', '',
			{['lua file'] = {'.lua'}})


		if savedName ~= nil then
			app.writeFile(savedName, item.editor:getText())

			local fileName = app.getFileName(savedName)

			setTabFileName(currentTabIndex, fileName)

			codeEditorMainTab:setTabText(currentTabIndex, fileName)
			item.editor:setModified(false)

			showSavedIcon()
		end
	else
		local savePath = stateLogic[currentTabIndex].filePath
		local saveContent = item.editor:getText()

		app.writeFile(savePath, saveContent)
		item.editor:setModified(false)
		item.hasUnsavedChanges = false	

		showSavedIcon()
	end
end

function createMenu()
	menuStruct = 
	{
    {
        label = '&File', -- Accelerator for letter F
        submenu = {
            {
                name = 'new',
                label = 'New',
                -- icon = images('toolbar/new_project.png'),
                shortcut = "Ctrl+N",
                click = newFile
            }, 
            {
                name = 'open',
                label = 'Open',
                -- icon = images('toolbar/open_project.png'),
                shortcut = "Ctrl+O",
                click = openFile
            },
            {
                name = 'save',
                label = 'Save',
                shortcut = 'Ctrl+S',
                -- icon = images('exit.png'),
                click = saveFile
            },
            {
                name = 'close_tab',
                label = 'Close Tab',
                -- icon = images('exit.png'),
                -- click = function()
                --     app.exit()
                -- end
            },
            {
                name = 'exit',
                label = 'Exit',
                -- icon = images('exit.png'),
                click = function()
                    app.exit()
                end
            }
        }
    }, 
    {
        label = '&Edit',
        name = 'edit_menu',
        submenu = {
            {
                name = 'undo',
                label = "Undo",
                -- click = returnHomePage,
                -- shortcut = "Ctrl+H"
            }, 
            {
                name = 'redo',
                label = "Redo",
                -- click = showAppLog -- Added missing click handler
            }, 
            {
                label = "-",
            }, 
            {
                name = 'cut',
                label = "Cut",
            }, 
            {
                name = 'copy',
                label = "Copy",
            }, 
            {
                name = 'Paste',
                label = "Paste",
            },
        }
    }}

	menubar= Menubar()
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

-- Handles creation of a new tab
function addNewTab(title, content, path)

	local editor = TextField()
	-- editor:setWrapMode('nowrap')
	editor:setPlainText(content)
	editor:setModified(false)

	-- editor:setOnKeyPress(function(s, event)
	-- end)

	editor:setOnModificationChanged(function()
		updateTabIcon(editor)
	end)

	index = codeEditorMainTab:addTab(editor, title, images('editor/normal.png'))
	codeEditorMainTab:setCurrentIndex(index)
	editor:setFocus()

	return editor, index, path
end

-- Appends to the logic state
function setState(index, editor, filePath)
	stateLogic[index] = {
		editor = editor,
		filePath = filePath
	}
end

function newFile()
	local editor, index, path = addNewTab('Untitled', '', nil)

	setState(index, editor, path)
end

codeEditorTabMainLay  = VLayout()

editorHLay = HLayout()

editorSideVLay = VLayout()



-- editorHLay:addLayout(editorSideVLay)
-- codeEditorTabGroup:setMinWidth(500)
-- codeEditorTabGroup:setMaxWidth(500)

-- codeEditorTabGroup:setMinHeight(700)

codeEditorMainTab = Tab()
codeEditorMainTab:setMovable(true)

codeEditorMainTab:setOnTabChange(function(s, index)
	setTabIndex(index)
end)
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

cornerEditorContainer =  Container()
codeEditorMainTab:setCornerChild(cornerEditorContainer)

cornerEditorContainerLayout = HLayout()
addNewTabCornerButton = Button("")
addNewTabCornerButton:setIcon(images('editor/new_tab.png'))
addNewTabCornerButton:setFixedSize(30,30)
addNewTabCornerButton:setOnClick(newFile)
cornerEditorContainerLayout:addChild(addNewTabCornerButton)

cornerEditorContainer:setLayout(cornerEditorContainerLayout)

-- addNewTab('Untitled','',nil) -- simply adding a new tab

newFile()

-- Now for the bottom layout, just after the code editor
editorBottomLay = HLayout()
editorBottomLay:setContentAlignment('center') -- the center look does it

-- Only for decor. We want that smooth round edge look
nestedBottomVLay = VLayout()
editorBottomLay:addLayout(nestedBottomVLay)

codeEditorBottomGroupBox = GroupBox()
codeEditorBottomGroupBox:setResizeRule('fixed','fixed')

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
bottomGroupBoxLay:addSpacer(Spacer(25,5))
bottomGroupBoxLay:addChild(Separator('vertical'))

codeEditorNewButton       = Button('New')
codeEditorNewButton:setOnClick(newFile)
codeEditorNewButton:setIcon(images('editor/new1.png'))

codeEditorCloseTabButton  = Button("Close")
codeEditorCloseTabButton:setIcon(images('editor/close.png'))

codeEditorSaveButton      = Button("Save")
codeEditorSaveButton:setOnClick(saveFile)
codeEditorSaveButton:setIcon(images('editor/normal.png'))

codeEditorOpenButton      = Button("Open")
codeEditorOpenButton:setOnClick(openFile)
codeEditorOpenButton:setIcon(images('editor/open.png'))

codeEditorRedoButton      = Button("Redo")
codeEditorRedoButton:setIcon(images('editor/redo.png'))

codeEditorUndoButton      = Button("Undo")
codeEditorUndoButton:setIcon(images('editor/undo.png'))

codeEditorCutButton       = Button("Cut")
codeEditorCutButton:setIcon(images('editor/cut2.png'))

codeEditorCopyButton      = Button("Copy")
codeEditorCopyButton:setIcon(images('editor/copy.png'))

codeEditorPasteButton     = Button("Paste")
codeEditorPasteButton:setIcon(images('editor/paste.png'))

bottomGroupBoxLay:addChild(codeEditorNewButton)
bottomGroupBoxLay:addChild(codeEditorCloseTabButton)
bottomGroupBoxLay:addChild(codeEditorSaveButton)
bottomGroupBoxLay:addChild(codeEditorOpenButton)
bottomGroupBoxLay:addSpacer(Spacer(25,5))

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
codeEditorRunProgress:setResizeRule('minimum','fixed')
codeEditorRunProgress:setVisibility(false)

nestedBottomVLay:addChild(codeEditorRunProgress)
