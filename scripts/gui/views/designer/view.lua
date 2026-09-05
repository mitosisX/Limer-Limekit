-- Designer view
-- Drag widgets from a palette onto real Limekit widgets, arrange them in
-- layouts, edit their properties, save the design, and write it out as a
-- Lua module.
--
-- The widgets on the canvas are real Limekit widgets in Limer's own process
-- -- not pictures of them, and not a preview rendered by something else. A
-- ui.DesignSurface is what makes that safe: it takes the whole design out of
-- the mouse's reach, so clicking a button selects it instead of pressing it,
-- and it reports where a drop lands without doing anything about it.
--
-- The model in app/core/design_model.lua is the truth. Every change goes
-- through `mutate`: a snapshot is taken, the change applied to the copy, and
-- if the model accepts it the copy becomes the design, goes on the undo
-- stack, and everything on screen is rebuilt from it.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")

local App = require "app.core.app"
local AppState = require "app.core.app_state"
local DesignModel = require "app.core.design_model"
local Canvas = require "gui.views.designer.canvas"
local Outline = require "gui.views.designer.outline"
local Properties = require "gui.views.designer.properties"
local Preview = require "gui.views.designer.preview"
local Files = require "gui.views.designer.files"

local DesignerView = {}

local S = nil   -- the one designer's state

-- HELPERS -------------------------------------------------------------------

local function setStatus(text)
    S.status:setText(text or "")
end

local function log(text)
    if App.console and App.console.log then App.console.log("Designer: " .. text) end
end

local function warn(text)
    setStatus(text)
    if App.console and App.console.warn then App.console.warn("Designer: " .. text) end
end

local function project()
    return AppState.activeProjectPath
end

local function short(class)
    return class:match("%.(.+)$") or class
end

