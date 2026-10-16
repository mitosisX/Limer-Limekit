-- Designer view
-- Drag widgets from a palette onto real Limekit widgets, arrange them in
-- layouts, edit their properties, save the design, and write it out as a
-- Lua module.
--
-- The designer is a window of its own, opened from Limer's toolbar, not a
-- tab: a canvas wants the whole screen, and in a window of its own its
-- shortcuts (Ctrl+X cut, Ctrl+R run the design) stop fighting Limer's
-- (Ctrl+X stop, Ctrl+R run the project). It still lives in Limer's process
-- and follows Limer's open project.
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
local Icons = require "gui.views.designer.icons"
local Theme = require "app.core.theme"
local Images = require "app.core.images"

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
    S.window:setTitle(S.name .. ".design" .. (S.dirty and " *" or "") .. "  —  Limer Designer")
    local w = S.design.window
    S.info:setText(("%s  ·  %d × %d  ·  %s"):format(
        S.name, w.width, w.height, S.dirty and "unsaved changes" or "saved"))
end

-- Menu entries that only make sense for some selections follow it.
local function updateActions()
    local node = S.selected
    local isRoot = node ~= nil and node == S.design.root
    local isWidget = node ~= nil and not node.kind and not isRoot
    local A = S.actions
    A.undo:setEnabled(S.undo:canUndo())
    A.redo:setEnabled(S.undo:canRedo())
    S.undoButton:setEnabled(S.undo:canUndo())
    S.redoButton:setEnabled(S.undo:canRedo())
    for _, key in ipairs({ "cut", "copy", "duplicate", "wrapRow", "wrapColumn" }) do
        A[key]:setEnabled(isWidget)
    end
    A.delete:setEnabled(node ~= nil and not isRoot)
    S.deleteButton:setEnabled(node ~= nil and not isRoot)
    S.wrapRowButton:setEnabled(isWidget)
    S.wrapColumnButton:setEnabled(isWidget)
    A.unwrap:setEnabled(DesignModel.isContainer(node) and not isRoot and #node.children == 1)
    A.moveUp:setEnabled(node ~= nil and not isRoot)
    A.moveDown:setEnabled(node ~= nil and not isRoot)
    A.addPage:setEnabled(node ~= nil and node.layout == "tab")
    for _, item in ipairs(A.layouts) do item:setEnabled(DesignModel.hasLayout(node)) end
end

local function describe(node)
    if node == nil then return "nothing selected" end
    if node.kind then return node.kind end
    local text = node.name .. "  ·  " .. short(node.class)
    if DesignModel.isContainer(node) then text = text .. " in a " .. short(node.layout) end
    return text
end

local function refreshAll()
    S.canvas:rebuild(S.design)
    S.canvas:select(S.selected)
    S.surface:setFrameTitle(S.design.window.title)
    S.outline:refresh(S.design)
    S.outline:select(S.selected)
    S.props:show(S.selected, S.canvas:widgetFor(S.selected), S.design)
    S.preview:refresh(S.design, S.name)
    updateActions()
    updateTitle()
end

local function select(node)
    S.selected = node
    S.canvas:select(node)
    S.outline:select(node)
    S.props:show(node, S.canvas:widgetFor(node), S.design)
    updateActions()
    setStatus(describe(node))
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
    -- What is selected afterwards is what changed: the widget just added,
    -- moved or edited, or the container something was just taken out of.
    S.surface:flash(S.canvas:widgetFor(S.selected))
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
            local node = DesignModel.fromPalette(d, drop.class)
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
        local node = DesignModel.fromPalette(d, class)
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

-- Property panel callbacks. Each edits a snapshot by path, like every
-- other change.
local callbacks = {}

--- An image for a widget's slot, or for the window's icon (slot "window
--- icon"), by name; nil clears it. From Properties or a drop on the canvas.
function callbacks.onImage(node, slot, key)
    if slot == "window icon" then return callbacks.onWindow("icon", key) end
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        n.images = n.images or {}
        n.images[slot] = key
        if next(n.images) == nil then n.images = nil end
        return true
    end, key and (node.name .. "." .. slot .. " = images." .. key) or (node.name .. "." .. slot .. " cleared"))
end

--- The window's title, width, height or icon, from the root's Window section.
function callbacks.onWindow(field, value)
    if (field == "width" or field == "height") and value < 1 then
        setStatus(field .. " must be at least 1")
        refreshAll()
        return
    end
    mutate(function(d)
        d.window[field] = value
        return true
    end, "window " .. field .. " = " .. tostring(value))
end

function callbacks.onProp(node, name, value)
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        -- The live widget is asked first: it coerces, validates, and reads
        -- back what it actually holds, which is what the model records.
        local widget = S.canvas:widgetFor(node)
        local ok, result = Canvas.apply(widget, name, value)
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

--- A handle drag sets a minimum size: inside a layout, that is the size
--- control that means something, and it is what the generated code sets.
function callbacks.onResize(widget, width, height)
    local node = S.canvas:nodeFor(widget)
    if not node or node.kind then return end
    local path = pathOf(S.design, node)
    mutate(function(d)
        local n = nodeAt(d, path)
        if not n then return false, "gone" end
        n.props.minWidth, n.props.minHeight = width, height
        return true
    end, node.name .. " min size " .. width .. "x" .. height)
end

-- The property a double-click edits: the first one the widget has.
local TEXT_PROPS = { "text", "title", "hint", "plainText" }

function callbacks.onDoubleClick(widget)
    local node = S.canvas:nodeFor(widget)
    if not node or node.kind then return end
    select(node)
    local ok, props = pcall(sys.Introspect.properties, widget)
    if not ok then return end
    local byName = {}
    for _, p in ipairs(props) do byName[p.name] = p end
    for _, name in ipairs(TEXT_PROPS) do
        local p = byName[name]
        if p and p.settable and (p.type == "str" or p.type == "nil") then
            local text = ui.Dialogs.textInput(S.window, node.name, name .. ":", tostring(p.value or ""))
            if text ~= nil then callbacks.onProp(node, name, text) end
            return
        end
    end
    setStatus(node.name .. " has no text to edit; use Properties")
end

local function copySelected()
    local node = S.selected
    if not node or node == S.design.root or node.kind then
        setStatus("select a widget to copy")
        return false
    end
    sys.System.setClipboardText(DesignModel.fragment(node))
    setStatus("copied " .. node.name)
    return true
end

local function cutSelected()
    if copySelected() then deleteSelected() end
end

-- Pastes into the selection if it can hold things, else beside it.
local function pasteClipboard()
    local text = sys.System.getClipboardText()
    if not text or not text:match("^%s*return%s*{") then
        setStatus("the clipboard holds no design fragment")
        return
    end
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
        local node, why = DesignModel.paste(d, parent, text, slot)
        if not node then return false, why end
        return true, nil, pathOf(d, node)
    end, "pasted")
