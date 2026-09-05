-- Properties
-- What the selection is called, where it sits, and what its widget
-- declares. Two columns; the value column takes the room, which is what
-- the old three-column panel never managed.
--
-- Booleans are checkboxes and enums are drop-downs, both as cell widgets,
-- so a value can only ever be set to something the widget accepts.
-- Numbers and text are typed straight into the cell.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"

local Properties = {}
Properties.__index = Properties

local LAYOUT_NAMES = { "VLayout", "HLayout", "GridLayout", "FormLayout" }

--- callbacks: onProp(node, name, value), onRename(node, name),
--- onPlacement(node, field, value), onLayout(node, layoutClass)
function Properties.new(table_, callbacks)
    local self = setmetatable({ table = table_, cb = callbacks, rows = {}, filling = false }, Properties)
    table_:setColumnHeaders({ "property", "value" })
    table_:setCellsEditable(true)
    table_:setColumnWidth(1, 150)
    table_:setStretchLastColumn(true)
    table_:setOnCellChange(function(_, row, column) self:edited(row, column) end)
    return self
end

-- Each row: { label, value, kind, apply(value), options }.
-- kind: "string" | "int" | "float" | "boolean" | "enum"
function Properties:rowsFor(node, widget)
    local rows, cb = {}, self.cb
    local function row(label, value, kind, apply, options)
        rows[#rows + 1] = { label = label, value = value, kind = kind, apply = apply, options = options }
    end

    if DesignModel.isPseudo(node) then
        if node.kind == "stretch" then
            row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
        else
            row("size", node.size, "int", function(v) cb.onPlacement(node, "size", v) end)
        end
        return rows
    end

    row("name", node.name, "string", function(v) cb.onRename(node, v) end)
    if DesignModel.hasLayout(node) then
        row("layout", node.layout:match("%.(.+)$"), "enum",
            function(v) cb.onLayout(node, "ui." .. v) end, LAYOUT_NAMES)
    end
    if node.tab then
        row("tab.title", node.tab.title, "string", function(v) cb.onPlacement(node, "tab.title", v) end)
    end
    if node.grid then
        for _, f in ipairs({ "row", "column", "rowSpan", "columnSpan" }) do
            row("grid." .. f, node.grid[f], "int", function(v) cb.onPlacement(node, "grid." .. f, v) end)
        end
    elseif node.form then
        row("form.label", node.form.label, "string", function(v) cb.onPlacement(node, "form.label", v) end)
    elseif node.stretch ~= nil then
        row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
    end
    if node.buildError then
        row("error", node.buildError, "readonly", function() end)
    end

    if widget and not node.buildError then
        local ok, props = pcall(sys.Introspect.properties, widget)
        if ok then
            for _, prop in ipairs(props) do
                if prop.settable then
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

function Properties:show(node, widget)
    self.filling = true
    self.table:clearContent()
    self.rows = node and self:rowsFor(node, widget) or {}
    self.table:setRowCount(#self.rows)

    for i, r in ipairs(self.rows) do
        self.table:setCellText(i, 1, r.label)
        if r.kind == "boolean" then
            local box = ui.CheckBox("")
            box:setChecked(r.value == true)
            box:setOnCheck(function(_, checked)
                if not self.filling then r.apply(checked == true) end
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
                    r.apply(r.options[index])
                end
            end)
            self.table:setCellChild(i, 2, combo)
        else
            local shown = r.value
            if shown == nil then shown = "" end
            self.table:setCellText(i, 2, tostring(shown))
        end
    end
    self.filling = false
end

function Properties:edited(row, column)
    if self.filling or column ~= 2 then return end
    local r = self.rows[row]
    if not r or r.kind == "boolean" or r.kind == "enum" or r.kind == "readonly" then return end

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
    r.apply(value)
end

return Properties
