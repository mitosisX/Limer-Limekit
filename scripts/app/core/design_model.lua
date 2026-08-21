-- DesignModel Module
-- The tree a design is, and the Lua it becomes.
--
-- The model is the source of truth, not the widgets on screen and not the
-- generated file. That is the decision the whole designer rests on, and it
-- is the one every designer that survived has made -- Qt Designer keeps
-- .ui, Android keeps XML -- because generating code once is easy and
-- keeping generated code in step with code somebody has since edited by
-- hand is the problem that kills these tools. Generation is one-way. Edit
-- the design, or edit the output; never both and expect them to meet.
--
-- A node is:
--   { class = "ui.Button", name = "button1", props = { text = "Hi" } }
--
-- A node that holds others also carries a layout, because in Limekit a
-- container does not hold widgets, a layout does:
--   { class = "ui.Container", layout = "ui.VLayout", children = { ... } }

local DesignModel = {}

DesignModel.LAYOUTS = { "ui.VLayout", "ui.HLayout" }

local counters = {}

--- A unique, readable variable name for a class: button1, label2.
function DesignModel.nameFor(class)
    local base = class:match("%.(.+)$") or class
    base = base:sub(1, 1):lower() .. base:sub(2)
    counters[base] = (counters[base] or 0) + 1
    return base .. counters[base]
end

function DesignModel.resetNames()
    counters = {}
end

--- A fresh, empty design: one container laid out in a column.
function DesignModel.blank()
    DesignModel.resetNames()
    return {
        class = "ui.Container",
        name = DesignModel.nameFor("ui.Container"),
        layout = "ui.VLayout",
        props = {},
        children = {},
    }
end

function DesignModel.node(class)
    return { class = class, name = DesignModel.nameFor(class), props = {} }
end

function DesignModel.container(layout)
    local node = DesignModel.node("ui.Container")
    node.layout = layout or "ui.VLayout"
    node.children = {}
    return node
end

function DesignModel.isContainer(node)
    return node ~= nil and node.children ~= nil
end

--- The node's parent, and its index within it. Nil for the root.
function DesignModel.parentOf(root, target, parent)
    if root == target then return parent end
    for _, child in ipairs(root.children or {}) do
        local found = DesignModel.parentOf(child, target, root)
        if found then return found end
    end
    return nil
end

function DesignModel.indexOf(parent, child)
    for index, candidate in ipairs(parent.children or {}) do
        if candidate == child then return index end
    end
    return nil
end

function DesignModel.add(parent, node)
    if not DesignModel.isContainer(parent) then return false end
    parent.children[#parent.children + 1] = node
    return true
end

function DesignModel.remove(root, target)
    local parent = DesignModel.parentOf(root, target)
    if not parent then return false end          -- the root cannot be removed

    local index = DesignModel.indexOf(parent, target)
    if not index then return false end

    table.remove(parent.children, index)
    return true
end

--- Moves a node one place earlier or later among its siblings.
function DesignModel.move(root, target, delta)
    local parent = DesignModel.parentOf(root, target)
    if not parent then return false end

    local index = DesignModel.indexOf(parent, target)
    local wanted = index + delta
    if wanted < 1 or wanted > #parent.children then return false end

    table.remove(parent.children, index)
    table.insert(parent.children, wanted, target)
    return true
end

--- Walks every node, deepest last, calling fn(node, depth).
function DesignModel.walk(node, fn, depth)
    depth = depth or 0
    fn(node, depth)
    for _, child in ipairs(node.children or {}) do
        DesignModel.walk(child, fn, depth + 1)
    end
end

-- CODE GENERATION -----------------------------------------------------------

local function literal(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local function setterName(prop)
    return "set" .. prop:sub(1, 1):upper() .. prop:sub(2)
end

-- Properties are emitted in a fixed order so that generating the same design
-- twice produces the same file. Lua's pairs() does not promise an order, and
-- a generator whose output shuffles between runs makes every diff useless.
local function sortedKeys(table_)
    local keys = {}
    for key in pairs(table_ or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function emitNode(node, lines)
    lines[#lines + 1] = string.format("local %s = %s()", node.name, node.class)

    for _, key in ipairs(sortedKeys(node.props)) do
        lines[#lines + 1] = string.format("%s:%s(%s)",
            node.name, setterName(key), literal(node.props[key]))
    end

    if DesignModel.isContainer(node) then
        local layoutName = node.name .. "Layout"
        lines[#lines + 1] = string.format("local %s = %s()", layoutName, node.layout)

        for _, child in ipairs(node.children) do
            lines[#lines + 1] = ""
            emitNode(child, lines)
        end

        lines[#lines + 1] = ""
        for _, child in ipairs(node.children) do
            lines[#lines + 1] = string.format("%s:addChild(%s)", layoutName, child.name)
        end
        lines[#lines + 1] = string.format("%s:setLayout(%s)", node.name, layoutName)
    end
end

--- The design as a runnable main.lua.
function DesignModel.generate(root, title)
    local lines = {
        "-- GENERATED by Limer's designer.",
        "--",
        "-- Edited by hand this becomes yours, and the designer will not read",
        "-- it back -- generation is one way. Keep designing, or keep editing.",
        "",
        'local ui = require("limekit.ui")',
        "",
    }

    emitNode(root, lines)

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format('local window = ui.Window { title = %s }',
        literal(title or "My App"))
    lines[#lines + 1] = string.format("window:setMainChild(%s)", root.name)
    lines[#lines + 1] = "window:show()"
    lines[#lines + 1] = ""

    return table.concat(lines, "\n")
end

return DesignModel