-- Selection is a node in the *current* design. After a snapshot the same
-- node has to be found again in the copy, and the only stable identity a
-- node has across copies is its path from the root.
local function pathOf(design, node)
    local found = nil
    local function find(n, trail)
        if n == node then found = trail; return true end
        for i, child in ipairs(n.children or {}) do
            local t = { table.unpack(trail) }
            t[#t + 1] = i
            if find(child, t) then return true end
        end
        return false
    end
    if node then find(design.root, {}) end
    return found
end

local function nodeAt(design, path)
    if not path then return nil end
    local n = design.root
    for _, i in ipairs(path) do
        n = n and n.children and n.children[i]
    end
    return n
end

-- REFRESH -------------------------------------------------------------------

local function updateTitle()
    S.tabTitle(S.name .. (S.dirty and " *" or ""))
end

local function refreshAll()
    S.canvas:rebuild(S.design)
    S.canvas:select(S.selected)
    S.outline:refresh(S.design)
    S.props:show(S.selected, S.canvas:widgetFor(S.selected))
    S.preview:refresh(S.design, S.name)

    S.filling = true
    S.titleField:setText(S.design.window.title)
    S.widthField:setText(tostring(S.design.window.width))
    S.heightField:setText(tostring(S.design.window.height))
    S.filling = false

    S.undoButton:setEnabled(S.undo:canUndo())
    S.redoButton:setEnabled(S.undo:canRedo())
    updateTitle()
end

local function select(node)
    S.selected = node
    S.canvas:select(node)
    S.props:show(node, S.canvas:widgetFor(node))
    if node == nil then
        setStatus("nothing selected")
    elseif node.kind then
        setStatus(node.kind)
    else
        setStatus(node.name .. "   " .. node.class)
    end
end

--- Applies fn(draft, selectedInDraft) to a snapshot. fn returns
--- ok, reason, selectPath. On ok the draft becomes the design.
local function mutate(fn, status)
    local path = pathOf(S.design, S.selected)
    local draft = DesignModel.snapshot(S.design)
    local ok, why, selectPath = fn(draft, nodeAt(draft, path))
    if not ok then
        setStatus(why or "no change")
        return false
    end
    S.design = draft
    S.selected = nodeAt(draft, selectPath or path)
    S.undo:push(draft)
    S.dirty = true
    refreshAll()
    if status then setStatus(status) end
    return true
end

-- Undo and redo swap the whole design; the selection follows by path.
local function restore(design, status)
    if not design then setStatus("nothing to " .. status); return end
    local path = pathOf(S.design, S.selected)
    S.design = design
    S.selected = nodeAt(design, path)
    S.dirty = true
    refreshAll()
    setStatus(status)
end

-- EDITS ---------------------------------------------------------------------

local function onDrop(drop)
    local targetPath = pathOf(S.design, drop.target)
    if drop.kind == "class" then
        mutate(function(d)
            local node = DesignModel.node(drop.class)
            local ok, why = DesignModel.insert(d, nodeAt(d, targetPath), node, drop.slot)
            if not ok then return false, why end
            return true, nil, pathOf(d, node)
        end, "added " .. short(drop.class))
    else
        local nodePath = pathOf(S.design, drop.node)
        mutate(function(d)
            local node = nodeAt(d, nodePath)
            local ok, why = DesignModel.move(d, node, nodeAt(d, targetPath), drop.slot)
            if not ok then return false, why end
            return true, nil, pathOf(d, node)
        end, "moved")
    end
end

-- Where a widget added without a drop goes: inside the selection if it
-- can hold things, otherwise beside it, and failing both at the end of
-- the root.
local function addClass(class)
    mutate(function(d, selected)
        local node = DesignModel.node(class)
        local parent, slot
        if DesignModel.isContainer(selected) then
            parent, slot = selected, {}
        elseif selected then
            parent = DesignModel.parentOf(d, selected)
            slot = { index = DesignModel.indexOf(parent, selected) + 1 }
        else
            parent, slot = d.root, {}
        end
        if DesignModel.layoutKind(parent.layout) == "grid" then
            -- Next free row in the first column.
            local rows = 0
            for _, c in ipairs(parent.children) do
                if c.grid and c.grid.row > rows then rows = c.grid.row end
            end
            slot = { row = rows + 1, column = 1 }
        end
        local ok, why = DesignModel.insert(d, parent, node, slot)
        if not ok then return false, why end
        return true, nil, pathOf(d, node)
    end, "added " .. short(class))
end

local function addPseudo(make, what)
    mutate(function(d, selected)
        local parent, slot
        if DesignModel.isContainer(selected) then
            parent, slot = selected, {}
        elseif selected then
            parent = DesignModel.parentOf(d, selected)
            slot = { index = DesignModel.indexOf(parent, selected) + 1 }
        else
            parent, slot = d.root, {}
        end
        local node = make()
        local ok, why = DesignModel.insert(d, parent, node, slot)
        if not ok then return false, why end
        return true, nil, pathOf(d, node)
    end, "added " .. what)
end

local function deleteSelected()
    if not S.selected then setStatus("nothing selected"); return end
    mutate(function(d, selected)
        if not selected then return false, "nothing selected" end
        local parent = DesignModel.parentOf(d, selected)
        local ok, why = DesignModel.remove(d, selected)
        if not ok then return false, why end
        return true, nil, pathOf(d, parent)
    end, "deleted")
end

local function moveSelected(delta)
    if not S.selected then return end
    mutate(function(d, selected)
        if not selected then return false, "nothing selected" end
        local parent = DesignModel.parentOf(d, selected)
        if not parent then return false, "the root stays put" end
        if DesignModel.layoutKind(parent.layout) == "grid" then
            return false, "in a grid, edit row and column instead"
        end
        local index = DesignModel.indexOf(parent, selected)
        local wanted = index + delta
        if wanted < 1 or wanted > #parent.children then
            return false, "already at the " .. (delta < 0 and "start" or "end")
        end
        -- A slot is "before item N" measured with the node still in place.
        local slot = { index = delta < 0 and wanted or wanted + 1 }
        local ok, why = DesignModel.move(d, selected, parent, slot)
        if not ok then return false, why end
        return true, nil, pathOf(d, selected)
    end, delta < 0 and "moved up" or "moved down")
end

local function wrapSelected(layout)
    if not S.selected then setStatus("select a widget to wrap"); return end
    mutate(function(d, selected)
        if not selected then return false, "nothing selected" end
        local box, why = DesignModel.wrap(d, selected, layout)
        if not box then return false, why end
        return true, nil, pathOf(d, box)
    end, "wrapped in a " .. (layout == "ui.HLayout" and "row" or "column"))
end

local function unwrapSelected()
    if not S.selected then return end
    mutate(function(d, selected)
        if not selected then return false, "nothing selected" end
        local child = selected.children and selected.children[1]
        local ok, why = DesignModel.unwrap(d, selected)
        if not ok then return false, why end
        return true, nil, pathOf(d, child)
    end, "unwrapped")
end

local function changeLayout(layout)
    if not S.selected then return end
    mutate(function(d, selected)
        if not DesignModel.isContainer(selected) then return false, "not a container" end
        return DesignModel.setLayout(d, selected, layout)
    end, "layout: " .. short(layout))
end

local function applyWindowFields()
    if S.filling then return end
    local title = S.titleField:getText()
    local width = math.tointeger(tonumber(S.widthField:getText()))
    local height = math.tointeger(tonumber(S.heightField:getText()))
    local w = S.design.window
    if title == w.title and width == w.width and height == w.height then return end
    if not width or not height or width < 1 or height < 1 then
        setStatus("width and height must be whole numbers")
        return
    end
    mutate(function(d)
        d.window.title, d.window.width, d.window.height = title, width, height
        return true
    end, "window: " .. title .. " " .. width .. "x" .. height)
end

-- Property panel callbacks. Each edits a snapshot by path, like every
-- other change.
local callbacks = {}

function callbacks.onProp(node, name, value)
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        -- The live widget is asked first: it coerces, validates, and reads
        -- back what it actually holds, which is what the model records.
        local widget = S.canvas:widgetFor(node)
        local ok, result = pcall(sys.Introspect.setProperty, widget, name, value)
        if not ok then return false, "could not set " .. name .. ": " .. tostring(result) end
        n.props[name] = result
        return true
    end, node.name .. "." .. name .. " = " .. tostring(value))
