-- Catalog
-- The properties the designer offers for each widget: the ones a person
-- designing a window actually sets, not every property the widget declares.
--
-- Introspection lists what a class *has* -- for most widgets that is
-- enabled, styleSheet and toolTip, while the setters that matter (a
-- LineEdit's hint, a Spinner's range, a ComboBox's items) are methods it
-- cannot see. So the list is written down here instead, one line per
-- property, by the setter's name: `hint` is set with setHint.
--
-- Each entry: { name, kind, options }. Kinds:
--   string, int, float, bool   one value
--   enum                       one of `options`
--   colour                     a colour name or #rrggbb
--   list                       several strings, edited one per row in the
--                              list editor (gui/modals/list_editor.lua);
--                              stored as a table, generated as setItems({ ... })
--   pair                       two numbers, typed "0, 100"; stored as
--                              { args = { 0, 100 } }, generated as setRange(0, 100)
--   date                       typed "2026-10-22"; stored as { args = { 2026, 10, 22 } },
--                              generated as setDate(2026, 10, 22)
--   time                       typed "14:30" or "14:30:15"; stored and spread the same
--                              way, as setTime(14, 30, 0)
--
-- Only setters Limekit itself defines can be listed. Qt's own methods --
-- QDateEdit's setCalendarPopup, say -- are not reachable with Lua's colon
-- syntax, so generated code calling one would fail where the canvas did not.
--
-- A class missing from the table falls back to what introspection finds.

local Catalog = {}

local ALIGN = { "left", "center", "right", "justify", "hcenter", "vcenter", "top", "bottom" }
local ORIENT = { "horizontal", "vertical" }

Catalog.CLASSES = {
    ["ui.Button"] = {
        { "text", "string" }, { "flat", "bool" }, { "checkable", "bool" }, { "checked", "bool" },
    },
    ["ui.CommandButton"] = { { "text", "string" }, { "description", "string" } },
    ["ui.CheckBox"] = { { "text", "string" }, { "checked", "bool" } },
    ["ui.RadioButton"] = { { "text", "string" }, { "checked", "bool" } },
    ["ui.Label"] = {
        { "text", "string" }, { "wordWrap", "bool" }, { "textAlignment", "enum", ALIGN },
        { "bold", "bool" }, { "textSize", "int" }, { "textColor", "colour" },
    },
    ["ui.LineEdit"] = {
        { "text", "string" }, { "hint", "string" }, { "readOnly", "bool" },
        { "inputMode", "enum", { "normal", "password", "passwordonedit", "hideinput" } },
    },
    ["ui.TextField"] = {
        { "plainText", "string" }, { "hint", "string" }, { "readOnly", "bool" },
        { "wrapMode", "enum", { "widget", "none" } },
    },
    ["ui.ComboBox"] = { { "items", "list" }, { "currentIndex", "int" }, { "editable", "bool" } },
    ["ui.Spinner"] = { { "range", "pair" }, { "value", "int" }, { "prefix", "string" }, { "suffix", "string" } },
    ["ui.DoubleSpinner"] = { { "range", "pair" }, { "value", "float" }, { "prefix", "string" }, { "suffix", "string" } },
    ["ui.Slider"] = {
        { "range", "pair" }, { "value", "int" }, { "orientation", "enum", ORIENT },
        { "tickPosition", "enum", { "none", "above", "below", "bothsides", "left", "right" } },
    },
    ["ui.AdvancedSlider"] = { { "range", "pair" }, { "value", "float" }, { "prefix", "string" }, { "suffix", "string" } },
    ["ui.Knob"] = { { "range", "pair" }, { "value", "int" }, { "notchesVisible", "bool" } },
    ["ui.ProgressBar"] = { { "range", "pair" }, { "value", "int" }, { "orientation", "enum", ORIENT } },
    ["ui.LCDNumber"] = {
        { "digitCount", "int" }, { "value", "float" }, { "segmentStyle", "enum", { "filled", "flat", "outline" } },
    },
    ["ui.Calendar"] = { { "date", "date" }, { "gridVisible", "bool" } },
    ["ui.DatePicker"] = { { "date", "date" } },
    ["ui.TimePicker"] = { { "time", "time" } },
    ["ui.Image"] = { { "imageSize", "pair" }, { "imageAlignment", "enum", ALIGN } },
    ["ui.GroupBox"] = { { "title", "string" }, { "checkable", "bool" }, { "checked", "bool" }, { "flat", "bool" } },
    ["ui.Tab"] = {
        { "tabPosition", "enum", { "top", "bottom", "left", "right" } },
        { "movable", "bool" }, { "tabsClosable", "bool" },
    },
    ["ui.Splitter"] = { { "orientation", "enum", ORIENT }, { "handleWidth", "int" } },
    ["ui.Scroller"] = { { "resizable", "bool" } },
    ["ui.ListBox"] = { { "items", "list" } },
    -- A Table's titles, row count and cells are its contents, edited
    -- together in the table editor (Properties' "contents" row), so they
    -- are not listed here one setter at a time.
    ["ui.Table"] = {
        { "showGrid", "bool" }, { "alternatingRowColors", "bool" }, { "stretchLastColumn", "bool" },
    },
    ["ui.TreeView"] = { { "headerLabels", "list" }, { "headerHidden", "bool" } },
    ["ui.Container"] = {},
    ["ui.Accordion"] = {},
    -- Lines are only drawn: nothing to set but what every widget has.
    ["ui.HLine"] = {},
    ["ui.VLine"] = {},
    ["ui.Separator"] = {},
}
Catalog.CLASSES["ui.TreeWidget"] = Catalog.CLASSES["ui.TreeView"]
Catalog.CLASSES["ui.FontComboBox"] = { { "editable", "bool" } }

-- Every widget, after its own: how it sizes and what it says on hover.
Catalog.COMMON = {
    { "toolTip", "string" }, { "enabled", "bool" },
    { "minWidth", "int" }, { "minHeight", "int" }, { "maxWidth", "int" }, { "maxHeight", "int" },
}

--- The entries for a class, or nil when it has none written down.
function Catalog.forClass(class)
    return Catalog.CLASSES[class]
end

--- The first list a class holds -- a ComboBox's items, a TreeView's header
--- labels -- or nil: what a double-click on the canvas opens the editor for.
function Catalog.listProp(class)
    for _, entry in ipairs(Catalog.CLASSES[class] or {}) do
        if entry[2] == "list" then return entry[1] end
    end
    return nil
end

-- PARSING AND SHOWING VALUES ---------------------------------------------------

--- What a stored value looks like in its cell.
function Catalog.show(kind, value)
    if value == nil then return "" end
    if kind == "list" and type(value) == "table" then return table.concat(value, ", ") end
    if kind == "date" and type(value) == "table" and value.args then
        local a = value.args
        return ("%04d-%02d-%02d"):format(a[1] or 0, a[2] or 0, a[3] or 0)
    end
    if kind == "time" and type(value) == "table" and value.args then
        local a = value.args
        return ("%02d:%02d:%02d"):format(a[1] or 0, a[2] or 0, a[3] or 0)
    end
    if kind == "pair" and type(value) == "table" then
        local a = value.args or value
        return tostring(a[1] or "") .. ", " .. tostring(a[2] or "")
    end
    return tostring(value)
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--- The value typed into a cell, or nil and a reason if it does not parse.
--- Empty text means "not set" and returns false (distinct from nil).
function Catalog.parse(kind, text)
    text = trim(text or "")
    if text == "" then return false end
    if kind == "int" then
        local n = math.tointeger(tonumber(text))
        if not n then return nil, "a whole number" end
        return n
    elseif kind == "float" then
        local n = tonumber(text)
        if not n then return nil, "a number" end
        return n
    elseif kind == "list" then
        local items = {}
        for part in (text .. ","):gmatch("([^,]*),") do
            part = trim(part)
            if part ~= "" then items[#items + 1] = part end
        end
        return items
    elseif kind == "date" then
        local y, m, d = text:match("^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)$")
        y, m, d = tonumber(y), tonumber(m), tonumber(d)
        if not y or m < 1 or m > 12 or d < 1 or d > 31 then
            return nil, "a date, like 2026-10-22"
        end
        return { args = { y, m, d } }
    elseif kind == "time" then
        local h, mi, sec = text:match("^(%d%d?):(%d%d)$")
        if not h then h, mi, sec = text:match("^(%d%d?):(%d%d):(%d%d)$") end
        h, mi, sec = tonumber(h), tonumber(mi), tonumber(sec) or 0
        if not h or h > 23 or mi > 59 or sec > 59 then
            return nil, "a time, like 14:30 or 14:30:15"
        end
        return { args = { h, mi, sec } }
    elseif kind == "pair" then
        local a, b = text:match("^(%-?[%d.]+)%s*[,;%s]%s*(%-?[%d.]+)$")
        a, b = tonumber(a), tonumber(b)
        if not a or not b then return nil, "two numbers, like 0, 100" end
        return { args = { math.tointeger(a) or a, math.tointeger(b) or b } }
    end
    return text
end

return Catalog