end

local function duplicateSelected()
    local node = S.selected
    if not node or node == S.design.root or node.kind then
        setStatus("select a widget to duplicate")
        return
    end
    local text = DesignModel.fragment(node)
    mutate(function(d, selected)
        local parent = DesignModel.parentOf(d, selected)
        local slot = { index = DesignModel.indexOf(parent, selected) + 1 }
        if selected.grid then slot = { row = selected.grid.row + 1, column = selected.grid.column } end
        local copy, why = DesignModel.paste(d, parent, text, slot)
        if not copy then return false, why end
        return true, nil, pathOf(d, copy)
    end, "duplicated " .. node.name)
end

local function addPage()
    mutate(function(d, selected)
        if not selected or selected.layout ~= "tab" then return false, "select a Tab first" end
        local page = DesignModel.container("ui.VLayout")
        local ok, why = DesignModel.insert(d, selected, page, {})
        if not ok then return false, why end
        return true, nil, pathOf(d, page)
    end, "added a page")
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

-- A name no saved design has, so saving a new design never quietly
-- overwrites one: main, then window2, window3...
local function freshName()
    local taken = {}
    for _, name in ipairs(project() and Files.list(project()) or {}) do taken[name] = true end
    if not taken.main then return "main" end
    local n = 2
    while taken["window" .. n] do n = n + 1 end
    return "window" .. n
