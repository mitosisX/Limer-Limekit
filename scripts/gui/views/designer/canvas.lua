-- Canvas
-- The model, built as real widgets on a ui.DesignSurface.
--
-- Rebuilt whole after every change rather than patched, because a canvas
-- edited in place drifts from the model that is about to generate the
-- file. The surface reports selections and drops as widgets; this module
-- turns them back into model nodes for the view.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"
local Images = require "app.core.images"

local Canvas = {}
Canvas.__index = Canvas

--- onDrop({ kind = "class", class, target, slot }) or
--- onDrop({ kind = "move", node, target, slot }); onSelect(node or nil);
--- onImage(node, slot, key) when an image is dragged onto a widget --
--- slot is "window icon" for the root.
function Canvas.new(surface, onDrop, onSelect, onImage)
    -- formLabels: the label a form row shows, built here as a ui.Label rather
    -- than left for Qt to make, so it can be hovered, clicked and renamed.
    -- It stands for the field it labels -- clicking it selects the field,
    -- dragging it moves the field -- but is not that field's widget.
    local self = setmetatable({ surface = surface, widgetOf = {}, nodeOf = {}, formLabels = {} }, Canvas)

    surface:setOnImageDrop(function(widget, relPath)
        local node = self.nodeOf[widget]
        local key = Images.keyFor(relPath)
        if not node or not key or not onImage then return end
        local slot = node == self.root and "window icon" or DesignModel.imageSlots(node.class)[1]
        if slot then onImage(node, slot, key) end
    end)

    surface:setOnSelect(function(widget)
        onSelect(self:nodeFor(widget))
    end)

    surface:setOnDrop(function(drop)
        local target = self.nodeOf[drop.target]
        if not target then return end
        local slot = { index = drop.index, row = drop.row, column = drop.column }
        if drop.kind == "class" then
            onDrop({ kind = "class", class = drop.class, target = target, slot = slot })
        else
            local node = self:nodeFor(drop.widget)
            -- Everything travelling, when several were selected: `nodes`, in
            -- design order, the held one among them.
            local nodes = {}
            for _, widget in ipairs(drop.widgets or {}) do
                local n = self:nodeFor(widget)
                if n then nodes[#nodes + 1] = n end
            end
            if node then
                onDrop({ kind = "move", node = node, nodes = #nodes > 1 and nodes or nil,
                         target = target, slot = slot })
            end
        end
    end)

    return self
end

local function className(class)
    return class:match("%.(.+)$") or class
end

--- Sets one property the way the generated code will: through the
--- declared property if there is one, else the plain setter (minWidth and
--- minHeight are methods, not declared properties). Returns ok, result.
function Canvas.apply(widget, name, value)
    if type(value) ~= "table" then
        local ok, result = pcall(sys.Introspect.setProperty, widget, name, value)
        if ok then return true, result end
    end
    local found, setter = pcall(function() return widget["set" .. name:sub(1, 1):upper() .. name:sub(2)] end)
    if not found or (type(setter) ~= "function" and type(setter) ~= "userdata") then
        return false, "no property " .. name
    end
    -- { args = { 0, 100 } } is spread: setRange(0, 100). A plain list is
    -- one argument: setItems({ "A", "B" }).
    local called, err
    if type(value) == "table" and value.args then
        called, err = pcall(setter, widget, table.unpack(value.args))
    else
        called, err = pcall(setter, widget, value)
    end
    if not called then return false, tostring(err) end
    return true, value
end

-- A widget that could not be built still needs a place on the canvas, or
-- the node it stands for could never be selected and deleted.
local function placeholder(node, err)
    local label = ui.Label(("%s failed: %s"):format(node.class, tostring(err)))
    label:setStyleSheet("color: #d32f2f; border: 1px dashed #d32f2f; padding: 4px;")
    label:setWordWrap(true)
    return label
end

function Canvas:build(node)
    local ctor = ui[className(node.class)]
    local ok, widget = pcall(function()
        if type(ctor) ~= "function" and type(ctor) ~= "table" and type(ctor) ~= "userdata" then
            error("no such class")
        end
        return ctor()
    end)
    if ok and widget ~= nil then
        node.buildError = nil
    else
        node.buildError = tostring(widget)
        widget = placeholder(node, widget)
        ok = false
    end

    -- Images first, as the generated code sets them: an Image's size means
    -- nothing -- and raises -- before it has a picture. Images are named, not
    -- pathed; the name is looked up in the project's images now, so a moved
    -- file still shows.
    for slot, key in pairs(node.images or {}) do
        local path = Images.path(key)
        if path then Canvas.apply(widget, slot, path) end
    end
    for name, value in pairs(node.props or {}) do
        Canvas.apply(widget, name, value)
    end
    -- A Table's cells, once the props above have given it its rows and
    -- columns -- in the same order the generated code sets them.
    if ok then
        for r, row in ipairs(node.cells or {}) do
            for c, text in ipairs(row) do
                if text ~= "" then pcall(function() widget:setCellText(r, c, text) end) end
            end
        end
    end
    self.widgetOf[node], self.nodeOf[widget] = widget, node

    if ok and DesignModel.isContainer(node) and not DesignModel.hasLayout(node) then
        -- Tab, Splitter, Scroller: children go in their own way.
        local kind = node.layout
        for _, child in ipairs(node.children) do
            local built = self:build(child)
            if kind == "tab" then
                widget:addTab(built, (child.tab or {}).title or "")
            elseif kind == "splitter" then
                widget:addChild(built)
            else
                widget:setChild(built)
            end
        end
        if #node.children == 0 then
            widget:setMinHeight(64)
            widget:setMinWidth(96)
        end
    elseif ok and DesignModel.isContainer(node) then
        local layout = ui[className(node.layout)]()
        local kind = DesignModel.layoutKind(node.layout)
        for _, child in ipairs(node.children) do
            if child.kind == "stretch" then
                layout:addStretch(child.stretch or 1)
            elseif child.kind == "spacing" then
                layout:addSpacing(child.size or 0)
            else
                local built = self:build(child)
                if kind == "grid" then
                    local g = child.grid
                    layout:addChild(built, g.row, g.column, g.rowSpan or 1, g.columnSpan or 1)
                elseif kind == "form" then
                    local title = ui.Label((child.form or {}).label or "")
                    self.formLabels[title] = child
                    layout:addChild(title, built)
                else
                    layout:addChild(built, child.stretch or 0)
                end
                -- Where it sits in its slot, as the generated code will say.
                local names = DesignModel.alignmentNames(child)
                if #names > 0 then
                    pcall(function() layout:setChildAlignment(built, table.unpack(names)) end)
                end
            end
        end
        -- An empty container has no size of its own, and a target with no
        -- area cannot be dropped on.
        if #node.children == 0 then
            widget:setMinHeight(48)
            widget:setMinWidth(48)
        end
        widget:setLayout(layout)
    end
    return widget
end

function Canvas:rebuild(design)
    self.widgetOf, self.nodeOf, self.formLabels = {}, {}, {}
    self.root = design.root
    local root = self:build(design.root)
    root:setFixedSize(design.window.width, design.window.height)
    -- Labels go on after setDesignChild, which forgets the old design's.
    self.surface:setDesignChild(root)
    for widget, node in pairs(self.nodeOf) do self:label(widget, node) end
    for title, node in pairs(self.formLabels) do
        self.surface:setWidgetLabel(title, node.name .. " · label")
    end
    -- Every widget built above is new and therefore still interactive; the
    -- surface has to be told before the next click reaches one of them.
    self.surface:refresh()
end

--- The name on the surface's hover, selection and drag tags: "ok · Button",
--- or for a laid-out container what it lays out as, "buttons · Row".
function Canvas:label(widget, node)
    local kind = className(node.class)
    if DesignModel.hasLayout(node) then
        local word = DesignModel.LAYOUT_WORDS[node.layout] or kind
        kind = word:sub(1, 1):upper() .. word:sub(2)
    end
    if node.locked then kind = kind .. " · locked" end
    self.surface:setWidgetLabel(widget, node.name .. " · " .. kind)
    -- Where an image dragged from the images manager can land: the
    -- widget's first image slot, or for the root, the window's icon.
    local slot = DesignModel.imageSlots(node.class)[1]
    if node == self.root then slot = "window icon" end
    if slot then self.surface:setImageTarget(widget, slot) end
end

function Canvas:widgetFor(node) return node and self.widgetOf[node] or nil end

--- The node a widget on the canvas stands for. A form row's label stands
--- for the field it labels.
function Canvas:nodeFor(widget)
    if not widget then return nil end
    return self.nodeOf[widget] or self.formLabels[widget]
end

--- True if the widget is a form row's label rather than a widget of its own.
function Canvas:isFormLabel(widget)
    return widget ~= nil and self.formLabels[widget] ~= nil
end

function Canvas:select(node)
    self.surface:setSelected(node and self.widgetOf[node] or nil)
end

--- Several selected; the last is the primary one, with the handles.
function Canvas:selectMany(nodes)
    local widgets = {}
    for _, node in ipairs(nodes) do
        local widget = self.widgetOf[node]
        if widget then widgets[#widgets + 1] = widget end
    end
    self.surface:setSelection(widgets)
end

return Canvas
