-- Table editor
-- What a Table holds -- its column titles, its rows, and the text in every
-- cell -- edited as one grid in a dialog of its own.
--
-- The grid's first row is the column titles and every row under it is a
-- row of the table, so the shape of the table and what is in it are
-- edited in the one place. Before this, Properties could give a Table its
-- titles and a row count, and nothing could put text in a single cell.

local ui = require("limekit.ui")

local TableEditor = {}

-- The titles row, set apart from the rows under it. Translucent, so it
-- reads in both themes -- the same band Properties uses for its sections.
local TITLES_BACKGROUND = "#3a808080"

-- See list_editor.lua: every cell is filled before it can be typed into.
local function cellText(t, row, column)
    local item = t:getCellItem(row, column)
    if not item then return "" end
    local ok, text = pcall(function() return item:getText() end)
    if not ok then ok, text = pcall(function() return item:text() end) end
    return ok and text and tostring(text) or ""
end

-- A, B ... Z, AA, AB: what the grid calls its columns, so "column 3" is
-- never confused with whatever the table's own third title says.
local function letters(n)
    local out = ""
    while n > 0 do
        local rem = (n - 1) % 26
        out = string.char(65 + rem) .. out
        n = (n - 1 - rem) // 26
    end
    return out
end

local function copy(contents)
    local headers, rows = {}, {}
    for c, title in ipairs(contents.headers or {}) do headers[c] = tostring(title) end
    for r, row in ipairs(contents.rows or {}) do
        rows[r] = {}
        for c, text in ipairs(row) do rows[r][c] = tostring(text) end
    end
    return { headers = headers, rows = rows }
end

local function sameContents(a, b)
    if #a.headers ~= #b.headers or #a.rows ~= #b.rows then return false end
    for c = 1, #a.headers do if a.headers[c] ~= b.headers[c] then return false end end
    for r = 1, #a.rows do
        if #a.rows[r] ~= #b.rows[r] then return false end
        for c = 1, #a.rows[r] do if a.rows[r][c] ~= b.rows[r][c] then return false end end
    end
    return true
end

--- Opens the editor over `parent` with `contents` -- { headers, rows }, as
--- DesignModel.tableContents gives it -- and waits for it to close.
--- Returns the edited contents, or nil if it was cancelled or nothing
--- changed.
function TableEditor.open(parent, title, contents)
    -- A table with no columns yet starts with one, or there would be no
    -- cell to type into.
    local original = copy(contents or {})
    if #original.headers == 0 then
        original.headers[1] = ""
        for _, row in ipairs(original.rows) do row[1] = row[1] or "" end
    end
    local result = nil

    local modal = ui.Modal(title, parent)
    modal:setMinSize(620, 480)

    local main = ui.VLayout()
    main:setMargins(14, 14, 14, 12)
    main:setSpacing(8)

    local hint = ui.Label("The first row is the column titles; every row under it is a row of the table. "
        .. "Double-click a cell to type into it. Untitled columns are fine -- the table numbers them.")
    hint:setWordWrap(true)
    hint:setTextColor("#6B7280")
    main:addChild(hint)

    local grid = ui.Table()
    grid:setCellsEditable(true)

    -- The grid's rows are the titles, then the table's rows; its columns
    -- are the table's columns.
    local function read()
        local headers, rows = {}, {}
        local columns, total = grid:getColumnCount(), grid:getRowCount()
        for c = 1, columns do headers[c] = cellText(grid, 1, c) end
        for r = 2, total do
            local row = {}
            for c = 1, columns do row[c] = cellText(grid, r, c) end
            rows[#rows + 1] = row
        end
        return { headers = headers, rows = rows }
    end

    local function fill(data, focusRow, focusColumn)
        local columns = #data.headers
        local names = {}
        for c = 1, columns do names[c] = letters(c) end
        grid:setColumnHeaders(names)
        grid:setRowCount(#data.rows + 1)
        local rowNames = { "Titles" }
        for r = 1, #data.rows do rowNames[r + 1] = tostring(r) end
        grid:setRowHeaders(rowNames)
        for c = 1, columns do
            grid:setCellText(1, c, data.headers[c] or "")
            local item = grid:getCellItem(1, c)
            if item then item:setBackgroundColour(TITLES_BACKGROUND) end
        end
        for r, row in ipairs(data.rows) do
            for c = 1, columns do grid:setCellText(r + 1, c, row[c] or "") end
        end
        if focusRow and focusColumn then
            grid:setCurrentCell(math.max(1, math.min(focusRow, #data.rows + 1)),
                                math.max(1, math.min(focusColumn, columns)))
        end
    end
    fill(original)
    main:addChild(grid, 1)

    local status = ui.Label("")
    status:setTextColor("#6B7280")

    -- Where the grid's cursor is, as a row of the table (0 for the titles
    -- row or nowhere) and a column.
    local function cursor()
        return grid:getCurrentRow() - 1, grid:getCurrentColumn()
    end

    local tools = ui.HLayout()
    tools:setSpacing(6)
    local function tool(text, tip, handler)
        local b = ui.Button(text)
        b:setToolTip(tip)
        b:setOnClick(function() status:setText(""); handler() end)
        tools:addChild(b)
        return b
    end

    tool("Add row", "A new row after the selected one", function()
        local data = read()
        local row = cursor()
        local index = (row >= 1 and row <= #data.rows) and row + 1 or #data.rows + 1
        local blank = {}
        for c = 1, #data.headers do blank[c] = "" end
        table.insert(data.rows, index, blank)
        fill(data, index + 1, 1)
    end)
    tool("Remove row", "Remove the selected row", function()
        local data = read()
        local row, column = cursor()
        if row < 1 or row > #data.rows then
            status:setText("select a row of the table -- the titles row stays")
            return
        end
        table.remove(data.rows, row)
        fill(data, math.max(2, math.min(row + 1, #data.rows + 1)), column)
    end)
    tool("Add column", "A new column after the selected one", function()
        local data = read()
        local _, column = cursor()
        local index = (column >= 1 and column <= #data.headers) and column + 1 or #data.headers + 1
        table.insert(data.headers, index, "")
        for _, r in ipairs(data.rows) do table.insert(r, index, "") end
        fill(data, 1, index)
    end)
    tool("Remove column", "Remove the selected column", function()
        local data = read()
        local row, column = cursor()
        if #data.headers <= 1 then
            status:setText("a table keeps at least one column")
            return
        end
        if column < 1 or column > #data.headers then
            status:setText("select a cell in the column to remove")
            return
        end
        table.remove(data.headers, column)
        for _, r in ipairs(data.rows) do table.remove(r, column) end
        fill(data, row + 1, math.min(column, #data.headers))
    end)
    tools:addStretch()
    tools:addChild(status)
    main:addLayout(tools)

    local buttons = ui.HLayout()
    buttons:setSpacing(8)
    buttons:addStretch()
    local cancel = ui.Button("Cancel")
    cancel:setOnClick(function() modal:dismiss() end)
    buttons:addChild(cancel)
    local ok = ui.Button("OK")
    ok:setOnClick(function()
        result = read()
        modal:dismiss()
    end)
    buttons:addChild(ok)
    main:addLayout(buttons)

    modal:setLayout(main)
    modal:open()

    if result == nil or sameContents(result, original) then return nil end
    return result
end

return TableEditor