end

local function newDesign()
    local name = freshName()
    loadDesign(DesignModel.blank(), name)
    setStatus("new, empty design '" .. name .. "' -- drag a layout or widget in; Ctrl+S saves it")
end

--- True if it is fine to throw the current design away.
local function confirmDiscard()
    if not S.dirty then return true end
    return ui.Dialogs.question(S.window, "Unsaved design",
        "The design '" .. S.name .. "' has unsaved changes. Discard them?") == true
end

local function refreshPicker()
    S.filling = true
    S.picker:clear()
    local names = Files.list(project())
    S.pickerNames = names
    -- The first entry names a design that is not on disk yet, so the
    -- picker always says what is being edited.
    local saved = false
    for _, name in ipairs(names) do saved = saved or name == S.name end
    S.picker:addItem(saved and "(designs)" or (S.name .. "  (not saved)"))
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
    local name = ui.Dialogs.textInput(S.window, "Save design as",
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
    local source = DesignModel.generate(S.design, S.name)
    local path, why = Files.writeGenerated(project(), S.name, source)
    if not path then warn("could not write: " .. tostring(why)); return end
    log("wrote " .. path)
    setStatus("wrote " .. path)

    -- Nothing overwrites main.lua. A generated file that quietly replaced
    -- the file someone had been writing would be unforgivable, and this is
    -- one way only -- the designer cannot read it back.
    ui.Dialogs.info(S.window, "Generated",
        "Written to scripts/designed/" .. S.name .. ".lua.\n\n" ..
        "In main.lua:\n\n" ..
        "    local " .. S.name .. " = require(\"designed." .. S.name .. "\")\n" ..
        "    " .. S.name .. ".window:show()\n\n" ..
        "Every widget is there by name, so handlers go on in main.lua:\n\n" ..
        "    " .. S.name .. ".button1:setOnClick(function() ... end)\n\n" ..
        "The designer never reads this file back; regenerate rather than edit it.")
end

--- Runs the design as a real window, through the same runner as Run.
local function runPreview()
    if not project() then warn("open a project first"); return end
    local ProjectRunner = require "app.core.project_runner"
    if AppState.projectIsRunning then
        warn("a project is already running -- stop it first")
        return
    end
    local source = DesignModel.generate(S.design, S.name)
    local path, why = Files.writePreview(project(), S.name, source)
    if not path then warn("could not write the preview: " .. tostring(why)); return end
    setStatus("running " .. S.name)
    ProjectRunner.run(path)
end

local function onProjectOpened()
    if S.dirty and not confirmDiscard() then return end
    S.imageBrowser:setRoot(Images.folder(project()))
    local names = Files.list(project())
    if #names > 0 then
        local design, why = Files.load(project(), names[1])
        if design then
            loadDesign(design, names[1])
            setStatus("opened design/" .. names[1] .. ".design.lua")
        else
            newDesign()
            warn("could not open " .. names[1] .. ": " .. tostring(why))
        end
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
    item(menu, "Add page", addPage, node ~= nil and node.layout == "tab")
    menu:addSeparator()
    item(menu, "Cut", cutSelected, isWidget and not isRoot)
    item(menu, "Copy", copySelected, isWidget and not isRoot)
    item(menu, "Paste", pasteClipboard)
    item(menu, "Duplicate", duplicateSelected, isWidget and not isRoot)
    menu:addSeparator()
    local layouts = ui.Menu("Change layout")
    for _, class in ipairs(DesignModel.LAYOUTS) do
        item(layouts, short(class), function() changeLayout(class) end, DesignModel.hasLayout(node))
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

-- BUILDING THE WINDOW -------------------------------------------------------

local function newDesignPrompt()
    if confirmDiscard() then newDesign(); refreshPicker() end
end

-- Run and Stop are one button, as on Limer's own toolbar: whatever is
-- running -- this design's preview or the project itself -- can be stopped
-- from here.
local function toggleRun()
    local ProjectRunner = require "app.core.project_runner"
    if AppState.projectIsRunning then
        ProjectRunner.stop()
    else
        runPreview()
    end
end

local function paintRun(isRunning)
    S.runButton:setText(isRunning and "Stop" or "Run")
    S.runButton:setIcon(Icons.tool(isRunning and "stop" or "run"))
    S.runButton:setToolTip(isRunning and "Stop the running window  (Ctrl+R)"
                                      or "Open the design as a real window  (Ctrl+R)")
    S.actions.run:setText(isRunning and "Stop running" or "Run design")
    S.actions.run:setIcon(Icons.tool(isRunning and "stop" or "run"))
    S.running:setVisible(isRunning)
    S.busy:setVisible(isRunning)
    setStatus(isRunning and "running -- Stop (Ctrl+R) ends it" or "stopped")
end

local function paintTheme()
    local label = Theme.offer()
    S.themeButton:setIcon(Icons.tool(label:lower()))
    S.themeButton:setToolTip("Switch to the " .. label:lower() .. " theme")
end

local function undo() restore(S.undo:undo(), "undo") end
local function redo() restore(S.undo:redo(), "redo") end

local function toggleCode()
    S.codeVisible = not S.codeVisible
    S.code:setVisible(S.codeVisible)
    S.codeButton:setChecked(S.codeVisible)
    S.actions.code:setChecked(S.codeVisible)
end

-- The menubar is where every command lives, with its shortcut beside it.
-- Entries given a `key` are kept in S.actions, so updateActions can enable
-- them as the selection changes.
--
-- Shortcuts on menu entries belong to the whole window. That is safe for
-- Ctrl+C, Ctrl+Z and the rest -- a text field that has focus claims the
-- standard editing keys before a shortcut sees them -- but not for Delete,
-- which a table does not claim: with the Properties table focused, Delete
-- would remove a widget from the design. Delete is bound to the canvas and
-- the outline instead (installShortcuts), and only shown here.
local function buildMenubar()
    S.actions = { layouts = {} }
    local menubar = ui.Menubar()

    local function menu(title, entries)
        local m = ui.Menu(title)
        for _, e in ipairs(entries) do
            if e == "-" then
                m:addSeparator()
            elseif e.submenu then
                m:addMenu(e.submenu)
            else
                local entry = ui.MenuItem(e[1])
                if e.icon then entry:setIcon(Icons.tool(e.icon)) end
                if e.shortcut then entry:setShortcut(e.shortcut) end
                if e.checkable then entry:setCheckable(true) end
                entry:setOnClick(e[2])
                m:addMenuItem(entry)
                if e.key then S.actions[e.key] = entry end
            end
        end
        menubar:addMenu(m)
    end

    local layouts = ui.Menu("Change layout")
    for _, class in ipairs(DesignModel.LAYOUTS) do
        local entry = ui.MenuItem(short(class))
        entry:setOnClick(function() changeLayout(class) end)
        layouts:addMenuItem(entry)
        S.actions.layouts[#S.actions.layouts + 1] = entry
    end

    menu("File", {
        { "New design", newDesignPrompt, shortcut = "Ctrl+N", icon = "new" },
        { "Save", save, shortcut = "Ctrl+S", icon = "save" },
        { "Save as...", saveAsPrompt, shortcut = "Ctrl+Shift+S" },
        "-",
        { "Generate Lua", generate, shortcut = "Ctrl+G", icon = "generate" },
        { "Run design", toggleRun, shortcut = "Ctrl+R", icon = "run", key = "run" },
        "-",
        { "Close designer", function() S.window:close() end, shortcut = "Ctrl+W" },
    })
    menu("Edit", {
        { "Undo", undo, shortcut = "Ctrl+Z", icon = "undo", key = "undo" },
        { "Redo", redo, shortcut = "Ctrl+Y", icon = "redo", key = "redo" },
        "-",
        { "Cut", cutSelected, shortcut = "Ctrl+X", key = "cut" },
        { "Copy", copySelected, shortcut = "Ctrl+C", key = "copy" },
        { "Paste", pasteClipboard, shortcut = "Ctrl+V" },
        { "Duplicate", duplicateSelected, shortcut = "Ctrl+D", key = "duplicate" },
        "-",
        { "Delete\tDel", deleteSelected, icon = "delete", key = "delete" },
    })
    menu("Arrange", {
        { "Wrap in a row", function() wrapSelected("ui.HLayout") end, icon = "row", key = "wrapRow" },
        { "Wrap in a column", function() wrapSelected("ui.VLayout") end, icon = "column", key = "wrapColumn" },
        { "Unwrap", unwrapSelected, key = "unwrap" },
        { submenu = layouts },
        "-",
        { "Add stretch", function() addPseudo(DesignModel.stretch, "stretch") end },
        { "Add spacing", function() addPseudo(function() return DesignModel.spacing(12) end, "spacing") end },
        { "Add page", addPage, key = "addPage" },
        "-",
        { "Move up", function() moveSelected(-1) end, shortcut = "Ctrl+Up", key = "moveUp" },
        { "Move down", function() moveSelected(1) end, shortcut = "Ctrl+Down", key = "moveDown" },
    })
    menu("View", {
        { "Generated code", toggleCode, shortcut = "Ctrl+Shift+C", icon = "code", checkable = true, key = "code" },
    })
    return menubar
end

local function buildToolbar()
    local toolbar = ui.Toolbar()
    toolbar:setMovable(false)
    toolbar:setToolButtonStyle("textbesideicon")

    -- An empty label leaves the icon alone; the tooltip names it.
    local function tool(text, icon, tip, handler)
        local b = ui.ToolbarButton(text)
        b:setIcon(Icons.tool(icon))
        b:setToolTip(tip)
        b:setOnClick(handler)
        toolbar:addButton(b)
        return b
    end

    tool("", "new", "New design  (Ctrl+N)", newDesignPrompt)
    tool("", "save", "Save  (Ctrl+S)", save)
    toolbar:addSeparator()
    S.undoButton = tool("", "undo", "Undo  (Ctrl+Z)", undo)
    S.redoButton = tool("", "redo", "Redo  (Ctrl+Y)", redo)
    toolbar:addSeparator()
    S.wrapRowButton = tool("Row", "row", "Wrap the selection in a new row",
        function() wrapSelected("ui.HLayout") end)
    S.wrapColumnButton = tool("Column", "column", "Wrap the selection in a new column",
        function() wrapSelected("ui.VLayout") end)
    S.deleteButton = tool("", "delete", "Delete the selection  (Del)", deleteSelected)

    -- Everything after this sits at the right-hand end.
    local spacer = ui.Container()
    spacer:setResizeRule("expanding", "preferred")
    toolbar:addChild(spacer)

    S.picker = ui.ComboBox()
    S.picker:setMinWidth(170)
    S.picker:setToolTip("The project's designs, in its design folder")
    S.picker:setOnItemSelect(function(_, index)
        if S.filling then return end
        local name = S.pickerNames[index - 1]
        if name and name ~= S.name then openDesign(name) end
    end)
    toolbar:addChild(S.picker)
    toolbar:addSeparator()
    S.codeButton = tool("Code", "code", "Show the Lua this design generates  (Ctrl+Shift+C)", toggleCode)
    S.codeButton:setCheckable(true)
    tool("Generate", "generate", "Write scripts/designed/<name>.lua  (Ctrl+G)", generate)
    S.runButton = tool("Run", "run", "Open the design as a real window  (Ctrl+R)", toggleRun)
    toolbar:addSeparator()
    S.themeButton = tool("", "dark", "Switch to the dark theme", function() Theme.toggle() end)
    return toolbar
end

-- Bare layouts on the palette. Each becomes a Container laid out that way
-- (DesignModel.fromPalette), named row1, column1 and so on.
local LAYOUT_ENTRIES = {
    { id = "layout:ui.VLayout", text = "Column", tip = "Widgets stacked top to bottom (VLayout)" },
    { id = "layout:ui.HLayout", text = "Row", tip = "Widgets side by side (HLayout)" },
    { id = "layout:ui.GridLayout", text = "Grid", tip = "Widgets in rows and columns (GridLayout)" },
    { id = "layout:ui.FormLayout", text = "Form", tip = "A label beside each field (FormLayout)" },
}

local function paletteIcons()
    local map = Icons.mapFor(S.palette:getClasses())
    for _, entry in ipairs(LAYOUT_ENTRIES) do map[entry.id] = Icons.forClass(entry.id) end
    return map
end

local function installShortcuts()
    local function bind(parent, sequence, scope, handler)
        local shortcut = ui.KeyboardShortcut(parent, sequence)
        shortcut:setScope(scope)
        shortcut:setOnPress(handler)
        return shortcut
    end
    S.shortcuts = {
        bind(S.scroller, "Delete", "widget", deleteSelected),
        bind(S.tree, "Delete", "widget", deleteSelected),
        bind(S.window, "Ctrl+Shift+Z", "window", redo),
    }
end

function DesignerView.create()
    S = {
        undo = DesignModel.Undo.new(),
        dirty = false,
        name = "main",
        filling = false,
        pickerNames = {},
        codeVisible = false,
        status = ui.Label(""),
        info = ui.Label(""),
    }

    S.window = ui.Window {
        title = "Limer Designer",
        icon = Icons.tool("designer"),
    }
    S.window:setSize(1360, 840)

    -- Left: the palette.
    S.palette = ui.WidgetPalette()
    S.palette:setMinWidth(160)
    S.palette:setMaxWidth(280)
    -- Layouts first: in Limekit a layout is what holds widgets, so it is
    -- usually the first thing a window needs.
    S.palette:addGroup("Layouts", LAYOUT_ENTRIES, true)
    S.palette:setIcons(paletteIcons())
    S.palette:setOnPick(addClass)

    -- Middle: the canvas, and the generated code under it when asked for.
    S.surface = ui.DesignSurface()
    S.surface:setOnContextMenu(function(widget, x, y)
        -- The surface has already selected `widget`; the view's selection
        -- follows through onSelect. Build the menu for that selection.
        local menu = buildContextMenu()
        menu:popupAt(S.surface, x, y)
    end)
    S.surface:setOnResize(callbacks.onResize)
    S.surface:setOnDoubleClick(function(widget) callbacks.onDoubleClick(widget) end)
    S.scroller = ui.Scroller()
    S.scroller:setChild(S.surface)
    S.scroller:setResizable(true)
    S.scroller:setMinWidth(240)
    S.canvas = Canvas.new(S.surface, onDrop, select,
        function(node, slot, key) callbacks.onImage(node, slot, key) end)

    -- The project's images, beside the palette. Dropping files in, making
    -- folders and moving images between them rewrites images.lua (through
    -- Images.refresh) and the canvas follows; drag an image onto a widget
    -- to give it that image.
    S.imageBrowser = ui.ImageBrowser()
    S.imageBrowser:setOrientation("vertical")
    S.imageBrowser:setOnChange(function()
        if project() then Images.refresh(project()) end
    end)
    S.imageBrowser:setOnSelect(function(relPath)
        local key = relPath and Images.keyFor(relPath)
        S.imageBrowser:setInfo(key
            and ("In code: " .. Images.reference(key) .. "\nDrag it onto a widget, or pick it in Properties.")
            or "Drop image files here, or onto a folder.")
    end)

    local left = ui.Tab()
    left:addTab(S.palette, "Widgets")
    left:addTab(S.imageBrowser, "Images")
    left:setMinWidth(170)

    S.code = ui.TextField()
    S.preview = Preview.new(S.code)
    S.code:setVisible(false)

    local middle = ui.Splitter("vertical")
    middle:addChild(S.scroller)
    middle:addChild(S.code)
    middle:setStretchFactors({ 1, 0 })
    middle:setSizes({ 560, 220 })

    -- Right: the outline above the properties, both always in view.
    S.tree = ui.TreeView()
    S.outline = Outline.new(S.tree, select)
    local table_ = ui.Table()
    S.props = Properties.new(table_, callbacks)

    local side = ui.Splitter("vertical")
    side:addChild(S.tree)
    side:addChild(table_)
    side:setSizes({ 260, 480 })
    side:setMinWidth(280)

    -- The canvas takes every pixel the palette and the side pane do not
    -- need. setSizes is in pixels and only a starting point; the stretch
    -- factors are what keep the canvas the one that grows.
    local split = ui.Splitter("horizontal")
    split:addChild(left)
    split:addChild(middle)
    split:addChild(side)
    split:setStretchFactors({ 0, 1, 0 })
    split:setSizes({ 210, 790, 360 })

    -- While a window is running: a green label and a busy bar, so it is
    -- plain that something is up and that Stop will end it.
    S.running = ui.Label("●  Running")
    S.running:setTextColor("#16A34A")
    S.running:setVisible(false)
    S.busy = ui.ProgressBar()
    S.busy:setRange(0, 0)
    S.busy:setMaxWidth(90)
    S.busy:setMaxHeight(10)
    S.busy:setVisible(false)

    local bar = ui.StatusBar()
    bar:addChild(S.status, 1)
    bar:addPermanentChild(S.running, 0)
    bar:addPermanentChild(S.busy, 0)
    bar:addPermanentChild(S.info, 0)

    S.window:setMenubar(buildMenubar())
    S.window:addToolbar(buildToolbar())
    S.window:setStatusbar(bar)
    S.window:setMainChild(split)

    installShortcuts()
    newDesign()

    -- The widget icons are drawn for one background; a theme switch has to
    -- swap them, which a palette change alone does not do.
    Theme.observe(function()
        S.palette:setIcons(paletteIcons())
        S.outline:refresh(S.design)
        S.outline:select(S.selected)
        paintTheme()
    end)
    paintTheme()

    -- Images added, moved or renamed -- here, in Limer's Images tab, or
    -- outside Limer -- show on the canvas and in Properties at once.
    Images.observe(function()
        if S.design then refreshAll() end
    end)

    -- The runner is shared with Limer's own Run button, so the designer's
    -- button follows it whoever started or stopped the run.
    local ProjectRunner = require "app.core.project_runner"
    ProjectRunner.observe(paintRun)
    paintRun(AppState.projectIsRunning == true)
    setStatus("")

    local function show()
        S.window:show()
        S.window:setFocus()
    end

    return {
        window = S.window,
        show = show,
        hide = function() S.window:hide() end,
        onProjectOpened = onProjectOpened,
        isDirty = function() return S.dirty end,

        --- True if Limer may quit: nothing unsaved, or the user said so.
        confirmQuit = function()
            if not S.dirty then return true end
            show()
            return ui.Dialogs.question(S.window, "Unsaved design",
                "The design '" .. S.name .. "' has unsaved changes. Quit anyway?") == true
        end,

        -- For scripts and checks.
        getDesign = function() return S.design end,
        getSelected = function() return S.selected end,
        selectNode = select,
        addClass = addClass,
        deleteSelected = deleteSelected,
        moveSelected = moveSelected,
        wrapSelected = wrapSelected,
        undo = undo,
        redo = redo,
        newDesign = newDesign,
        generate = generate,
        runPreview = runPreview,
        copySelected = copySelected,
        pasteClipboard = pasteClipboard,
        duplicateSelected = duplicateSelected,
        toggleCode = toggleCode,
        getStatus = function() return S.status:getText() end,
    }
end

return DesignerView
