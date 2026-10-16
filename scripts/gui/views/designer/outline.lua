-- Outline
-- The tree beside the canvas, mirroring the model: name and type, with the
-- widget's icon. Click to select; a selection made anywhere else is shown
-- here too.

local ui = require("limekit.ui")
local DesignModel = require "app.core.design_model"
local Icons = require "gui.views.designer.icons"

local Outline = {}
Outline.__index = Outline

function Outline.new(tree, onSelect)
    local self = setmetatable({ tree = tree, nodeOf = {}, itemOf = {} }, Outline)
    tree:setHeaderLabels({ "Object", "Type" })
    tree:setColumnWidth(1, 190)
    tree:setOnItemClick(function(_, item)
        local node = self.nodeOf[item]
        if node then onSelect(node) end
    end)
    return self
end

local function short(name)
    return name:match("%.(.+)$") or name
end

local function textsFor(node)
    if node.kind == "stretch" then return "stretch", ("Stretch %d"):format(node.stretch or 1) end
    if node.kind == "spacing" then return "spacing", ("Spacing %d px"):format(node.size or 0) end
    local kind = short(node.class)
    if DesignModel.isContainer(node) then
        kind = kind .. " · " .. short(node.layout)
    end
    if node.buildError then kind = kind .. "  (failed)" end
    return node.name, kind
end

function Outline:refresh(design)
    self.tree:clear()
    self.nodeOf, self.itemOf = {}, {}
    local function add(node, parentItem)
        local name, kind = textsFor(node)
        local item = ui.TreeViewItem({ name, kind })
        item:setEditable(false)
        local icon = Icons.forNode(node)
        if icon then item:setIcon(1, icon) end
        self.nodeOf[item], self.itemOf[node] = node, item
        if parentItem then parentItem:addChild(item) else self.tree:addTopItem(item) end
        for _, child in ipairs(node.children or {}) do add(child, item) end
        return item
    end
    add(design.root, nil)
    self.tree:expandAll()
end

--- Highlights the node's row, or clears the highlight for nil.
function Outline:select(node)
    self.tree:setCurrentItem(node and self.itemOf[node] or nil)
end

return Outline
