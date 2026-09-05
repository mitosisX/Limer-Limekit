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

local Canvas = {}
Canvas.__index = Canvas

--- onDrop({ kind = "class", class, target, slot }) or
--- onDrop({ kind = "move", node, target, slot }); onSelect(node or nil).
function Canvas.new(surface, onDrop, onSelect)
    local self = setmetatable({ surface = surface, widgetOf = {}, nodeOf = {} }, Canvas)

    surface:setOnSelect(function(widget)
        onSelect(widget and self.nodeOf[widget] or nil)
    end)

    surface:setOnDrop(function(drop)
        local target = self.nodeOf[drop.target]
        if not target then return end
        local slot = { index = drop.index, row = drop.row, column = drop.column }
        if drop.kind == "class" then
            onDrop({ kind = "class", class = drop.class, target = target, slot = slot })
        else
            local node = self.nodeOf[drop.widget]
            if node then
                onDrop({ kind = "move", node = node, target = target, slot = slot })
            end
        end
    end)

    return self
end

local function className(class)
    return class:match("%.(.+)$") or class
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

    for name, value in pairs(node.props or {}) do
        pcall(sys.Introspect.setProperty, widget, name, value)
    end
    self.widgetOf[node], self.nodeOf[widget] = widget, node

    if ok and DesignModel.isContainer(node) then
        local layout = ui[className(node.layout)]()
        local kind = DesignModel.layoutKind(node.layout)
        for _, child in ipairs(node.children) do
            if child.kind == "stretch" then
                layout:addStretch(child.stretch or 1)
            elseif child.kind == "spacing" then
                layout:addSpacing(child.size or 0)
            elseif kind == "grid" then
                local g = child.grid
                layout:addChild(self:build(child), g.row, g.column, g.rowSpan or 1, g.columnSpan or 1)
            elseif kind == "form" then
                layout:addChild(child.form.label or "", self:build(child))
            else
                layout:addChild(self:build(child), child.stretch or 0)
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
    self.widgetOf, self.nodeOf = {}, {}
    local root = self:build(design.root)
    root:setFixedSize(design.window.width, design.window.height)
    self.surface:setDesignChild(root)
    -- Every widget built above is new and therefore still interactive; the
    -- surface has to be told before the next click reaches one of them.
    self.surface:refresh()
end

function Canvas:widgetFor(node) return node and self.widgetOf[node] or nil end
function Canvas:nodeFor(widget) return widget and self.nodeOf[widget] or nil end

function Canvas:select(node)
    self.surface:setSelected(node and self.widgetOf[node] or nil)
end

return Canvas
