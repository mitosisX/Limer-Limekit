-- Outline
-- The tree beside the canvas, mirroring the model. Click to select.

local ui = require("limekit.ui")
local DesignModel = require "app.core.design_model"

local Outline = {}
Outline.__index = Outline

function Outline.new(tree, onSelect)
    local self = setmetatable({ tree = tree, nodeOf = {} }, Outline)
    tree:setHeaderHidden(true)
    tree:setOnItemClick(function(_, item)
        local node = self.nodeOf[item]
        if node then onSelect(node) end
    end)
    return self
end

local function labelFor(node)
    if node.kind == "stretch" then return ("~ stretch %d"):format(node.stretch or 1) end
    if node.kind == "spacing" then return ("~ spacing %d"):format(node.size or 0) end
    local text = node.name .. "   " .. (node.class:match("%.(.+)$") or node.class)
    if DesignModel.isContainer(node) then
        text = text .. "  [" .. (node.layout:match("%.(.+)$") or node.layout) .. "]"
    end
    if node.buildError then text = text .. "   (!)" end
    return text
end

function Outline:refresh(design)
    self.tree:clear()
    self.nodeOf = {}
    local function add(node, parentItem)
        local item = ui.TreeViewItem({ labelFor(node) })
        self.nodeOf[item] = node
        if parentItem then parentItem:addChild(item) else self.tree:addTopItem(item) end
        for _, child in ipairs(node.children or {}) do add(child, item) end
        return item
    end
    add(design.root, nil)
    self.tree:expandAll()
end

return Outline