end

function callbacks.onRename(node, name)
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        -- A form label that was only ever the default name follows it.
        local ok, why = DesignModel.rename(d, n, name)
        if not ok then return false, why end
        return true
    end, "renamed to " .. tostring(name))
end

function callbacks.onPlacement(node, field, value)
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        local group, key = field:match("^(%w+)%.(%w+)$")
        if group == "grid" and (key == "row" or key == "column") then
            if value < 1 then return false, "rows and columns count from 1" end
            local parent = DesignModel.parentOf(d, n)
            local slot = { row = n.grid.row, column = n.grid.column }
            slot[key] = value
            local ok, why = DesignModel.move(d, n, parent, slot)
            if not ok then return false, why end
            return true, nil, pathOf(d, n)
        elseif group then
            if group == "grid" and value < 1 then return false, "spans start at 1" end
            n[group][key] = value
        else
            if (field == "stretch" or field == "size") and value < 0 then
                return false, field .. " cannot be negative"
            end
            n[field] = value
        end
        return true
    end, field .. " = " .. tostring(value))
end

function callbacks.onLayout(node, layout)
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        return DesignModel.setLayout(d, n, layout)
    end, "layout: " .. short(layout))
end

-- FILES ---------------------------------------------------------------------

local function loadDesign(design, name)
    S.design = design
    S.name = name
    S.selected = design.root
    S.dirty = false
    S.undo:reset(design)
    refreshAll()
end

local function newDesign()
    loadDesign(DesignModel.blank(), "main")
    setStatus("new design")
end

