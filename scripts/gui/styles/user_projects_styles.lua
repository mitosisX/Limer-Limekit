-- User Projects Styles
-- Theme styles for the projects list (light and dark themes)
--
-- A compact list -- an icon and a name per row -- rather than a stack of
-- bordered cards. Cards with 10px padding and a 14px font took a dock's
-- whole width for a single letter of a name, and were the first thing to be
-- clipped when the window narrowed.

local PROJECT_LISTBOX_LIGHT = [[
ListBox {
    background-color: transparent;
    border: none;
    outline: none;
    font-size: 13px;
    color: #1f2933;
    padding: 4px;
}

ListBox::item {
    border: none;
    border-radius: 6px;
    padding: 3px 6px;
    margin: 0px;
}

ListBox::item:hover {
    background-color: #eef2f7;
}

ListBox::item:selected {
    background-color: #dbeafe;
    color: #1d4ed8;
    border-left: 3px solid #2563eb;
}

QScrollBar:vertical {
    border: none;
    background: transparent;
    width: 8px;
    margin: 0px;
}

QScrollBar::handle:vertical {
    background-color: #cbd5e1;
    border-radius: 4px;
    min-height: 24px;
}

QScrollBar::add-line:vertical,
QScrollBar::sub-line:vertical {
    height: 0px;
}
]]

local PROJECT_LISTBOX_DARK = [[
ListBox {
    background-color: transparent;
    border: none;
    outline: none;
    font-size: 13px;
    color: #e5e7eb;
    padding: 4px;
}

ListBox::item {
    border: none;
    border-radius: 6px;
    padding: 3px 6px;
    margin: 0px;
}

ListBox::item:hover {
    background-color: #2f3337;
}

ListBox::item:selected {
    background-color: #1e3a5f;
    color: #ffffff;
    border-left: 3px solid #3b82f6;
}

QScrollBar:vertical {
    border: none;
    background: transparent;
    width: 8px;
    margin: 0px;
}

QScrollBar::handle:vertical {
    background-color: #4b5563;
    border-radius: 4px;
    min-height: 24px;
}

QScrollBar::add-line:vertical,
QScrollBar::sub-line:vertical {
    height: 0px;
}
]]

return { PROJECT_LISTBOX_LIGHT = PROJECT_LISTBOX_LIGHT, PROJECT_LISTBOX_DARK = PROJECT_LISTBOX_DARK }
