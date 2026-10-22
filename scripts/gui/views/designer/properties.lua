-- Properties
-- What the selection is called, where it sits, and what its widget
-- declares, in labelled sections. With the root selected, the window it
-- will become comes first: its title and size live here rather than in a
-- row of fields above the canvas.
--
-- Booleans are checkboxes and enums are drop-downs, both as cell widgets,
-- so a value can only ever be set to something the widget accepts.
-- Numbers and text are typed straight into the cell. A list, and a Table's
-- contents, are a button that opens an editor of their own.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"
local Images = require "app.core.images"
local Catalog = require "gui.views.designer.catalog"

local Properties = {}
Properties.__index = Properties

local LAYOUT_NAMES = { "VLayout", "HLayout", "GridLayout", "FormLayout" }

-- Declared by every widget but meaningless in a design: read live from the
-- canvas, `visible` reports whether the canvas happens to be on screen.
local HIDDEN = { visible = true }

-- Translucent, so one colour reads as a band in both light and dark themes.
local SECTION_BACKGROUND = "#3a808080"
-- A mid blue that holds its contrast on either background.
local SECTION_TEXT = "#4C8DFF"

-- The first choice in an image drop-down: no image.
local NONE = "(none)"

--- callbacks: onProp(node, name, value), onRename(node, name),
--- onPlacement(node, field, value), onLayout(node, layoutClass),
--- onWindow(field, value), onImage(node, slot, key), onLock(node, locked),
--- editList(node, name) and editTable(node), which open the editors
function Properties.new(table_, callbacks)
    local self = setmetatable({ table = table_, cb = callbacks, rows = {}, filling = false }, Properties)
    table_:setColumnHeaders({ "Property", "Value" })
    table_:setCellsEditable(true)
    table_:setColumnWidth(1, 140)
    table_:setStretchLastColumn(true)
    table_:setRowHeadersVisible(false)
    -- Alternating rows and a grid would drown out the section bands, which
    -- are what tell one group of properties from the next.
    table_:setAlternatingRowColors(false)
    table_:setShowGrid(false)
    table_:setOnCellChange(function(_, row, column) self:edited(row, column) end)
    return self
end

-- Applies a value on the next turn of the event loop. Applying rebuilds
-- this table, and a ComboBox or CheckBox in a cell must not be destroyed
-- inside its own change signal: Qt then reports commitData/closeEditor
-- "called with an editor that does not belong to this view".
local function later(fn)
    sys.Timer.singleShot(0, fn)
end

-- The value a widget shows before the design sets one, read through its
-- getter (getText, isChecked...). Only for plain values; nil if none.
local function current(widget, name)
    local cap = name:sub(1, 1):upper() .. name:sub(2)
    for _, prefix in ipairs({ "get", "is" }) do
        local ok, getter = pcall(function() return widget[prefix .. cap] end)
        if ok and getter then
            local called, value = pcall(getter, widget)
            local t = type(value)
            if called and (t == "string" or t == "number" or t == "boolean") then return value end
        end
    end
    return nil
end

-- How each catalogue kind is edited in the table. A pair is typed as text
-- and read back by Catalog.parse; a list opens the list editor.
local ROW_KINDS = { string = "string", colour = "string", int = "int", float = "float",
                    bool = "boolean", enum = "enum", list = "list", pair = "parsed",
                    date = "parsed", time = "parsed" }

-- Row kinds whose value cell is a widget of its own, not typed into.
local CELL_WIDGETS = { boolean = true, enum = true, image = true, list = true, table = true }

-- One catalogue entry as a row.
local function catalogRow(row, node, widget, entry, cb)
    local name, kind, options = entry[1], entry[2], entry[3]
    local value = node.props[name]
    -- A list, pair, date or time is read from the design only: the widget's
    -- getters hand back other shapes than the setters take.
    if value == nil and ROW_KINDS[kind] ~= "list" and ROW_KINDS[kind] ~= "parsed" then
        value = current(widget, name)
    end
    local r = row(name, value, ROW_KINDS[kind] or "string", function(v) cb.onProp(node, name, v) end, options, kind)
    if kind == "list" then r.open = function() cb.editList(node, name) end end