--- True if it is fine to throw the current design away.
local function confirmDiscard()
    if not S.dirty then return true end
    return ui.Dialogs.question(App.window, "Unsaved design",
        "The design '" .. S.name .. "' has unsaved changes. Discard them?") == true
end

local function refreshPicker()
    S.filling = true
    S.picker:clear()
    local names = Files.list(project())
    S.pickerNames = names
    S.picker:addItem("(designs)")
    for _, name in ipairs(names) do S.picker:addItem(name) end
    S.picker:setCurrentIndex(1)
    for i, name in ipairs(names) do
        if name == S.name then S.picker:setCurrentIndex(i + 1) end
    end
    S.filling = false
end

local function openDesign(name)
    if not project() then warn("open a project first"); return end
    if not confirmDiscard() then refreshPicker(); return end
    local design, why = Files.load(project(), name)
    if not design then
        warn("could not open " .. name .. ": " .. tostring(why))
        refreshPicker()
        return
    end
    loadDesign(design, name)
    refreshPicker()
    setStatus("opened design/" .. name .. ".design.lua")
end

local function saveAs(name)
    if not project() then warn("open a project first -- there is nowhere to save"); return false end
    applyWindowFields()
    local ok, why = Files.save(project(), name, S.design)
    if not ok then warn("could not save: " .. tostring(why)); return false end
    S.name = name
    S.dirty = false
    refreshPicker()
    refreshAll()
    setStatus("saved design/" .. name .. ".design.lua")
    log("saved " .. Files.designPath(project(), name))
    return true
end

local function askName()
    local name = ui.Dialogs.textInput(App.window, "Save design as",
        "Name (becomes scripts/designed/<name>.lua):", S.name)
    if name == nil or name == "" then return nil end
    if not Files.validName(name) then
        warn("a design name must be a Lua identifier: letters, digits, underscores")
        return nil
    end
    return name
end

local function save()
    if not project() then warn("open a project first -- there is nowhere to save"); return end
    local existing = false
    for _, n in ipairs(Files.list(project())) do if n == S.name then existing = true end end
    if existing then
        saveAs(S.name)
    else
        local name = askName()
        if name then saveAs(name) end
    end
end

local function saveAsPrompt()
    local name = askName()
    if name then saveAs(name) end
end

local function generate()
    if not project() then warn("open a project first -- there is nowhere to write"); return end
    applyWindowFields()
    local source = DesignModel.generate(S.design, S.name)
    local path, why = Files.writeGenerated(project(), S.name, source)
    if not path then warn("could not write: " .. tostring(why)); return end
    log("wrote " .. path)
    setStatus("wrote " .. path)

    -- Nothing overwrites main.lua. A generated file that quietly replaced
    -- the file someone had been writing would be unforgivable, and this is
    -- one way only -- the designer cannot read it back.
    ui.Dialogs.info(App.window, "Generated",
        "Written to scripts/designed/" .. S.name .. ".lua.\n\n" ..
        "In main.lua:\n\n" ..
        "    local " .. S.name .. " = require(\"designed." .. S.name .. "\")\n" ..
        "    " .. S.name .. ".window:show()\n\n" ..
        "Every widget is there by name, so handlers go on in main.lua:\n\n" ..
        "    " .. S.name .. ".button1:setOnClick(function() ... end)\n\n" ..
        "The designer never reads this file back; regenerate rather than edit it.")
end

local function onProjectOpened()
    if S.dirty and not confirmDiscard() then return end
    local names = Files.list(project())
    if #names > 0 then
        local design = Files.load(project(), names[1])
        if design then loadDesign(design, names[1]) else newDesign() end
    else
        newDesign()
    end
    refreshPicker()
end

-- MENUS ---------------------------------------------------------------------

local function item(menu, label, handler, enabled)
    local entry = ui.MenuItem(label)
    entry:setOnClick(handler)
    if enabled == false then entry:setEnabled(false) end
    menu:addMenuItem(entry)
    return entry
