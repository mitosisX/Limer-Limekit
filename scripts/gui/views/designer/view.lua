-- Designer view
-- Build a window by picking widgets, and turn it into Lua.
--
-- The widgets on the canvas are real Limekit widgets in Limer's own process
-- -- not pictures of them, and not a preview rendered by something else. A
-- ui.DesignSurface is what makes that safe: it takes the whole design out of
-- the mouse's reach, so clicking a button selects it instead of pressing it.
--
-- The model in app/core/design_model.lua is the truth. The canvas is
-- rebuilt from it after every change rather than patched, because a canvas
-- edited in place drifts from the model that is about to generate the file.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local fs  = require("limekit.fs")

local App = require "app.core.app"
local AppState = require "app.core.app_state"
local DesignModel = require "app.core.design_model"

local DesignerView = {}

local self = nil

local function setStatus(text)
    self.status:setText(text)
end

local function selectedNode()
    return self.selected
end

-- BUILDING THE CANVAS -------------------------------------------------------

local function buildNode(node)
    local ui_ = require("limekit.ui")
    local className = node.class:match("%.(.+)$")

    local widget = ui_[className]()
    for name, value in pairs(node.props or {}) do
        pcall(sys.Introspect.setProperty, widget, name, value)
    end

    self.widgetOf[node] = widget
    self.nodeOf[widget] = node

    if DesignModel.isContainer(node) then
        local layoutClass = node.layout:match("%.(.+)$")
        local layout = ui_[layoutClass]()
        for _, child in ipairs(node.children) do
            layout:addChild(buildNode(child))
        end
        widget:setLayout(layout)
    end

    return widget
end

local function rebuild()
    self.widgetOf, self.nodeOf = {}, {}

    local root = buildNode(self.model)
    self.surface:setDesignChild(root)
    -- Every widget built above is new and therefore still interactive; the
    -- surface has to be told before the next click reaches one of them.
    self.surface:refresh()

    -- Selection survives a rebuild because it is held as a model node, not
    -- as a widget -- the widgets it pointed at have just been thrown away.
    local widget = self.selected and self.widgetOf[self.selected]
    self.surface:setSelected(widget)
end

