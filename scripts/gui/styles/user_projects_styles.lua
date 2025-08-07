-- Holds themes for the ListBox that holds all user project

local PROJECT_LISTBOX_LIGHT = [[
/* List widget styling */
ListBox {
    background-color: transparent;
    border: none;
    outline: none;
    font-size: 14px;
    color: #333;
    padding: 8px;
}

/* Item styling - modern card look */
ListBox::item {

    border-radius: 8px;
    padding: 10px 12px;
    border: 1px solid #e0e3e7;
}

/* Hover effect */
ListBox::item:hover {
    background-color: #f1f5f9;
    border: 1px solid #cbd5e1;
}

/* Selected item */
ListBox::item:selected {
    background-color: #e0f2fe;
    color: #0369a1;
    border: 1px solid #7dd3fc;
}

/* Scrollbar styling */
Scroller:vertical {
    border: none;
    background-color: #f1f5f9;
    width: 8px;
    margin: 0px;
}

Scroller::handle:vertical {
    background-color: #cbd5e1;
    border-radius: 4px;
    min-height: 20px;
}

Scroller::add-line:vertical,
Scroller::sub-line:vertical {
    height: 0px;
}
]]

local PROJECT_LISTBOX_DARK  = [[
ListBox {
    background-color: transparent;
    border: none;
    outline: none;
    font-size: 14px;
    color: #e0e0e0;
    padding: 8px;
}

ListBox::item {
    background-color: #2d2d2d;
    border-radius: 8px;
    padding: 10px 12px;
    border: 1px solid #444;
}

ListBox::item:hover {
    background-color: #3d3d3d;
    border: 1px solid #555;
}

ListBox::item:selected {
    background-color: #1e3a8a;
    color: #ffffff;
    border: 1px solid #3b82f6;
}

QScrollBar:vertical {
    border: none;
    background-color: #2d2d2d;
    width: 8px;
    margin: 0px;
}

QScrollBar::handle:vertical {
    background-color: #555;
    border-radius: 4px;
    min-height: 20px;
}
]]

return { PROJECT_LISTBOX_LIGHT = PROJECT_LISTBOX_LIGHT, PROJECT_LISTBOX_DARK = PROJECT_LISTBOX_DARK }
