-- WatchPanel Module
-- Manages watch expressions that are evaluated periodically

local AppState = require "app.core.app_state"

local WatchPanel = {}

function WatchPanel.create(options)
    options = options or {}

    local self = {
        view = Container(),
        mainLayout = VLayout(),
        headerLayout = HLayout(),
        addWatchInput = LineEdit(),
        addWatchButton = Button(),
        watchTable = Table(),
        refreshButton = Button(),
        removeButton = Button(),
        watches = {},
        onEvaluate = options.onEvaluate,
        onWatchAdded = options.onWatchAdded,
        onWatchRemoved = options.onWatchRemoved
    }

    local function createHeader()
        self.headerLayout:setContentAlignment('left', 'vcenter')
        self.headerLayout:setMargins(0, 0, 0, 3)

        local titleLabel = Label('<strong>Watch</strong>')
        titleLabel:setResizeRule('fixed', 'fixed')

        -- Refresh button
        self.refreshButton:setText('')
        self.refreshButton:setIcon(images('arrow_refresh_small.png'))
        self.refreshButton:setToolTip('Refresh all watches')
        self.refreshButton:setResizeRule('fixed', 'fixed')
        self.refreshButton:setEnabled(false)
        self.refreshButton:setOnClick(function()
            refreshAllWatches()
        end)

        -- Remove button
        self.removeButton:setText('')
        self.removeButton:setIcon(images('app/cross.png'))
        self.removeButton:setToolTip('Remove selected watch')
        self.removeButton:setResizeRule('fixed', 'fixed')
        self.removeButton:setOnClick(function()
            removeSelectedWatch()
        end)

        self.headerLayout:addChild(titleLabel)
        self.headerLayout:addStretch()
        self.headerLayout:addChild(self.refreshButton)
        self.headerLayout:addChild(self.removeButton)

        self.mainLayout:addLayout(self.headerLayout)
    end

    local function createAddWatchRow()
        local addLayout = HLayout()
        addLayout:setMargins(0, 0, 0, 3)

        self.addWatchInput:setHint('Enter expression to watch...')
        self.addWatchInput:setOnReturnPress(function()
            addWatch()
        end)

        self.addWatchButton:setText('')
        self.addWatchButton:setIcon(images('app/add.png'))
        self.addWatchButton:setToolTip('Add watch expression')
        self.addWatchButton:setResizeRule('fixed', 'fixed')
        self.addWatchButton:setOnClick(function()
            addWatch()
        end)

        addLayout:addChild(self.addWatchInput)
        addLayout:addChild(self.addWatchButton)

        self.mainLayout:addLayout(addLayout)
    end

    local function createWatchTable()
        self.watchTable:setColumns(lua_table({'Expression', 'Value'}))
        self.watchTable:setColumnWidth(0, 150)
        self.watchTable:setColumnWidth(1, 150)
        self.watchTable:setSelectionBehavior('rows')

        self.mainLayout:addChild(self.watchTable)
    end

    function addWatch()
        local expression = self.addWatchInput:getText()
        if not expression or expression == "" then
            return
        end

        -- Check if already watching this expression
        for _, watch in ipairs(self.watches) do
            if watch.expression == expression then
                return
            end
        end

        -- Add to watches list
        local watch = {
            expression = expression,
            value = "...",
            error = nil
        }
        table.insert(self.watches, watch)

        -- Add to table
        local row = self.watchTable:getRowCount()
        self.watchTable:addRow()
        self.watchTable:setItemText(row, 0, expression)
        self.watchTable:setItemText(row, 1, "...")

        -- Clear input
        self.addWatchInput:clear()

        -- Notify
        if self.onWatchAdded then
            self.onWatchAdded(expression)
        end

        -- Evaluate immediately if project is running
        if AppState.projectIsRunning then
            evaluateWatch(#self.watches)
        end
    end

    function removeSelectedWatch()
        local row = self.watchTable:getCurrentRow()
        if row < 0 then return end

        local expression = self.watches[row + 1].expression
        table.remove(self.watches, row + 1)
        self.watchTable:removeRow(row)

        if self.onWatchRemoved then
            self.onWatchRemoved(expression)
        end
    end

    function evaluateWatch(index)
        local watch = self.watches[index]
        if not watch then return end

        if self.onEvaluate then
            self.onEvaluate(watch.expression, function(result, error)
                if error then
                    watch.value = "<error>"
                    watch.error = error
                    self.watchTable:setItemText(index - 1, 1, '<error>')
                else
                    watch.value = tostring(result)
                    watch.error = nil
                    self.watchTable:setItemText(index - 1, 1, tostring(result))
                end
            end)
        end
    end

    function refreshAllWatches()
        for i = 1, #self.watches do
            evaluateWatch(i)
        end
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        createHeader()
        createAddWatchRow()
        createWatchTable()
    end

    initComponents()

    return {
        view = self.view,

        addWatch = function(expression)
            self.addWatchInput:setText(expression)
            addWatch()
        end,

        removeWatch = function(expression)
            for i, watch in ipairs(self.watches) do
                if watch.expression == expression then
                    table.remove(self.watches, i)
                    self.watchTable:removeRow(i - 1)
                    break
                end
            end
        end,

        updateWatch = function(expression, value, error)
            for i, watch in ipairs(self.watches) do
                if watch.expression == expression then
                    watch.value = value
                    watch.error = error
                    if error then
                        self.watchTable:setItemText(i - 1, 1, '<error>')
                    else
                        self.watchTable:setItemText(i - 1, 1, tostring(value))
                    end
                    break
                end
            end
        end,

        refreshAll = function()
            refreshAllWatches()
        end,

        clear = function()
            self.watches = {}
            self.watchTable:clear()
        end,

        getWatches = function()
            return self.watches
        end,

        setProjectRunning = function(running)
            self.refreshButton:setEnabled(running)
        end,

        setOnEvaluate = function(callback)
            self.onEvaluate = callback
        end,

        setOnWatchAdded = function(callback)
            self.onWatchAdded = callback
        end,

        setOnWatchRemoved = function(callback)
            self.onWatchRemoved = callback
        end
    }
end

return WatchPanel
