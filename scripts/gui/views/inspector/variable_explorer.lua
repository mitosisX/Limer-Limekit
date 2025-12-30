-- VariableExplorer Module
-- Displays variables from the running application in a tree structure

local AppState = require "app.core.app_state"

local VariableExplorer = {}

-- Variable types for icons/styling
VariableExplorer.VAR_TYPE = {
    TABLE = "table",
    FUNCTION = "function",
    STRING = "string",
    NUMBER = "number",
    BOOLEAN = "boolean",
    NIL = "nil",
    USERDATA = "userdata",
    WIDGET = "widget"
}

function VariableExplorer.create(options)
    options = options or {}

    local self = {
        view = Container(),
        mainLayout = VLayout(),
        headerLayout = HLayout(),
        filterInput = LineEdit(),
        variableTree = TreeWidget(),
        refreshButton = Button(),
        variables = {},
        onVariableSelected = options.onVariableSelected,
        onRefresh = options.onRefresh
    }

    local function getTypeIcon(varType)
        -- Use existing icons from the project
        local icons = {
            [VariableExplorer.VAR_TYPE.TABLE] = images('widgets/Table.png'),
            [VariableExplorer.VAR_TYPE.FUNCTION] = images('py.png'),
            [VariableExplorer.VAR_TYPE.STRING] = images('widgets/Label.png'),
            [VariableExplorer.VAR_TYPE.NUMBER] = images('widgets/Spinner.png'),
            [VariableExplorer.VAR_TYPE.BOOLEAN] = images('widgets/CheckBox.png'),
            [VariableExplorer.VAR_TYPE.WIDGET] = images('widgets/Widget.png'),
            [VariableExplorer.VAR_TYPE.USERDATA] = images('widgets/Widget.png')
        }
        return icons[varType] or images('widgets/Widget.png')
    end

    local function formatValue(value, varType)
        if varType == VariableExplorer.VAR_TYPE.STRING then
            local truncated = string.sub(tostring(value), 1, 50)
            if string.len(tostring(value)) > 50 then
                truncated = truncated .. "..."
            end
            return string.format('"%s"', truncated)
        elseif varType == VariableExplorer.VAR_TYPE.TABLE then
            return "{...}"
        elseif varType == VariableExplorer.VAR_TYPE.FUNCTION then
            return "function()"
        elseif varType == VariableExplorer.VAR_TYPE.NIL then
            return "nil"
        elseif varType == VariableExplorer.VAR_TYPE.USERDATA then
            return "<userdata>"
        elseif varType == VariableExplorer.VAR_TYPE.WIDGET then
            return "<widget>"
        else
            return tostring(value)
        end
    end

    local function createHeader()
        self.headerLayout:setContentAlignment('left', 'vcenter')
        self.headerLayout:setMargins(0, 0, 0, 3)

        local titleLabel = Label('<strong>Variables</strong>')
        titleLabel:setResizeRule('fixed', 'fixed')

        -- Refresh button
        self.refreshButton:setText('')
        self.refreshButton:setIcon(images('arrow_refresh_small.png'))
        self.refreshButton:setToolTip('Refresh variables')
        self.refreshButton:setResizeRule('fixed', 'fixed')
        self.refreshButton:setEnabled(false)
        self.refreshButton:setOnClick(function()
            if self.onRefresh then
                self.onRefresh()
            end
        end)

        self.headerLayout:addChild(titleLabel)
        self.headerLayout:addStretch()
        self.headerLayout:addChild(self.refreshButton)

        self.mainLayout:addLayout(self.headerLayout)
    end

    local function createFilter()
        self.filterInput:setHint('Filter variables...')
        self.filterInput:setMaxHeight(25)
        self.filterInput:setOnTextChange(function(sender, text)
            filterVariables(text)
        end)

        self.mainLayout:addChild(self.filterInput)
    end

    local function createTree()
        self.variableTree:setHeaderLabels(lua_table({'Name', 'Value', 'Type'}))
        self.variableTree:setColumnWidth(0, 150)
        self.variableTree:setColumnWidth(1, 150)
        self.variableTree:setColumnWidth(2, 80)

        self.variableTree:setOnItemClick(function(item)
            if self.onVariableSelected and item then
                local varPath = item:getText(0)
                self.onVariableSelected(varPath)
            end
        end)

        self.mainLayout:addChild(self.variableTree)
    end

    function filterVariables(filterText)
        -- Simple filter: show/hide items based on name matching
        -- For now, we'll rebuild the tree with filtered data
        if not filterText or filterText == "" then
            rebuildTree(self.variables)
        else
            local filtered = {}
            for name, data in pairs(self.variables) do
                if string.find(string.lower(name), string.lower(filterText)) then
                    filtered[name] = data
                end
            end
            rebuildTree(filtered)
        end
    end

    function rebuildTree(variables)
        self.variableTree:clear()

        -- Create category items
        local globalsItem = TreeItem(lua_table({'_G (globals)', '', 'table'}))
        local widgetsItem = TreeItem(lua_table({'Widgets', '', 'category'}))
        local modulesItem = TreeItem(lua_table({'Modules', '', 'category'}))

        for name, data in pairs(variables) do
            local varType = data.type or VariableExplorer.VAR_TYPE.NIL
            local value = formatValue(data.value, varType)

            local item = TreeItem(lua_table({name, value, varType}))

            -- Categorize
            if data.isWidget then
                widgetsItem:addChild(item)
            elseif data.isModule then
                modulesItem:addChild(item)
            else
                globalsItem:addChild(item)
            end

            -- Add children for tables
            if varType == VariableExplorer.VAR_TYPE.TABLE and data.children then
                for childName, childData in pairs(data.children) do
                    local childType = childData.type or VariableExplorer.VAR_TYPE.NIL
                    local childValue = formatValue(childData.value, childType)
                    local childItem = TreeItem(lua_table({childName, childValue, childType}))
                    item:addChild(childItem)
                end
            end
        end

        -- Add category items to tree
        self.variableTree:addTopItem(globalsItem)
        self.variableTree:addTopItem(widgetsItem)
        self.variableTree:addTopItem(modulesItem)

        -- Expand globals by default
        globalsItem:setExpanded(true)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        createHeader()
        createFilter()
        createTree()
    end

    initComponents()

    return {
        view = self.view,

        setVariables = function(variables)
            self.variables = variables or {}
            rebuildTree(self.variables)
        end,

        addVariable = function(name, value, varType, options)
            options = options or {}
            self.variables[name] = {
                value = value,
                type = varType,
                isWidget = options.isWidget,
                isModule = options.isModule,
                children = options.children
            }
            rebuildTree(self.variables)
        end,

        removeVariable = function(name)
            self.variables[name] = nil
            rebuildTree(self.variables)
        end,

        clear = function()
            self.variables = {}
            self.variableTree:clear()
        end,

        refresh = function()
            if self.onRefresh then
                self.onRefresh()
            end
        end,

        setProjectRunning = function(running)
            self.refreshButton:setEnabled(running)
        end,

        setOnVariableSelected = function(callback)
            self.onVariableSelected = callback
        end,

        setOnRefresh = function(callback)
            self.onRefresh = callback
        end,

        getSelectedVariable = function()
            local item = self.variableTree:getCurrentItem()
            if item then
                return item:getText(0)
            end
            return nil
        end
    }
end

return VariableExplorer
