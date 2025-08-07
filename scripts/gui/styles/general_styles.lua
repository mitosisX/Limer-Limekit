local GENERAL_STYLES = [[
ListBox {
    selection-background-color: #3465a4;
    selection-color: white;
}

ListBox::item:selected {
    background-color: #3465a4;
    color: white;
}

LineEdit {
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 14px;
}

MenuBar {
    background-color: #202124;
    padding: 4px;
}

Menubar {
    padding: 4px;
}

Menubar::item {
    padding: 4px 8px;
    background: transparent;
    border-radius: 4px;
}

Button {
    border: 1px solid #c1c1c1;
    border-radius: 4px;
    padding: 4px 8px;
    min-width: 80px;
}

Button:flat {
    border: none;
}
]]

return { GENERAL_STYLES = GENERAL_STYLES }
