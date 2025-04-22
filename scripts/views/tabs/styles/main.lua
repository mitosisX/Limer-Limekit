appTabLightStyle = [[
Tab {
    background: white;
    border: none;
}

Tab:tab-bar{
    alignment: center;
}

/* Tab Bar */
QTabBar {
    background: transparent;
    border: none;
}

/* Individual Tabs */
QTabBar::tab {
    background: #f5f5f5;
    color: #555;
    padding: 8px 16px;
    border-top-left-radius: 4px;
    border-top-right-radius: 4px;
    margin-right: 4px;
    font-size: 12px;
    min-width: 120px;
    border: 1px solid #e0e0e0;
    border-bottom: none;
}

/* Selected Tab */
QTabBar::tab:selected {
    background: white;
    color: #0066cc;
    border-bottom: 2px solid #0066cc;
    font-weight: 500;
}

/* Hovered Tab */
QTabBar::tab:hover {
    background: #e8e8e8;
}

/* Tab Widget Pane (content area) */
Tab::pane {
    border-top: 1px solid #e0e0e0;
    background: white;
    margin-top: -1px;  /* Align with tab bar */
}
]]

appTabDarkStyle=[[
/* Tab Widget */
Tab {
    background: #2d2d2d;
    border: none;
}

Tab:tab-bar{
    alignment: center;
}

/* Tab Bar */
QTabBar {
    background: transparent;
    border: none;
}

/* Individual Tabs */
QTabBar::tab {
    background: #3a3a3a;
    color: #b0b0b0;
    padding: 8px 16px;
    border-top-left-radius: 4px;
    border-top-right-radius: 4px;
    margin-right: 4px;
    font-size: 12px;
    min-width: 120px;
    border: 1px solid #444;
    border-bottom: none;
}

/* Selected Tab */
QTabBar::tab:selected {
    background: #2d2d2d;
    color: #4a9cff;
    border-bottom: 2px solid #4a9cff;
    font-weight: 500;
}

/* Hovered Tab */
QTabBar::tab:hover {
    background: #454545;
}

/* Tab Widget Pane (content area) */
Tab::pane {
    border-top: 1px solid #444;
    background: #2d2d2d;
    margin-top: -1px;  /* Align with tab bar */
}
]]