end

local function buildContextMenu()
    local node = S.selected
    local menu = ui.Menu("")
    local isWidget = node and not node.kind
    local isBox = node and DesignModel.isContainer(node)
    local isRoot = node == S.design.root

    item(menu, "Wrap in a row", function() wrapSelected("ui.HLayout") end, isWidget and not isRoot)
    item(menu, "Wrap in a column", function() wrapSelected("ui.VLayout") end, isWidget and not isRoot)
    item(menu, "Unwrap", unwrapSelected, isBox and not isRoot and #node.children == 1)
    menu:addSeparator()
    local layouts = ui.Menu("Change layout")
    for _, class in ipairs(DesignModel.LAYOUTS) do
        item(layouts, short(class), function() changeLayout(class) end, isBox)
    end
    menu:addMenu(layouts)
    menu:addSeparator()
    item(menu, "Add stretch", function() addPseudo(DesignModel.stretch, "stretch") end)
    item(menu, "Add spacing", function() addPseudo(function() return DesignModel.spacing(12) end, "spacing") end)
    menu:addSeparator()
    item(menu, "Move up", function() moveSelected(-1) end, node ~= nil and not isRoot)
    item(menu, "Move down", function() moveSelected(1) end, node ~= nil and not isRoot)
    item(menu, "Delete", deleteSelected, node ~= nil and not isRoot)
    return menu
end

-- BUILDING THE VIEW ---------------------------------------------------------

local function button(row, text, tip, handler)
    local widget = ui.Button(text)
    widget:setToolTip(tip)
    widget:setResizeRule("fixed", "fixed")
    widget:setOnClick(handler)
    row:addChild(widget)
    return widget
end

local function separator(row)
    local line = ui.VLine()
    row:addChild(line)
end

local function buildToolbar()
    local row = ui.HLayout()
    button(row, "New", "Start a new design (Ctrl+N)", function()
        if confirmDiscard() then newDesign(); refreshPicker() end
    end)
    button(row, "Save", "Save the design (Ctrl+S)", save)
    button(row, "Save as", "Save under another name (Ctrl+Shift+S)", saveAsPrompt)
    separator(row)
    S.undoButton = button(row, "Undo", "Ctrl+Z", function() restore(S.undo:undo(), "undo") end)
    S.redoButton = button(row, "Redo", "Ctrl+Y", function() restore(S.undo:redo(), "redo") end)
    separator(row)
    button(row, "Wrap: row", "Put the selection inside a new row", function() wrapSelected("ui.HLayout") end)
    button(row, "Wrap: column", "Put the selection inside a new column", function() wrapSelected("ui.VLayout") end)
    button(row, "Delete", "Remove the selection (Delete)", deleteSelected)
    S.moreButton = button(row, "More...", "Wrap, unwrap, change layout, stretch, spacing", function()
        local menu = buildContextMenu()
        menu:popupAt(S.moreButton, 0, 24)
    end)
    separator(row)
    button(row, "Generate", "Write the design out as scripts/designed/<name>.lua (Ctrl+G)", generate)
    row:addStretch()
    return row
end

local function buildDesignRow()
    local row = ui.HLayout()
    row:addChild(ui.Label("Design"))
    S.picker = ui.ComboBox()
    S.picker:setMinWidth(160)
    S.picker:setOnItemSelect(function(_, index)
        if S.filling then return end
        local name = S.pickerNames[index - 1]
        if name and name ~= S.name then openDesign(name) end
    end)
    row:addChild(S.picker)
    row:addSpacing(16)

    row:addChild(ui.Label("Window title"))
    S.titleField = ui.LineEdit("My App")
    S.titleField:setMaxWidth(200)
    S.titleField:setOnReturnPress(applyWindowFields)
    row:addChild(S.titleField)
    row:addChild(ui.Label("Size"))
    S.widthField = ui.LineEdit("640")
    S.widthField:setMaxWidth(60)
    S.widthField:setOnReturnPress(applyWindowFields)
    row:addChild(S.widthField)
    row:addChild(ui.Label("x"))
    S.heightField = ui.LineEdit("480")
    S.heightField:setMaxWidth(60)
    S.heightField:setOnReturnPress(applyWindowFields)
    row:addChild(S.heightField)
    row:addStretch()
    return row
end

-- Shortcuts are scoped to the designer's own widget tree, or Delete in
-- the designer would eat Delete in every text field in the window.
local function installShortcuts()
    local function bind(sequence, handler)
        local shortcut = ui.KeyboardShortcut(S.view, sequence)
        shortcut:setScope("widget")
        shortcut:setOnPress(handler)
        return shortcut
    end
    S.shortcuts = {
        bind("Delete", deleteSelected),
        bind("Ctrl+Z", function() restore(S.undo:undo(), "undo") end),
        bind("Ctrl+Y", function() restore(S.undo:redo(), "redo") end),
        bind("Ctrl+Shift+Z", function() restore(S.undo:redo(), "redo") end),
        bind("Ctrl+S", save),
        bind("Ctrl+Shift+S", saveAsPrompt),
        bind("Ctrl+G", generate),
        bind("Ctrl+N", function() if confirmDiscard() then newDesign(); refreshPicker() end end),
        bind("Ctrl+Up", function() moveSelected(-1) end),
        bind("Ctrl+Down", function() moveSelected(1) end),
    }
end

function DesignerView.create()
    S = {
        undo = DesignModel.Undo.new(),
        dirty = false,
        name = "main",
        filling = false,
        pickerNames = {},
        tabTitle = function() end,
        status = ui.Label(""),
    }

    S.palette = ui.WidgetPalette()
    S.palette:setMinWidth(170)
    S.palette:setMaxWidth(260)
    S.palette:setOnPick(addClass)

    S.surface = ui.DesignSurface()
    S.surface:setOnContextMenu(function(widget, x, y)
        -- The surface has already selected `widget`; the view's selection
        -- follows through onSelect. Build the menu for that selection.
        local menu = buildContextMenu()
        menu:popupAt(S.surface, x, y)
    end)
    local scroller = ui.Scroller()
    scroller:setChild(S.surface)
    scroller:setResizable(true)
    S.canvas = Canvas.new(S.surface, onDrop, select)

    local tree = ui.TreeView()
    S.outline = Outline.new(tree, select)
    local table_ = ui.Table()
    S.props = Properties.new(table_, callbacks)
    local code = ui.TextField()
    S.preview = Preview.new(code)

    local side = ui.Tab()
    side:addTab(tree, "Outline")
    side:addTab(table_, "Properties")
    side:addTab(code, "Code")
    side:setMinWidth(320)

    local split = ui.Splitter("horizontal")
    split:addChild(S.palette)
    split:addChild(scroller)
    split:addChild(side)
    split:setSizes({ 18, 52, 30 })

    local layout = ui.VLayout()
    layout:addLayout(buildToolbar())
    layout:addLayout(buildDesignRow())
    layout:addChild(split, 1)
    layout:addChild(S.status)
    S.view = ui.Container()
    S.view:setLayout(layout)

    installShortcuts()
    newDesign()

    return {
        view = S.view,
        onProjectOpened = onProjectOpened,
        isDirty = function() return S.dirty end,
        setTabTitleSetter = function(fn) S.tabTitle = fn; updateTitle() end,

        -- For scripts and checks.
        getDesign = function() return S.design end,
        getSelected = function() return S.selected end,
        selectNode = select,
        addClass = addClass,
        deleteSelected = deleteSelected,
        moveSelected = moveSelected,
        wrapSelected = wrapSelected,
        undo = function() restore(S.undo:undo(), "undo") end,
        redo = function() restore(S.undo:redo(), "redo") end,
        newDesign = newDesign,
        generate = generate,
        getStatus = function() return S.status:getText() end,
    }
end

return DesignerView
