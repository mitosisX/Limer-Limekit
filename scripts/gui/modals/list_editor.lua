-- List editor
-- A list of strings -- a ComboBox's or ListBox's items, a TreeView's
-- column titles -- edited one item per row, in a dialog of its own.
--
-- These used to be typed into a single Properties cell, comma-separated.
-- That way an item could never hold a comma, a list of any length could
-- not be read back, and nothing could be put in a different order without
-- retyping it.

local ui = require("limekit.ui")

local ListEditor = {}

-- The text in a cell. Every cell is filled with setCellText before it can
-- be typed into, so it holds a ui.TableItem; the fallback is for one that
-- somehow holds Qt's own item, which has text() and not getText().
local function cellText(t, row, column)
    local item = t:getCellItem(row, column)
    if not item then return "" end
    local ok, text = pcall(function() return item:getText() end)
    if not ok then ok, text = pcall(function() return item:text() end) end
    return ok and text and tostring(text) or ""
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

--- Opens the editor over `parent` and waits for it to close. Returns the
--- edited list -- trimmed, blank rows left out -- or nil if it was
--- cancelled or nothing changed.
function ListEditor.open(parent, title, items)
    local original = {}
    for i, item in ipairs(items or {}) do original[i] = tostring(item) end
    local result = nil

    local modal = ui.Modal(title, parent)
    modal:setMinSize(420, 460)

    local main = ui.VLayout()
    main:setMargins(14, 14, 14, 12)
    main:setSpacing(8)

    local hint = ui.Label("One item per row. Double-click a row to change it; blank rows are left out.")
    hint:setWordWrap(true)
    hint:setTextColor("#6B7280")
    main:addChild(hint)

    local list = ui.Table()
    list:setColumnHeaders({ "Item" })
    list:setStretchLastColumn(true)
    list:setCellsEditable(true)
    list:setSelectionBehavior("rows")

    local function texts()
        local out = {}
        for r = 1, list:getRowCount() do out[r] = cellText(list, r, 1) end
        return out
    end

    -- Every row gets a cell, so typing into any of them edits a TableItem.
    local function fill(values, current)
        list:setRowCount(#values)
        for r, text in ipairs(values) do list:setCellText(r, 1, text) end
        if current and current >= 1 and current <= #values then list:setCurrentCell(current, 1) end
    end
    fill(original)
    main:addChild(list, 1)

    -- Add, remove and reorder, beside a way to type the whole list at once.
    local tools = ui.HLayout()
    tools:setSpacing(6)
    local function tool(text, tip, handler)
        local b = ui.Button(text)
        b:setToolTip(tip)
        b:setOnClick(handler)
        tools:addChild(b)
        return b
    end

    tool("Add", "A new row after the selected one", function()
        local values = texts()
        local at = list:getCurrentRow()
        local index = at >= 1 and at + 1 or #values + 1
        table.insert(values, index, "")
        fill(values, index)
    end)
    tool("Remove", "Remove the selected row", function()
        local values = texts()
        local at = list:getCurrentRow()
        if at < 1 or at > #values then return end
        table.remove(values, at)
        fill(values, math.min(at, #values))
    end)
    tool("Up", "Move the selected row up", function()
        local values = texts()
        local at = list:getCurrentRow()
        if at < 2 or at > #values then return end
        values[at - 1], values[at] = values[at], values[at - 1]
        fill(values, at - 1)
    end)
    tool("Down", "Move the selected row down", function()
        local values = texts()
        local at = list:getCurrentRow()
        if at < 1 or at >= #values then return end
        values[at + 1], values[at] = values[at], values[at + 1]
        fill(values, at + 1)
    end)
    tools:addStretch()
    tool("Edit as text...", "Type or paste the whole list, one item per line", function()
        local text = ui.Dialogs.multilineInput(modal, title, "One item per line:", table.concat(texts(), "\n"))
        if text == nil then return end
        local values = {}
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            values[#values + 1] = (line:gsub("\r$", ""))
        end
        -- The last line of pasted text usually ends with a newline of its own.
        if #values > 0 and values[#values] == "" then values[#values] = nil end
        fill(values)
    end)
    main:addLayout(tools)

    local buttons = ui.HLayout()
    buttons:setSpacing(8)
    buttons:addStretch()
    local cancel = ui.Button("Cancel")
    cancel:setOnClick(function() modal:dismiss() end)
    buttons:addChild(cancel)
    local ok = ui.Button("OK")
    ok:setOnClick(function()
        local values = {}
        for _, text in ipairs(texts()) do
            text = trim(text)
            if text ~= "" then values[#values + 1] = text end
        end
        result = values
        modal:dismiss()
    end)
    buttons:addChild(ok)
    main:addLayout(buttons)

    modal:setLayout(main)
    modal:open()

    if result == nil or same(result, original) then return nil end
    return result
end

return ListEditor
