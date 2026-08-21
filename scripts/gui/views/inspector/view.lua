-- Inspector view
-- The widget tree of the running project, its properties, and Lua run
-- inside it.
--
-- This was the Code Injection tab: a text box that wrote to a file the
-- engine never read. Two things were wrong with it and only one was the
-- plumbing. The other is that an injected chunk cannot see anything the
-- project declared `local`, which in a normal main.lua is everything --
-- there was no name to reach for even if the code had run.
--
-- So the tree comes first here and the code box second. You pick the widget;
-- the path is how it is addressed, and Lua's scoping stops mattering.

local ui  = require("limekit.ui")

local App = require "app.core.app"
local Inspector = require "app.core.inspector"

local InspectorView = {}

local self = nil

-- path -> tree item, so a reply about "1.2.3" can find its row again
-- without walking. Rebuilt on every refresh, because the paths are only
-- meaningful for the tree they came from.
local itemPaths = {}

local function setStatus(text)
    self.status:setText(text)
end

local function addNode(node, parent)
    local text = node["class"]
    if node.label ~= "" then
        text = text .. "   " .. node.label
    end

    local item = ui.TreeViewItem(text)
    item:setEditable(false)
    item:setText(2, node.path)

    if parent then
        parent:addChild(item)
    else
        self.tree:addTopItem(item)
    end

    itemPaths[node.path] = item

    for _, child in ipairs(node.children or {}) do
        addNode(child, item)
    end
end

local function showProperties(payload)
    -- Rebuilt wholesale rather than patched: a reply describes the widget as
    -- it was when asked, and reconciling that against edits made since would
    -- be guessing.
    self.filling = true
    self.props:clear()
    self.props:setColumnCount(3)
    self.props:setColumnHeaders({ "property", "value", "options" })

    local rows = payload.props or {}
    self.props:setRowCount(#rows)
    self.rows = rows

    for index, prop in ipairs(rows) do
        self.props:setCellText(index, 1, prop.name)
        self.props:setCellText(index, 2, tostring(prop.value))
        self.props:setCellText(index, 3,
            prop.options and table.concat(prop.options, " | ") or "")
    end

    self.props:setColumnWidth(1, 150)
    self.props:setColumnWidth(2, 220)
    self.filling = false

    setStatus(string.format("%s   %s   %d properties",
        payload["class"], payload.path, #rows))
end

local function onCellChanged(_, row, column)
    -- Fires while the table is being filled as well as when a person types
    -- in it, and sending the value back to the project during a refresh
    -- would write it straight back over itself.
    if self.filling or column ~= 2 then return end

    local prop = self.rows and self.rows[row]
    if not prop then return end

    if prop.settable ~= true then
        self.props:setCellText(row, 2, tostring(prop.value))
        setStatus(prop.name .. " cannot be set from here -- it is a " .. prop.type)
        return
    end

    local text = self.props:getCellItem(row, 2):getText()
    local value = text
    if prop.type == "boolean" then
        value = (text == "true")
    elseif prop.type == "number" or prop.type == "int" or prop.type == "float" then
        value = tonumber(text) or text
    end

    Inspector.ask("set", { path = self.selectedPath, prop = prop.name, value = value },
        function(ok, result)
            if not ok then
                self.props:setCellText(row, 2, tostring(prop.value))
                setStatus("could not set " .. prop.name .. ": " .. tostring(result))
                return
            end
            prop.value = result.value
            self.filling = true
            self.props:setCellText(row, 2, tostring(result.value))
            self.filling = false
            setStatus(prop.name .. " = " .. tostring(result.value))
        end)
end

local function refreshTree()
    Inspector.ask("tree", nil, function(ok, result)
        self.tree:clear()
        itemPaths = {}

        if not ok then
            setStatus("could not read the tree: " .. tostring(result))
            return
        end

        local count = 0
        for _, node in ipairs(result) do
            addNode(node, nil)
            count = count + 1
        end

        self.tree:expandAll()
        setStatus(count == 0 and "nothing on screen yet"
                             or ("tree read -- pick a widget"))
    end)
end

local function onWidgetPicked(_, item)
    local path = item:getText(2)
    if path == "" then return end

    self.selectedPath = path
    Inspector.ask("props", { path = path }, function(ok, result)
        if not ok then
            setStatus("could not read " .. path .. ": " .. tostring(result))
            return
        end
        showProperties(result)
    end)
end

local function runCode()
    local code = self.codeField:getText()
    if code == "" then
        setStatus("nothing to run")
        return
    end

    Inspector.ask("eval", { code = code }, function(ok, result)
        if ok then
            App.console.log("injected: " .. code)
            if result ~= "" then App.console.log("  = " .. tostring(result)) end
            setStatus("ran")
            -- Anything might have changed, including what exists.
            refreshTree()
        else
            App.console.error("injection failed: " .. tostring(result))
            setStatus("failed -- see the console")
        end
    end)
end

local function setEnabled(connected)
    self.refreshButton:setEnabled(connected)
    self.runButton:setEnabled(connected and self.codeField:getText() ~= "")
    self.codeField:setEnabled(connected)
end

function InspectorView.create()
    self = {
        view = ui.Container(),
        tree = ui.TreeView(),
        props = ui.Table(),
        codeField = ui.TextField(),
        refreshButton = ui.Button('Refresh'),
        runButton = ui.Button('Run'),
        status = ui.Label('start a project to inspect it'),
        rows = nil,
        selectedPath = nil,
        filling = false,
    }

    self.tree:setColumnCount(2)
    self.tree:setHeaderLabels({ 'widget', 'path' })
    self.tree:setColumnWidth(1, 260)
    self.tree:setOnItemClick(onWidgetPicked)

    self.props:setColumnCount(3)
    self.props:setColumnHeaders({ 'property', 'value', 'options' })
    self.props:setCellsEditable(true)
    self.props:setOnCellChange(onCellChanged)

    self.codeField:setHint('Lua to run inside the project...')
    self.codeField:setMaxHeight(90)
    self.codeField:setOnTextChange(function(_, text)
        self.runButton:setEnabled(Inspector.isConnected() and text ~= "")
    end)

    self.refreshButton:setResizeRule('fixed', 'fixed')
    self.refreshButton:setOnClick(refreshTree)

    self.runButton:setResizeRule('fixed', 'fixed')
    self.runButton:setOnClick(runCode)

    -- Tree beside properties, code underneath: you find the widget, then you
    -- act on it, and the code box is the fallback for what the property
    -- table cannot express.
    local splitter = ui.Splitter('horizontal')
    splitter:addChild(self.tree)
    splitter:addChild(self.props)

    local buttons = ui.HLayout()
    buttons:addChild(self.refreshButton)
    buttons:addChild(self.runButton)
    buttons:addChild(self.status)
    buttons:addStretch()

    local layout = ui.VLayout()
    layout:addChild(splitter)
    layout:addLayout(buttons)
    layout:addChild(self.codeField)
    self.view:setLayout(layout)

    setEnabled(false)

    local api = {
        view = self.view,

        getView = function() return self.view end,

        onConnected = function()
            setEnabled(true)
            setStatus('connected -- reading the tree')
            refreshTree()
        end,

        onDisconnected = function()
            setEnabled(false)
            self.tree:clear()
            self.props:clear()
            self.rows, self.selectedPath = nil, nil
            setStatus('the project has stopped')
        end,
    }

    Inspector.setView(api)
    return api
end

return InspectorView
