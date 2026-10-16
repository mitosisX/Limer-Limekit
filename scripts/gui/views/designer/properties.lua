-- Properties
-- What the selection is called, where it sits, and what its widget
-- declares, in labelled sections. With the root selected, the window it
-- will become comes first: its title and size live here rather than in a
-- row of fields above the canvas.
--
-- Booleans are checkboxes and enums are drop-downs, both as cell widgets,
-- so a value can only ever be set to something the widget accepts.
-- Numbers and text are typed straight into the cell.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"
local Images = require "app.core.images"

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
--- onWindow(field, value)
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

-- Each row: { label, value, kind, apply(value), options }.
-- kind: "section" | "string" | "int" | "float" | "boolean" | "enum" | "readonly"
function Properties:rowsFor(design, node, widget)
    local rows, cb = {}, self.cb
    local function row(label, value, kind, apply, options)
        rows[#rows + 1] = { label = label, value = value, kind = kind, apply = apply, options = options }
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
    if DesignModel.hasLayout(node) then
        row("layout", node.layout:match("%.(.+)$"), "enum",
            function(v) cb.onLayout(node, "ui." .. v) end, LAYOUT_NAMES)
    end
    if node.buildError then
        row("error", node.buildError, "readonly", function() end)
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
    return rows
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
                local item = self.table:getCellItem(i, column)
                if item then
                    item:setBackgroundColour(SECTION_BACKGROUND)
                    item:setTextColour(SECTION_TEXT)
                end
            end
        else
            self.table:setCellText(i, 1, r.label)
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
            local combo = ui.ComboBox()
            combo:addItems(r.options)
            for k, option in ipairs(r.options) do
                if option == r.value then combo:setCurrentIndex(k) end
            end
            combo:setOnItemSelect(function(_, index)
                if not self.filling and r.options[index] and r.options[index] ~= r.value then
                    local chosen = r.options[index]
                    later(function() r.apply(chosen) end)
                end
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
        elseif r.kind ~= "section" then
            local shown = r.value
            if shown == nil then shown = "" end
            self.table:setCellText(i, 2, tostring(shown))
        end
    end
    self.filling = false
end

function Properties:edited(row, column)
    if self.filling then return end
    local r = self.rows[row]
    if not r then return end
    if column ~= 2 or r.kind == "section" or r.kind == "readonly" then
        -- Labels are not values; put back whatever was typed over them.
        self.filling = true
        self.table:setCellText(row, 1, r.kind == "section" and r.label:upper() or r.label)
        if r.kind == "section" then
            self.table:setCellText(row, 2, "")
        elseif r.kind == "readonly" then
            self.table:setCellText(row, 2, tostring(r.value or ""))
        end
        self.filling = false
        return
    end
    if r.kind == "boolean" or r.kind == "enum" or r.kind == "image" then return end

    local item = self.table:getCellItem(row, 2)
    local text = item and item:getText() or ""
    local value = text
    if r.kind == "int" then
        value = math.tointeger(tonumber(text))
    elseif r.kind == "float" then
        value = tonumber(text)
    end
    if value == nil then
        -- Not a number: put the old value back rather than send text where
        -- a number is expected.
        self.filling = true
        self.table:setCellText(row, 2, tostring(r.value == nil and "" or r.value))
        self.filling = false
        return
    end
    if value == r.value then return end
    later(function() r.apply(value) end)
end

return Properties
