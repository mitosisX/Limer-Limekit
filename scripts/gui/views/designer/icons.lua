-- Icons
-- Which picture stands for which widget, in the palette and the outline,
-- and the designer's own toolbar icons. One table, so the two lists can
-- never disagree about what a Button looks like.

local res = require("limekit.res")

local Icons = {}

-- Class name -> file in images/widgets. Several widgets share a picture
-- where Limer has no closer one.
local WIDGETS = {
    Container = "VLayout", GroupBox = "GroupBox", Scroller = "Scroller",
    Splitter = "splitter", Tab = "Tab", Accordion = "Accordion",
    Button = "Button", CommandButton = "ToggleButton", CheckBox = "CheckBox",
    RadioButton = "RadioButton", ButtonGroup = "ButtonGroup",
    LineEdit = "LineEdit", TextField = "TextField",
    ComboBox = "ComboBox", FontComboBox = "ComboBox",
    Spinner = "Spinner", DoubleSpinner = "Spinner",
    Slider = "Slider", AdvancedSlider = "Slider", Knob = "Slider",
    DatePicker = "DateTimePicker", TimePicker = "TimePicker", Calendar = "Calendar",
    Label = "label", Image = "display", GifPlayer = "display",
    ProgressBar = "ProgressBar", LCDNumber = "LCD",
    HLine = "line", VLine = "line", Separator = "line",
    ListBox = "ListBox", Table = "Table", TreeView = "ListBox", TreeWidget = "ListBox",
}

-- Layouts have pictures of their own, so a container shows how it lays out.
local LAYOUTS = {
    ["ui.VLayout"] = "VLayout", ["ui.HLayout"] = "HLayout",
    ["ui.GridLayout"] = "gridlayout", ["ui.FormLayout"] = "FormLayout",
}

-- The widget icons are black line art; images/widgets-dark holds copies
-- redrawn light for the dark theme.
local function widgetImage(file)
    local Theme = require "app.core.theme"
    local folder = Theme.active == "dark" and "widgets-dark/" or "widgets/"
    return res.Resources.images(folder .. file .. ".png")
end

--- The icon path for a class such as "ui.Button", or a palette layout
--- entry such as "layout:ui.HLayout"; nil if there is none.
function Icons.forClass(class)
    local layout = class:match("^layout:(.+)$")
    if layout then return LAYOUTS[layout] and widgetImage(LAYOUTS[layout]) or nil end
    local file = WIDGETS[class:match("%.(.+)$") or class]
    return file and widgetImage(file) or nil
end

--- The icon path for a design node. A plain container shows its layout.
function Icons.forNode(node)
    if node.kind then return nil end
    if node.class == "ui.Container" and LAYOUTS[node.layout] then
        return widgetImage(LAYOUTS[node.layout])
    end
    return Icons.forClass(node.class)
end

--- {["ui.Button"] = path, ...} for every class given.
function Icons.mapFor(classes)
    local map = {}
    for _, class in ipairs(classes) do map[class] = Icons.forClass(class) end
    return map
end

--- One of the designer's toolbar icons, from images/designer.
function Icons.tool(name)
    return res.Resources.images("designer/" .. name .. ".svg")
end

return Icons