local function refreshOutline()
    self.outline:clear()
    self.outlineNodes = {}

    DesignModel.walk(self.model, function(node, depth)
        local indent = string.rep("    ", depth)
        local label = indent .. node.name .. "   " .. node.class
        if DesignModel.isContainer(node) then
            label = label .. "  [" .. node.layout:match("%.(.+)$") .. "]"
        end
        self.outline:addItem(label)
        self.outlineNodes[#self.outlineNodes + 1] = node
    end)
end

-- PROPERTIES ----------------------------------------------------------------

local function showProperties(node)
    self.filling = true
    self.props:clear()
    self.props:setColumnCount(3)
    self.props:setColumnHeaders({ "property", "value", "options" })

    local widget = node and self.widgetOf[node]
    if not widget then
        self.props:setRowCount(0)
        self.rows = nil
        self.filling = false
        return
    end

    local rows = sys.Introspect.properties(widget)
    self.rows = rows
    self.props:setRowCount(#rows)

    for index, prop in ipairs(rows) do
        self.props:setCellText(index, 1, prop.name)
        self.props:setCellText(index, 2, tostring(prop.value))
        self.props:setCellText(index, 3,
            prop.options and table.concat(prop.options, " | ") or "")
    end

    self.props:setColumnWidth(1, 140)
    self.props:setColumnWidth(2, 180)
    self.filling = false
end

local function select(node)
    self.selected = node
    self.surface:setSelected(node and self.widgetOf[node])
    showProperties(node)
    setStatus(node and (node.name .. "   " .. node.class) or "nothing selected")
end

local function onPropertyEdited(_, row, column)
    if self.filling or column ~= 2 then return end

    local prop = self.rows and self.rows[row]
    local node = selectedNode()
    if not prop or not node then return end

    if prop.settable ~= true then
        self.props:setCellText(row, 2, tostring(prop.value))
        setStatus(prop.name .. " cannot be set -- it is a " .. prop.type)
        return
    end

    local text = self.props:getCellItem(row, 2):getText()
    local value = text
    if prop.type == "boolean" then
        value = (text == "true")
    elseif prop.type == "int" or prop.type == "float" then
        value = tonumber(text) or text
    end

    -- The model first, because it is what generates the file. The widget
    -- follows so the canvas agrees with it.
    node.props[prop.name] = value

    local ok, result = pcall(sys.Introspect.setProperty, self.widgetOf[node], prop.name, value)
    if not ok then
        node.props[prop.name] = prop.value
        self.props:setCellText(row, 2, tostring(prop.value))
        setStatus("could not set " .. prop.name .. ": " .. tostring(result))
        return
    end

    prop.value = result
    self.filling = true
    self.props:setCellText(row, 2, tostring(result))
    self.filling = false
    refreshOutline()
    setStatus(node.name .. "." .. prop.name .. " = " .. tostring(result))
end

-- ACTIONS -------------------------------------------------------------------

-- Where a new widget goes: inside the selection if it can hold things,
-- otherwise beside it, and failing both at the end of the root.
local function dropTarget()
    local node = selectedNode()
    if DesignModel.isContainer(node) then return node end
    if node then
        local parent = DesignModel.parentOf(self.model, node)
        if parent then return parent end
    end
    return self.model
end

local function addSelectedClass()
    local row = self.palette:getCurrentRow()
    if row == 0 then
        setStatus("pick a widget from the list first")
        return
    end

    local className = "ui." .. self.palette:getItemAt(row)
    local node = DesignModel.node(className)
    DesignModel.add(dropTarget(), node)

    rebuild()
    refreshOutline()
    select(node)
    setStatus("added " .. node.name)
end

local function addContainer(layout)
    local node = DesignModel.container(layout)
    DesignModel.add(dropTarget(), node)
    rebuild()
    refreshOutline()
    select(node)
    setStatus("added " .. node.name .. " (" .. layout:match("%.(.+)$") .. ")")
end

local function deleteSelected()
    local node = selectedNode()
    if not node then return end
    if node == self.model then
        setStatus("the root cannot be deleted -- use New")
        return
    end

    DesignModel.remove(self.model, node)
    self.selected = nil
    rebuild()
    refreshOutline()
    select(nil)
    setStatus("deleted")
end

local function moveSelected(delta)
    local node = selectedNode()
    if not node then return end

    if not DesignModel.move(self.model, node, delta) then
        setStatus("already at the " .. (delta < 0 and "top" or "bottom"))
        return
    end

    rebuild()
    refreshOutline()
    select(node)
end

local function newDesign()
    self.model = DesignModel.blank()
    self.selected = nil
    rebuild()
    refreshOutline()
    select(self.model)
    setStatus("new design")
end

--- Writes the design out as Lua. Returns the path, or nil and a reason.
function DesignerView.generate()
    local source = DesignModel.generate(self.model, self.titleField:getText())

    if AppState.activeProjectPath == nil then
        return nil, "open a project first -- there is nowhere to write it"
    end

    local folder = fs.FileSystem.joinPaths(AppState.activeProjectPath, "scripts")
    local path = fs.FileSystem.joinPaths(folder, "designed.lua")

    local ok, err = pcall(fs.FileSystem.writeFile, path, source)
    if not ok then return nil, tostring(err) end
    return path
end

local function onGenerate()
    local path, reason = DesignerView.generate()
    if not path then
        setStatus(reason)
        App.console.warn("Designer: " .. reason)
        return
    end

    App.console.log("Designer wrote " .. path)
    setStatus("wrote " .. path)

    -- Nothing overwrites main.lua. A generated file that quietly replaced
    -- the file someone had been writing would be unforgivable, and this is
    -- one way only -- the designer cannot read it back.
    ui.Dialogs.alert(App.window, "Generated",
        "Written to scripts/designed.lua.\n\n" ..
        "Point your main.lua at it, or copy what you need. The designer " ..
        "does not read this file back, so edits you make there are yours.")
end

-- BUILDING THE VIEW ---------------------------------------------------------

local function buildPalette()
    local list = ui.ListBox()
    -- Straight from the framework: every class that can be built with no
    -- arguments. Three cannot, and offering them would put items in the
    -- palette that fail the moment they are used.
    list:addItems(sys.Introspect.buildableClasses())
    list:setMinWidth(150)
    list:setOnItemDoubleClick(function() addSelectedClass() end)
    return list
end

local function buildToolbar()
    local row = ui.HLayout()

    local function button(text, tip, handler)
        local widget = ui.Button(text)
        widget:setToolTip(tip)
        widget:setResizeRule('fixed', 'fixed')
        widget:setOnClick(handler)
        row:addChild(widget)
        return widget
    end

    button('New', 'Start again', newDesign)
    button('Add', 'Add the widget selected in the list', addSelectedClass)
    button('Row', 'Add a container that lays its children out in a row',
        function() addContainer("ui.HLayout") end)
    button('Column', 'Add a container that lays its children out in a column',
        function() addContainer("ui.VLayout") end)
    button('Delete', 'Remove the selected widget', deleteSelected)
    button('Up', 'Move the selection earlier among its siblings',
        function() moveSelected(-1) end)
    button('Down', 'Move the selection later among its siblings',
        function() moveSelected(1) end)

    row:addChild(ui.Label('Window title'))
    self.titleField = ui.LineEdit('My App')
    self.titleField:setMaxWidth(160)
    row:addChild(self.titleField)

    button('Generate', 'Write this design out as Lua', onGenerate)
    row:addStretch()
    return row
end

function DesignerView.create()
    self = {
        view = ui.Container(),
        surface = ui.DesignSurface(),
        props = ui.Table(),
        outline = ui.ListBox(),
        status = ui.Label(''),
        model = nil,
        selected = nil,
        widgetOf = {},
        nodeOf = {},
        outlineNodes = {},
        rows = nil,
        filling = false,
    }

    self.palette = buildPalette()

    self.props:setColumnCount(3)
    self.props:setColumnHeaders({ 'property', 'value', 'options' })
    self.props:setCellsEditable(true)
    self.props:setOnCellChange(onPropertyEdited)

    self.outline:setMinWidth(220)
    self.outline:setOnItemSelect(function(_, _, row)
        local node = self.outlineNodes[row]
        if node then select(node) end
    end)

    self.surface:setOnSelect(function(widget)
        select(widget and self.nodeOf[widget] or nil)
    end)

    local splitter = ui.Splitter('horizontal')
    splitter:addChild(self.palette)
    splitter:addChild(self.surface)
    splitter:addChild(self.outline)
    splitter:addChild(self.props)

    local layout = ui.VLayout()
    layout:addLayout(buildToolbar())
    layout:addChild(splitter)
    layout:addChild(self.status)
    self.view:setLayout(layout)

    newDesign()

    return {
        view = self.view,
        getModel = function() return self.model end,
        getSurface = function() return self.surface end,
        getPalette = function() return self.palette end,
        getOutline = function() return self.outline end,
        getProps = function() return self.props end,
        getStatus = function() return self.status:getText() end,
        getSelected = function() return self.selected end,
        widgetFor = function(node) return self.widgetOf[node] end,

        --- Selects by model node, as a click on the canvas would.
        selectNode = function(node) select(node) end,

        addClass = function(className)
            local node = DesignModel.node(className)
            DesignModel.add(dropTarget(), node)
            rebuild(); refreshOutline(); select(node)
            return node
        end,

        addRow = function() addContainer("ui.HLayout") end,
        deleteSelected = deleteSelected,
        moveSelected = moveSelected,
        newDesign = newDesign,
        generate = DesignerView.generate,
    }
end

return DesignerView