end

-- What a list's or a table's button says it holds.
local SUMMARY_LENGTH = 44

local function clip(text)
    if #text <= SUMMARY_LENGTH then return text end
    return text:sub(1, SUMMARY_LENGTH - 3) .. "..."
end

local function listSummary(value)
    if type(value) ~= "table" or #value == 0 then return "(none)  --  edit..." end
    return clip(("%d: %s"):format(#value, table.concat(value, ", ")))
end

local function tableSummary(contents)
    local columns, rows = #contents.headers, #contents.rows
    if columns == 0 and rows == 0 then return "(empty)  --  edit..." end
    local titles = {}
    for _, title in ipairs(contents.headers) do if title ~= "" then titles[#titles + 1] = title end end
    local shape = ("%d %s x %d %s"):format(columns, columns == 1 and "column" or "columns",
                                          rows, rows == 1 and "row" or "rows")
    if #titles == 0 then return shape end
    return clip(shape .. ": " .. table.concat(titles, ", "))
end

-- Each row: { label, value, kind, apply(value), options, catalog, open }.
-- kind: "section" | "string" | "int" | "float" | "boolean" | "enum" | "image"
--     | "parsed" | "list" | "table" | "readonly"
-- A list or table row is a button; `open` is what pressing it does.
function Properties:rowsFor(design, node, widget)
    local rows, cb = {}, self.cb
    local function row(label, value, kind, apply, options, catalog)
        local r = { label = label, value = value, kind = kind, apply = apply,
                    options = options, catalog = catalog }
        rows[#rows + 1] = r
        return r
    end
    local function section(title)
        row(title, nil, "section")
    end

    if DesignModel.isPseudo(node) then
        section(node.kind)
        if node.kind == "stretch" then
            row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
        else
            row("size", node.size, "int", function(v) cb.onPlacement(node, "size", v) end)
        end
        return rows
    end

    if design and node == design.root then
        local w = design.window
        section("Window")
        row("title", w.title, "string", function(v) cb.onWindow("title", v) end)
        row("width", w.width, "int", function(v) cb.onWindow("width", v) end)
        row("height", w.height, "int", function(v) cb.onWindow("height", v) end)
        row("icon", w.icon, "image", function(v) cb.onWindow("icon", v) end)
    end

    section("Object")
    row("name", node.name, "string", function(v) cb.onRename(node, v) end)
    if not (design and node == design.root) then
        row("locked", node.locked == true, "boolean", function(v) cb.onLock(node, v) end)
    end
    if DesignModel.hasLayout(node) then
        row("layout", node.layout:match("%.(.+)$"), "enum",
            function(v) cb.onLayout(node, "ui." .. v) end, LAYOUT_NAMES)
    end
    if node.buildError then
        row("error", node.buildError, "readonly", function() end)
    end

    -- A form's labels belong to its rows, and each is stored on the field it
    -- labels. Shown here too, so a form's rows can be read and relabelled
    -- in one place rather than one field at a time.
    if node.layout == "ui.FormLayout" and #node.children > 0 then
        section("Rows")
        for _, child in ipairs(node.children) do
            if child.form then
                row(child.name, child.form.label, "string",
                    function(v) cb.onPlacement(child, "form.label", v) end)
            end
        end
    end

    local slots = DesignModel.imageSlots(node.class)
    if #slots > 0 then
        section("Images")
        for _, slot in ipairs(slots) do
            row(slot, (node.images or {})[slot], "image",
                function(v) cb.onImage(node, slot, v) end)
        end
    end

    if node.tab or node.grid or node.form or node.stretch ~= nil then
        section("Placement")
        if node.tab then
            row("tab title", node.tab.title, "string", function(v) cb.onPlacement(node, "tab.title", v) end)
        end
        if node.grid then
            for _, f in ipairs({ "row", "column", "rowSpan", "columnSpan" }) do
                row(f, node.grid[f], "int", function(v) cb.onPlacement(node, "grid." .. f, v) end)
            end
        elseif node.form then
            row("label", node.form.label, "string", function(v) cb.onPlacement(node, "form.label", v) end)
        elseif node.stretch ~= nil then
            row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
        end
    end

    if widget and not node.buildError then
        local entries = Catalog.forClass(node.class)
        local isTable = node.class == "ui.Table"
        if entries then
            -- The catalogue: what designing this widget needs, by setter.
            if #entries > 0 or isTable then section(node.class:match("%.(.+)$") or node.class) end
            if isTable then
                -- Titles, rows and cells: not setters one at a time, but one
                -- grid, edited in the table editor.
                local r = row("contents", DesignModel.tableContents(node), "table", function() end)
                r.open = function() cb.editTable(node) end
            end
            for _, entry in ipairs(entries) do catalogRow(row, node, widget, entry, cb) end
        else
            -- A widget nobody has written a list for: what it declares.
            local ok, props = pcall(sys.Introspect.properties, widget)
            if ok then
                section(node.class:match("%.(.+)$") or node.class)
                for _, prop in ipairs(props) do
                    if prop.settable and not HIDDEN[prop.name] then
                        local kind = prop.options and "enum"
                            or (prop.type == "str" and "string")
                            or (prop.type == "nil" and "string")
                            or prop.type
                        row(prop.name, prop.value, kind,
                            function(v) cb.onProp(node, prop.name, v) end, prop.options)
                    end
                end
            end
        end
        section("Common")
        for _, entry in ipairs(Catalog.COMMON) do catalogRow(row, node, widget, entry, cb) end
    end
    return rows
end

-- A cell that shows text but cannot be typed into: every label, every
-- section band, and a read-only value.
function Properties:lock(row, column)
    local item = self.table:getCellItem(row, column)
    if item then item:setEditable(false) end
    return item
end

function Properties:show(node, widget, design)
    self.filling = true
    self.table:clearContent()
    self.rows = node and self:rowsFor(design, node, widget) or {}
    self.table:setRowCount(#self.rows)

    for i, r in ipairs(self.rows) do
        if r.kind == "section" then
            self.table:setCellText(i, 1, r.label:upper())
            self.table:setCellText(i, 2, "")
            for column = 1, 2 do
                local item = self:lock(i, column)
                if item then
                    item:setBackgroundColour(SECTION_BACKGROUND)
                    item:setTextColour(SECTION_TEXT)
                end
            end
        else
            self.table:setCellText(i, 1, r.label)
            self:lock(i, 1)
        end

        if r.kind == "boolean" then
            local box = ui.CheckBox("")
            -- A cell widget paints its own background over the cell's;
            -- transparent, it sits on the table like a typed value does.
            box:setStyleSheet("QCheckBox { background: transparent; padding-left: 6px; }")
            box:setChecked(r.value == true)
            box:setOnCheck(function(_, checked)
                if not self.filling then later(function() r.apply(checked == true) end) end
            end)
            self.table:setCellChild(i, 2, box)
        elseif r.kind == "enum" then
            -- A catalogue choice not yet made reads "(default)" rather than
            -- showing the first option as though it had been picked.
            local options, values = {}, {}
            if r.catalog then options[1], values[1] = "(default)", false end
            for _, option in ipairs(r.options) do
                options[#options + 1], values[#values + 1] = option, option
            end
            local combo = ui.ComboBox()
            combo:addItems(options)
            for k, value in ipairs(values) do
                if value == (r.value or false) then combo:setCurrentIndex(k) end
            end
            combo:setOnItemSelect(function(_, index)
                local chosen = values[index]
                if self.filling or chosen == nil or chosen == (r.value or false) then return end
                later(function() r.apply(chosen or nil) end)
            end)
            self.table:setCellChild(i, 2, combo)
        elseif r.kind == "image" then
            -- Every image in the project by name. One that is named in the
            -- design but no longer on disk stays listed, marked, so it is
            -- plain what broke rather than silently showing "(none)".
            local options, keys = { NONE }, { false }
            local present = false
            for _, image in ipairs(Images.list()) do
                options[#options + 1] = image.key .. "   (" .. image.path .. ")"
                keys[#keys + 1] = image.key
                present = present or image.key == r.value
            end
            if r.value and not present then
                options[#options + 1] = r.value .. "   (missing)"
                keys[#keys + 1] = r.value
            end
            local combo = ui.ComboBox()
            combo:addItems(options)
            for k, key in ipairs(keys) do
                if key == (r.value or false) then combo:setCurrentIndex(k) end
            end
            combo:setOnItemSelect(function(_, index)
                local chosen = keys[index]
                if self.filling or chosen == nil or chosen == (r.value or false) then return end
                later(function() r.apply(chosen or nil) end)
            end)
            self.table:setCellChild(i, 2, combo)
        elseif r.kind == "list" or r.kind == "table" then
            -- A button saying what is there; pressing it opens the editor.
            -- The editor opens on the next turn: what it returns is applied,
            -- applying rebuilds this table, and the button must not be
            -- destroyed inside its own click.
            local summary = r.kind == "list" and listSummary(r.value) or tableSummary(r.value)
            local button = ui.Button(summary)
            button:setStyleSheet("QPushButton { text-align: left; padding: 2px 8px; }")
            button:setToolTip(r.kind == "list" and "Edit the items, one per row"
                                               or "Edit the titles, rows and cells")
            button:setOnClick(function()
                if not self.filling and r.open then later(r.open) end
            end)
            self.table:setCellChild(i, 2, button)
        elseif r.kind == "parsed" then
            self.table:setCellText(i, 2, Catalog.show(r.catalog, r.value))
        elseif r.kind ~= "section" then
            local shown = r.value
            if shown == nil then shown = "" end
            self.table:setCellText(i, 2, tostring(shown))
            if r.kind == "readonly" then self:lock(i, 2) end
        end
    end
    self.filling = false
end

-- Puts a value cell back to what the row holds: after text that does not
-- parse, rather than sending it on.
function Properties:restore(row, r)
    self.filling = true
    local shown = r.kind == "parsed" and Catalog.show(r.catalog, r.value)
        or tostring(r.value == nil and "" or r.value)
    self.table:setCellText(row, 2, shown)
    self.filling = false
end

function Properties:edited(row, column)
    if self.filling or column ~= 2 then return end
    local r = self.rows[row]
    if not r or r.kind == "section" or r.kind == "readonly" or CELL_WIDGETS[r.kind] then
        return
    end

    local item = self.table:getCellItem(row, 2)
    local text = item and item:getText() or ""

    -- A catalogue value emptied is "not set": the widget keeps its default.
    if r.catalog and r.catalog ~= "string" and r.catalog ~= "colour" and text:match("^%s*$") then
        if r.value ~= nil then later(function() r.apply(nil) end) end
        return
    end

    local value = text
    if r.kind == "parsed" then
        local parsed = Catalog.parse(r.catalog, text)
        if not parsed then self:restore(row, r); return end
        value = parsed
    elseif r.kind == "int" then
        value = math.tointeger(tonumber(text))
    elseif r.kind == "float" then
        value = tonumber(text)
    end
    if value == nil then
        -- Not a number: put the old value back rather than send text where
        -- a number is expected.
        self:restore(row, r)
        return
    end
    if value == r.value then return end
    later(function() r.apply(value) end)
end

return Properties
