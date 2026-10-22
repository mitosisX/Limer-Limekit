-- Outline
-- The tree beside the canvas, mirroring the model: each node's name beside
-- its widget's icon, which already says what it is -- a column spelling the
-- type out too only took the width the names needed. Click to select; a
-- selection made anywhere else is shown here too.

local ui = require("limekit.ui")
local Icons = require "gui.views.designer.icons"

local Outline = {}
Outline.__index = Outline

function Outline.new(tree, onSelect)
    local self = setmetatable({ tree = tree, nodeOf = {}, itemOf = {} }, Outline)
    tree:setHeaderLabels({ "Object" })
    tree:setOnItemClick(function(_, item)
        local node = self.nodeOf[item]
        if node then onSelect(node) end
    end)
    return self
end

-- What a row says: the node's name, or for a stretch or spacing, what it is.
local function textFor(node)
    if node.kind == "stretch" then return ("Stretch %d"):format(node.stretch or 1) end
    if node.kind == "spacing" then return ("Spacing %d px"):format(node.size or 0) end
    local name = node.name
    if node.buildError then name = name .. "  (failed)" end
    if node.locked then name = name .. "  (locked)" end
    return name
end

function Outline:refresh(design)
    self.tree:clear()
    self.nodeOf, self.itemOf = {}, {}
    local function add(node, parentItem)
        local item = ui.TreeViewItem({ textFor(node) })
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
