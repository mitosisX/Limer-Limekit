-- CodeEditorPanel Module
-- Code editor with scope selector and execution controls

local AppState = require "app.core.app_state"
local App = require "app.core.app"
local Paths = require "app.core.config.paths"

local CodeEditorPanel = {}

function CodeEditorPanel.create(options)
    options = options or {}

    local self = {
        view = Container(),
        mainLayout = VLayout(),
        toolbarLayout = HLayout(),
        codeField = TextField(),
        scopeSelector = ComboBox(),
        pickWidgetButton = Button(),
        targetLabel = Label(''),
        runButton = Button('Run'),
        clearButton = Button('Clear'),
        executionTimeLabel = Label(''),
        executionIndicator = ProgressBar(),
        isExecuting = false,
        currentTarget = nil,
        onExecute = options.onExecute,
        onClear = options.onClear
    }

    local function createToolbar()
        self.toolbarLayout:setContentAlignment('left', 'vcenter')
        self.toolbarLayout:setMargins(0, 0, 0, 5)

        -- Scope selector
        local scopeLabel = Label('Scope:')
        scopeLabel:setResizeRule('fixed', 'fixed')

        self.scopeSelector:addItem('Global')
        self.scopeSelector:addItem('Module')
        self.scopeSelector:addItem('Widget')
        self.scopeSelector:setResizeRule('fixed', 'fixed')
        self.scopeSelector:setFixedWidth(100)

        -- Widget picker button
        self.pickWidgetButton:setText('')
        self.pickWidgetButton:setIcon(images('widgets/Widget.png'))
        self.pickWidgetButton:setToolTip('Pick a widget from running app')
        self.pickWidgetButton:setResizeRule('fixed', 'fixed')
        self.pickWidgetButton:setEnabled(false)
        self.pickWidgetButton:setOnClick(function()
            if self.onPickWidget then
                self.onPickWidget()
            end
        end)

        -- Target label (shows selected widget)
        self.targetLabel:setTextColor('#888888')
        self.targetLabel:setResizeRule('expanding', 'fixed')

        self.toolbarLayout:addChild(scopeLabel)
        self.toolbarLayout:addChild(self.scopeSelector)
        self.toolbarLayout:addChild(self.pickWidgetButton)
        self.toolbarLayout:addChild(self.targetLabel)

        self.mainLayout:addLayout(self.toolbarLayout)
    end

    local function createCodeEditor()
        self.codeField:setHint('-- Enter Lua code here...\n-- Example: myButton:setText("Hello")')
        self.codeField:setToolTip('Code entered here will be executed in the running application')
        self.codeField:setTabSize(4)
        self.codeField:setMinHeight(150)

        self.mainLayout:addChild(self.codeField)
    end

    local function createActionBar()
        local actionLayout = HLayout()
        actionLayout:setContentAlignment('left', 'vcenter')
        actionLayout:setMargins(0, 5, 0, 0)

        -- Run button
        self.runButton:setIcon(images('app/run.png'))
        self.runButton:setResizeRule('fixed', 'fixed')
        self.runButton:setEnabled(false)
        self.runButton:setOnClick(function()
            if self.onExecute then
                local code = self.codeField:getText()
                local scope = self.scopeSelector:getCurrentText()
                local target = self.currentTarget

                if code and code ~= "" then
                    self.onExecute(code, scope, target)
                end
            end
        end)

        -- Clear button
        self.clearButton:setIcon(images('app/cross.png'))
        self.clearButton:setResizeRule('fixed', 'fixed')
        self.clearButton:setOnClick(function()
            self.codeField:clear()
            if self.onClear then
                self.onClear()
            end
        end)

        -- Execution indicator (hidden by default)
        self.executionIndicator:setRange(0, 0)
        self.executionIndicator:setMaxHeight(3)
        self.executionIndicator:setMaxWidth(50)
        self.executionIndicator:setVisibility(false)

        -- Execution time label
        self.executionTimeLabel:setTextColor('#888888')
        self.executionTimeLabel:setResizeRule('fixed', 'fixed')

        actionLayout:addChild(self.runButton)
        actionLayout:addChild(self.clearButton)
        actionLayout:addChild(self.executionIndicator)
        actionLayout:addStretch()
        actionLayout:addChild(self.executionTimeLabel)

        self.mainLayout:addLayout(actionLayout)
    end

    local function setupTextChangeHandler()
        self.codeField:setOnTextChange(function(sender, text)
            local hasCode = text and string.len(text) > 0
            local canRun = hasCode and AppState.projectIsRunning
            self.runButton:setEnabled(canRun)
        end)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        createToolbar()
        createCodeEditor()
        createActionBar()
        setupTextChangeHandler()
    end

    initComponents()

    return {
        view = self.view,

        getCode = function()
            return self.codeField:getText()
        end,

        setCode = function(code)
            self.codeField:setText(code)
        end,

        clearCode = function()
            self.codeField:clear()
        end,

        getScope = function()
            return self.scopeSelector:getCurrentText()
        end,

        getTarget = function()
            return self.currentTarget
        end,

        setTarget = function(target, displayName)
            self.currentTarget = target
            self.targetLabel:setText(displayName or '')
        end,

        clearTarget = function()
            self.currentTarget = nil
            self.targetLabel:setText('')
        end,

        setExecuting = function(executing)
            self.isExecuting = executing
            self.executionIndicator:setVisibility(executing)
            self.runButton:setEnabled(not executing and AppState.projectIsRunning)
        end,

        setExecutionTime = function(timeMs)
            if timeMs then
                self.executionTimeLabel:setText(string.format('%.2fms', timeMs))
            else
                self.executionTimeLabel:setText('')
            end
        end,

        setProjectRunning = function(running)
            self.pickWidgetButton:setEnabled(running)
            local hasCode = self.codeField:getText() and string.len(self.codeField:getText()) > 0
            self.runButton:setEnabled(running and hasCode)
        end,

        setOnExecute = function(callback)
            self.onExecute = callback
        end,

        setOnClear = function(callback)
            self.onClear = callback
        end,

        setOnPickWidget = function(callback)
            self.onPickWidget = callback
        end,

        insertAtCursor = function(text)
            local current = self.codeField:getText() or ""
            self.codeField:setText(current .. text)
        end
    }
end

return CodeEditorPanel
