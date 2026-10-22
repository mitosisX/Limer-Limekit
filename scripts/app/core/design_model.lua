-- DesignModel
-- The tree a design is, the file it is saved as, and the Lua it becomes.
--
-- The model is the source of truth, not the widgets on screen and not the
-- generated file. That is the decision the whole designer rests on, and it
-- is the one every designer that survived has made -- Qt Designer keeps
-- .ui, Android keeps XML -- because generating code once is easy and
-- keeping generated code in step with code somebody has since edited by
-- hand is the problem that kills these tools. Generation is one-way. Edit
-- the design, or edit the output; never both and expect them to meet.
--
-- A design:
--   { version = 1, window = { title, width, height }, root = <node> }
--
-- A node:
--   { class = "ui.Button", name = "button1", props = { text = "Hi" } }
--
-- A node that holds others also carries a layout, because in Limekit a
-- container does not hold widgets, a layout does:
--   { class = "ui.Container", name = "box", layout = "ui.VLayout",
--     children = { ... } }
--
-- Where a node sits is the parent's layout's business, so it is recorded
-- on the child in the shape that layout reads:
--   stretch = 0                                        -- in a row/column
--   grid = { row, column, rowSpan, columnSpan }        -- in a grid
--   form = { label = "Name" }                          -- in a form
--
-- Rows and columns can also hold two things that are not widgets:
--   { kind = "stretch", stretch = 1 }   { kind = "spacing", size = 12 }
--
-- Three widgets hold children without a layout, and carry a holder kind
-- in `layout` instead of a layout class:
--   ui.Tab       layout = "tab"       children are pages, each a container
--                                     with tab = { title = "Page 1" }
--   ui.Splitter  layout = "splitter"  children are panes, any widget
--   ui.Scroller  layout = "scroller"  one child, any widget
--
-- Two more fields a node may carry: `cells`, the text in a Table's cells
-- (see TABLE CONTENTS), and `locked`, which keeps it where it is.
--
-- Every mutating function returns true, or false and a reason, and never
-- half-applies: a refused change leaves the design as it was.

local DesignModel = {}

DesignModel.LAYOUTS = { "ui.VLayout", "ui.HLayout", "ui.GridLayout", "ui.FormLayout" }

local KINDS = {
    ["ui.VLayout"] = "vbox", ["ui.HLayout"] = "hbox",
    ["ui.GridLayout"] = "grid", ["ui.FormLayout"] = "form",
    tab = "tab", splitter = "splitter", scroller = "scroller",
}

-- Widgets that are containers by nature, and how they hold.
local HOLDERS = { ["ui.Tab"] = "tab", ["ui.Splitter"] = "splitter", ["ui.Scroller"] = "scroller" }

-- Widgets that hold others through a layout. A Container dropped without
-- one could hold nothing -- there was nowhere to drop into it -- so they
-- start as a column; Properties or Arrange > Change layout makes it a row,
-- grid or form.
local LAYOUT_HOLDERS = { ["ui.Container"] = true, ["ui.GroupBox"] = true }

-- What a widget starts with, where an empty one would be invisible.
local DEFAULT_PROPS = { ["ui.GroupBox"] = { title = "Group" } }

--- True for a container whose layout is a real ui.* layout class, as
--- opposed to a Tab, Splitter or Scroller holding children its own way.
function DesignModel.hasLayout(node)
    return node ~= nil and node.children ~= nil and node.layout ~= nil and node.layout:sub(1, 3) == "ui."
end

--- "vbox", "hbox", "grid" or "form" for a layout class; nil otherwise.
function DesignModel.layoutKind(layout) return KINDS[layout] end

-- Lua's own words, plus the names the generated module uses for itself.
local RESERVED = {}
for word in ([[and break do else elseif end false for function goto if in
    local nil not or repeat return then true until while
    window root M ui]]):gmatch("%S+") do
    RESERVED[word] = true
end

-- NODES ---------------------------------------------------------------------

function DesignModel.node(class)
    local node = { class = class, props = {} }
    for key, value in pairs(DEFAULT_PROPS[class] or {}) do node.props[key] = value end
    if HOLDERS[class] then
        node.layout, node.children = HOLDERS[class], {}
    elseif LAYOUT_HOLDERS[class] then
        node.layout, node.children = "ui.VLayout", {}
    end
    return node
end

-- Widgets that show an image, and the slot it goes in. A slot's setter is
-- set<Slot>: Button:setIcon, Image:setImage. A node records the images it
-- uses by name -- node.images = { icon = "save" } -- never by path, so
-- moving the file in the images manager changes nothing in the design.
-- The window's own icon is design.window.icon, a name the same way.
local IMAGE_SLOTS = {
    ["ui.Button"] = { "icon" }, ["ui.CommandButton"] = { "icon" }, ["ui.CheckBox"] = { "icon" },
    ["ui.Image"] = { "image" }, ["ui.Label"] = { "image" },
}

--- The image slots a class has: { "icon" } for a Button, {} for most.
function DesignModel.imageSlots(class)
    return IMAGE_SLOTS[class] or {}
end

-- What each layout is called on the palette and in a widget's name.
DesignModel.LAYOUT_WORDS = {
    ["ui.VLayout"] = "column", ["ui.HLayout"] = "row",
    ["ui.GridLayout"] = "grid", ["ui.FormLayout"] = "form",
}

--- A node for a palette entry: a widget class ("ui.Button"), or a bare
--- layout ("layout:ui.HLayout"), which is a Container laid out that way
--- and named after it -- row1, column2 -- so the outline says what it is.
function DesignModel.fromPalette(design, entry)
    local layout = entry:match("^layout:(.+)$")
    if not layout then return DesignModel.node(entry) end
    local box = DesignModel.container(layout)
    box.name = DesignModel.nameFor(design, "ui." .. (DesignModel.LAYOUT_WORDS[layout] or "box"))
    return box
end

function DesignModel.container(layout)
    local node = DesignModel.node("ui.Container")
    node.layout = layout or "ui.VLayout"
    node.children = {}
    return node
end

function DesignModel.stretch(n) return { kind = "stretch", stretch = n or 1 } end
function DesignModel.spacing(size) return { kind = "spacing", size = size or 12 } end

function DesignModel.isContainer(node) return node ~= nil and node.children ~= nil end
function DesignModel.isPseudo(node) return node ~= nil and node.kind ~= nil end

--- A fresh, empty design: one container laid out in a column.
function DesignModel.blank()
    local design = { version = 1, window = { title = "My App", width = 640, height = 480 } }
    design.root = DesignModel.container("ui.VLayout")
    design.root.name = "root"
    return design
end

--- Walks every node, parents before children, calling fn(node, depth).
function DesignModel.walk(node, fn, depth)
    depth = depth or 0
    fn(node, depth)
    for _, child in ipairs(node.children or {}) do
        DesignModel.walk(child, fn, depth + 1)
    end
end

--- The node's parent. Nil for the root, and for a node not in the design.
function DesignModel.parentOf(design, target, node, parent)
    node = node or design.root
    if node == target then return parent end
    for _, child in ipairs(node.children or {}) do
        local found = DesignModel.parentOf(design, target, child, node)
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

local function descends(node, ancestor)
    if node == ancestor then return true end
    for _, child in ipairs(ancestor.children or {}) do
        if descends(node, child) then return true end
    end
    return false
end

-- LOCKING -------------------------------------------------------------------

-- A locked node stays where it is: it can still be selected and its
-- properties edited, but it is not moved, wrapped, unwrapped or deleted
-- until it is unlocked. Locking is the designer's own business; nothing
-- about it reaches the generated code.

local function lockedReason(node)
    return (node.name or node.kind or "it") .. " is locked -- unlock it first"
end

--- The first locked node in a subtree, the node itself included; nil if
--- none is. Deleting a container would take its locked children with it.
function DesignModel.lockedWithin(node)
    if node.locked then return node end
    for _, child in ipairs(node.children or {}) do
        local found = DesignModel.lockedWithin(child)
        if found then return found end
    end
    return nil
end

function DesignModel.setLocked(design, node, locked)
    if node == design.root then return false, "the root stays put already" end
    if not DesignModel.parentOf(design, node) then return false, "not in the design" end
    -- Absent rather than false, so an unlocked node saves as it always did.
    node.locked = locked and true or nil
    return true
end

-- NAMES ---------------------------------------------------------------------

local function usedNames(design)
    local used = {}
    DesignModel.walk(design.root, function(node)
        if node.name then used[node.name] = true end
    end)
    return used
end

--- A unique, readable variable name for a class: button1, label2.
function DesignModel.nameFor(design, class)
    local base = class:match("%.(.+)$") or class
    base = base:sub(1, 1):lower() .. base:sub(2)
    local used = usedNames(design)
    local n = 1
    while used[base .. n] do n = n + 1 end
    return base .. n
end

function DesignModel.rename(design, node, name)
    if type(name) ~= "string" or not name:match("^[%a_][%w_]*$") then
        return false, "a name must be a Lua identifier"
    end
    if RESERVED[name] then return false, name .. " is reserved" end
    if name ~= node.name and usedNames(design)[name] then
        return false, name .. " is already used"
    end
    node.name = name
    return true
end

-- PLACEMENT -----------------------------------------------------------------

local function clearPlacement(node)
    -- A stretch item's `stretch` is what it is, not where it sits.
    if DesignModel.isPseudo(node) then return end
    node.grid, node.form, node.stretch, node.tab = nil, nil, nil, nil
end

local function pageTitle(parent)
    return ("Page %d"):format(#parent.children + 1)
end

local function cellTaken(parent, row, column, except)
    for _, child in ipairs(parent.children) do
        if child ~= except and child.grid
            and child.grid.row == row and child.grid.column == column then
            return true
        end
    end
    return false
end

-- Gives `node` the placement the parent's layout reads and returns the
-- list index it should sit at -- or nil and a reason, with the node's
-- placement untouched.
local function place(parent, node, slot, except)
    local kind = KINDS[parent.layout]
    local pseudo = DesignModel.isPseudo(node)
    if pseudo and kind ~= "vbox" and kind ~= "hbox" then
        return nil, "stretch and spacing only belong in a row or column"
    end

    if kind == "grid" then
        local row, column = slot.row or 1, slot.column or 1
        if cellTaken(parent, row, column, except) then
            return nil, ("cell %d,%d is occupied"):format(row, column)
        end
        clearPlacement(node)
        node.grid = { row = row, column = column, rowSpan = 1, columnSpan = 1 }
        return #parent.children + 1
    end

    if kind == "scroller" then
        local held = #parent.children - (except and DesignModel.indexOf(parent, except) and 1 or 0)
        if held >= 1 then return nil, "a scroller holds one widget; wrap it to hold more" end
        clearPlacement(node)
        return 1
    end

    if kind == "tab" and not DesignModel.isContainer(node) then
        -- The caller (insert, move) wraps a plain widget in a page first;
        -- reaching here with one is a bug, not a user error.
        return nil, "a tab holds pages"
    end

    clearPlacement(node)
    if kind == "form" then
        node.form = { label = node.name or "" }
    elseif kind == "tab" then
        node.tab = { title = pageTitle(parent) }
    elseif kind == "splitter" then
        -- nothing to record: a pane is just a child in order
    elseif not pseudo then
        node.stretch = 0
    end
    local index = slot.index or (#parent.children + 1)
    return math.max(1, math.min(index, #parent.children + 1))
end

-- A tab holds pages. A widget dropped on one gets a page made around it,
-- unless it is a container already, which becomes the page itself.
local function asPage(design, parent, node)
    if KINDS[parent.layout] ~= "tab" or DesignModel.isContainer(node) then return node end
    local page = DesignModel.container("ui.VLayout")
    page.name = DesignModel.nameFor(design, "ui.Container")
    node.stretch = 0
    page.children[1] = node
    return page
end

--- Puts a node into a container. slot = { index = } or { row =, column = }.
function DesignModel.insert(design, parent, node, slot)
    if not DesignModel.isContainer(parent) then return false, "not a container" end
    if DesignModel.isPseudo(node) and KINDS[parent.layout] ~= "vbox" and KINDS[parent.layout] ~= "hbox" then
        return false, "stretch and spacing only belong in a row or column"
    end
    if not DesignModel.isPseudo(node) and not node.name then
        node.name = DesignModel.nameFor(design, node.class)
    end
    node = asPage(design, parent, node)
    local index, why = place(parent, node, slot or {})
    if not index then return false, why end
    table.insert(parent.children, index, node)
    return true
end

--- Moves a node that is in the design to a container and slot.
function DesignModel.move(design, node, parent, slot)
    if node == design.root then return false, "the root stays put" end
    if node.locked then return false, lockedReason(node) end
    if not DesignModel.isContainer(parent) then return false, "not a container" end
    if descends(parent, node) then return false, "a widget cannot be moved inside itself" end
    local oldParent = DesignModel.parentOf(design, node)
    if not oldParent then return false, "not in the design" end

    local oldIndex = DesignModel.indexOf(oldParent, node)
    local saved = { grid = node.grid, form = node.form, stretch = node.stretch, tab = node.tab }
    local moved = asPage(design, parent, node)
    local index, why = place(parent, moved, slot or {}, node)
    if not index then
        node.grid, node.form, node.stretch, node.tab = saved.grid, saved.form, saved.stretch, saved.tab
        return false, why
    end

    table.remove(oldParent.children, oldIndex)
    -- The slot was measured with the node still in place; once it is out,
    -- everything after it has shifted up one.
    if parent == oldParent and index > oldIndex then index = index - 1 end
    index = math.min(index, #parent.children + 1)
    table.insert(parent.children, index, moved)
    return true
end

function DesignModel.remove(design, node)
    if node == design.root then return false, "the root cannot be removed" end
    local held = DesignModel.lockedWithin(node)
    if held then return false, lockedReason(held) end
    local parent = DesignModel.parentOf(design, node)
    if not parent then return false, "not in the design" end
    table.remove(parent.children, DesignModel.indexOf(parent, node))
    return true
end

-- What a widget can be wrapped in, in the order it is offered: a Container
-- laid out each of the four ways, then the widgets that hold children
-- their own way (a GroupBox through a layout of its own).
DesignModel.WRAPPERS = {
    "ui.HLayout", "ui.VLayout", "ui.GridLayout", "ui.FormLayout",
    "ui.GroupBox", "ui.Scroller", "ui.Splitter", "ui.Tab",
}

-- An empty, named node to wrap with: a layout class makes a Container laid
-- out that way, a holder class makes that widget.
local function wrapperFor(design, how)
    if type(how) == "string" and how:match("^ui%.") and KINDS[how] then
        local box = DesignModel.container(how)
        box.name = DesignModel.nameFor(design, "ui.Container")
        return box
    end
    if HOLDERS[how] or LAYOUT_HOLDERS[how] then
        local box = DesignModel.node(how)
        box.name = DesignModel.nameFor(design, how)
        return box
    end
    return nil, "cannot wrap in " .. tostring(how)
end

--- Replaces a node with a new container holding it, and returns the
--- container. `how` is a layout class ("ui.HLayout" -- a Container laid out
--- that way) or a holder class ("ui.GroupBox", "ui.Tab", ...); see
--- DesignModel.WRAPPERS.
function DesignModel.wrap(design, node, how)
    if node == design.root then return nil, "the root cannot be wrapped" end
    if DesignModel.isPseudo(node) then return nil, "only a widget can be wrapped" end
    if node.locked then return nil, lockedReason(node) end
    local parent = DesignModel.parentOf(design, node)
    if not parent then return nil, "not in the design" end
    local box, why = wrapperFor(design, how)
    if not box then return nil, why end

    -- The box takes the node's place and placement -- a page's tab title
    -- included -- and the node starts fresh inside the box.
    box.grid, box.form, box.stretch, box.tab = node.grid, node.form, node.stretch, node.tab
    clearPlacement(node)
    -- A Tab holds pages, so a plain widget gets a page made around it.
    -- That happens while the node is still in the design, so the page's
    -- name cannot clash with anything in it.
    local inner = asPage(design, box, node)
    local index, reason = place(box, inner, {})
    if not index then return nil, reason end
    box.children[index] = inner
    parent.children[DesignModel.indexOf(parent, node)] = box
    return box
end

--- The reverse of wrap: a container holding exactly one widget gives its
--- place to that widget.
function DesignModel.unwrap(design, box)
    if box == design.root then return false, "the root cannot be unwrapped" end
    if box.locked then return false, lockedReason(box) end
    if not DesignModel.isContainer(box) or #box.children ~= 1 then
        return false, "only a container holding exactly one widget can be unwrapped"
    end
    local child = box.children[1]
    if DesignModel.isPseudo(child) then return false, "nothing to keep" end
    local parent = DesignModel.parentOf(design, box)
    if not parent then return false, "not in the design" end
    if KINDS[parent.layout] == "tab" and not DesignModel.isContainer(child) then
        return false, "a tab holds pages, and " .. child.name .. " is not one"
    end

    clearPlacement(child)
    child.grid, child.form, child.stretch, child.tab = box.grid, box.form, box.stretch, box.tab
    parent.children[DesignModel.indexOf(parent, box)] = child
    return true
end

--- Moves a node to the start ("first") or the end ("last") of the
--- container it is in. Laid out, siblings never overlap, so this is what
--- bring-to-front and send-to-back come to: first and last in the order
--- they are laid out in.
function DesignModel.reorder(design, node, where)
    if where ~= "first" and where ~= "last" then
        return false, "reorder to 'first' or 'last', not " .. tostring(where)
    end
    if node == design.root then return false, "the root stays put" end
    if node.locked then return false, lockedReason(node) end
    local parent = DesignModel.parentOf(design, node)
    if not parent then return false, "not in the design" end
    if KINDS[parent.layout] == "grid" then
        return false, "in a grid, edit row and column instead"
    end
    local index = DesignModel.indexOf(parent, node)
    local target = where == "first" and 1 or #parent.children
    if index == target then
        return false, "already at the " .. (where == "first" and "start" or "end")
    end
    table.remove(parent.children, index)
    table.insert(parent.children, target, node)
    return true
end

-- SEVERAL AT ONCE -----------------------------------------------------------

-- A list without any node that sits inside another node of the list: moving
-- or deleting a row and a button in it would otherwise do the button twice.
local function outermost(nodes)
    local out = {}
    for _, node in ipairs(nodes) do
        local inside = false
        for _, other in ipairs(nodes) do
            if other ~= node and descends(node, other) then inside = true; break end
        end
        if not inside then out[#out + 1] = node end
    end
    return out
end
DesignModel.outermost = outermost

--- Moves several nodes into one container, side by side from `slot`, in the
--- order given. In a grid, one row after another from the slot's cell.
--- All or nothing: the caller works on a snapshot, so a refusal half way
--- leaves the design as it was.
function DesignModel.moveMany(design, nodes, parent, slot)
    nodes = outermost(nodes)
    if #nodes == 0 then return false, "nothing to move" end
    local grid = KINDS[parent.layout] == "grid"
    local previous
    for i, node in ipairs(nodes) do
        local s
        if grid then
            s = { row = (slot.row or 1) + i - 1, column = slot.column or 1 }
        elseif previous then
            -- Just after the one moved before it, measured as move() measures:
            -- with this node still where it was.
            s = { index = DesignModel.indexOf(parent, previous) + 1 }
        else
            s = { index = slot.index }
        end
        local ok, why = DesignModel.move(design, node, parent, s)
        if not ok then return false, why end
        previous = node
    end
    return true
end

--- Deletes several nodes. Refused whole if any is the root or holds a lock.
function DesignModel.removeMany(design, nodes)
    nodes = outermost(nodes)
    for _, node in ipairs(nodes) do
        if node == design.root then return false, "the root cannot be removed" end
        local held = DesignModel.lockedWithin(node)
        if held then return false, lockedReason(held) end
    end
    for _, node in ipairs(nodes) do
        local ok, why = DesignModel.remove(design, node)
        if not ok then return false, why end
    end
    return true
end

-- ALIGNMENT -----------------------------------------------------------------

-- Where a widget sits in the space its layout gives it. Laid out, a widget
-- fills that space; aligned in a direction it keeps its own size that way
-- and sits at the side named. Stored on the node as `halign` and `valign`,
-- generated as Layout:setChildAlignment(widget, ...).
local ALIGN_AXIS = {
    left = "halign", hcenter = "halign", right = "halign",
    top = "valign", vcenter = "valign", bottom = "valign",
}
DesignModel.ALIGNMENTS = { "left", "hcenter", "right", "top", "vcenter", "bottom" }

--- `how` is one of DesignModel.ALIGNMENTS, or "hfill" / "vfill" to fill
--- that way again.
function DesignModel.align(design, nodes, how)
    local axis = ALIGN_AXIS[how] or (how == "hfill" and "halign") or (how == "vfill" and "valign")
    if not axis then return false, "unknown alignment " .. tostring(how) end
    if #nodes == 0 then return false, "nothing selected" end
    for _, node in ipairs(nodes) do
        if node == design.root then return false, "the window has nothing to align in" end
        if DesignModel.isPseudo(node) then return false, "only a widget can be aligned" end
        if node.locked then return false, lockedReason(node) end
        local parent = DesignModel.parentOf(design, node)
        if not parent then return false, "not in the design" end
        if not DesignModel.hasLayout(parent) then
            return false, node.name .. " fills its " .. (parent.class:match("%.(.+)$") or "holder")
        end
    end
    for _, node in ipairs(nodes) do
        node[axis] = ALIGN_AXIS[how] and how or nil
    end
    return true
end

--- Gives every node the same stretch in its row or column, so they share
--- its space equally. They must all be in one row or one column.
function DesignModel.distribute(design, nodes)
    if #nodes < 2 then return false, "select two or more to distribute" end
    local parent = DesignModel.parentOf(design, nodes[1])
    local kind = parent and KINDS[parent.layout]
    if kind ~= "vbox" and kind ~= "hbox" then
        return false, "distribute works on widgets in one row or column"
    end
    for _, node in ipairs(nodes) do
        if DesignModel.parentOf(design, node) ~= parent then
            return false, "they must all be in the same row or column"
        end
        if node.locked then return false, lockedReason(node) end
        if DesignModel.isPseudo(node) then return false, "only widgets can be distributed" end
    end
    for _, node in ipairs(nodes) do node.stretch = 1 end
    return true
end

--- Changes a container's layout, converting how its children are placed.
--- Grid children are ordered row-major; a box's stretch and spacing items
--- are dropped when leaving a box, since nothing else can hold them.
function DesignModel.setLayout(design, box, layout)
    if not DesignModel.isContainer(box) then return false, "not a container" end
    if not DesignModel.hasLayout(box) then
        return false, (box.class:match("%.(.+)$") or box.class) .. " holds children its own way"
    end
    if not KINDS[layout] or not layout:match("^ui%.") then
        return false, "unknown layout " .. tostring(layout)
    end
    local old, new = KINDS[box.layout], KINDS[layout]

    if old == "grid" then
        table.sort(box.children, function(a, b)
            if a.grid.row ~= b.grid.row then return a.grid.row < b.grid.row end
            return a.grid.column < b.grid.column
        end)
    end

    local kept = {}
    for _, child in ipairs(box.children) do
        if not DesignModel.isPseudo(child) or new == "vbox" or new == "hbox" then
            kept[#kept + 1] = child
        end
    end
    box.children, box.layout = kept, layout

    for i, child in ipairs(box.children) do
        clearPlacement(child)
        if new == "grid" then
            child.grid = { row = i, column = 1, rowSpan = 1, columnSpan = 1 }
        elseif new == "form" then
            child.form = { label = child.name or "" }
        elseif not DesignModel.isPseudo(child) then
            child.stretch = 0
        end
    end
    return true
end

-- TABLE CONTENTS ------------------------------------------------------------

-- A Table's column titles and row count are ordinary setter props --
-- columnHeaders, rowCount, or columnCount when no column has a title --
-- but the text in its cells is not: the Table sets one cell at a time.
-- So the cells live beside the props, as rows of strings, every row as
-- wide as the table:
--   node.cells = { { "Ada", "1815" }, { "Grace", "1906" } }
-- and generate as setCellText(row, column, text), once per filled cell.

--- What a Table holds, ready to edit: { headers = { ... }, rows = { { ... } } },
--- every row and the headers padded to the same width.
function DesignModel.tableContents(node)
    local props = node.props or {}
    local headers = {}
    if type(props.columnHeaders) == "table" then
        for i, title in ipairs(props.columnHeaders) do headers[i] = tostring(title) end
    end
    local cells = node.cells or {}
    local columns = math.max(#headers, math.tointeger(props.columnCount) or 0)
    for _, row in ipairs(cells) do columns = math.max(columns, #row) end
    local rowCount = math.max(math.tointeger(props.rowCount) or 0, #cells)

    for c = #headers + 1, columns do headers[c] = "" end
    local rows = {}
    for r = 1, rowCount do
        local row = {}
        for c = 1, columns do row[c] = (cells[r] or {})[c] or "" end
        rows[r] = row
    end
    return { headers = headers, rows = rows }
end

--- Sets what a Table holds from { headers, rows } (the shape tableContents
--- returns). Titles become columnHeaders, or a bare columnCount when every
--- title is blank; the row count follows the rows; and the cells are kept
--- only when at least one of them has text.
function DesignModel.setTableContents(node, contents)
    local headers, rows = contents.headers or {}, contents.rows or {}
    local columns = #headers
    for _, row in ipairs(rows) do columns = math.max(columns, #row) end

    local titles, titled = {}, false
    for c = 1, columns do
        titles[c] = tostring(headers[c] or "")
        if titles[c] ~= "" then titled = true end
    end
    node.props.columnHeaders, node.props.columnCount = nil, nil
    if titled then
        node.props.columnHeaders = titles
    elseif columns > 0 then
        node.props.columnCount = columns
    end
    node.props.rowCount = #rows > 0 and #rows or nil

    local cells, filled = {}, false
    for r, row in ipairs(rows) do
        cells[r] = {}
        for c = 1, columns do
            local text = tostring(row[c] or "")
            cells[r][c] = text
            if text ~= "" then filled = true end
        end
    end
    node.cells = filled and cells or nil
    return true
end

-- FILES ---------------------------------------------------------------------

-- Keys are emitted in a fixed order so that saving the same design twice
-- produces the same file. Lua's pairs() promises no order, and a file that
-- shuffles between saves makes every diff useless.
local function sortedKeys(t)
    local keys = {}
    for key in pairs(t or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function literal(value)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" then
        if math.type(value) == "integer" then return tostring(value) end
        return string.format("%.17g", value)
    end
    if kind == "boolean" then return tostring(value) end
    return "nil"
end

local function emitTable(t, indent, out)
    local pad = string.rep("    ", indent + 1)
    out[#out + 1] = "{\n"
    if #t > 0 then
        for _, value in ipairs(t) do
            out[#out + 1] = pad
            if type(value) == "table" then emitTable(value, indent + 1, out)
            else out[#out + 1] = literal(value) end
            out[#out + 1] = ",\n"
        end
    else
        for _, key in ipairs(sortedKeys(t)) do
            local value = t[key]
            local shown = type(key) == "string" and key:match("^[%a_][%w_]*$") and key
                or ("[" .. literal(key) .. "]")
            out[#out + 1] = pad .. shown .. " = "
            if type(value) == "table" then emitTable(value, indent + 1, out)
            else out[#out + 1] = literal(value) end
            out[#out + 1] = ",\n"
        end
    end
    out[#out + 1] = string.rep("    ", indent) .. "}"
end

--- The design as the Lua source of a file that returns it.
function DesignModel.serialize(design)
    local out = { "return " }
    emitTable(design, 0, out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

local function checkNode(node, path)
    if type(node) ~= "table" then return false, path .. " is not a table" end
    if node.kind then
        if node.kind ~= "stretch" and node.kind ~= "spacing" then
            return false, path .. " has an unknown kind " .. tostring(node.kind)
        end
        return true
    end
    if type(node.class) ~= "string" then return false, path .. " has no class" end
    if type(node.name) ~= "string" then return false, path .. " has no name" end
    node.props = node.props or {}
    -- Alignments are generated as names the layout must know.
    if node.halign ~= nil and ALIGN_AXIS[node.halign] ~= "halign" then
        return false, path .. " has an unknown horizontal alignment " .. tostring(node.halign)
    end
    if node.valign ~= nil and ALIGN_AXIS[node.valign] ~= "valign" then
        return false, path .. " has an unknown vertical alignment " .. tostring(node.valign)
    end
    -- Cells are generated as text, so anything but rows of strings is refused
    -- here rather than turning into nil in the generated code.
    if node.cells ~= nil then
        if type(node.cells) ~= "table" then return false, path .. ".cells is not a table" end
        for r, row in ipairs(node.cells) do
            if type(row) ~= "table" then return false, ("%s.cells[%d] is not a row"):format(path, r) end
            for c, text in ipairs(row) do
                if type(text) ~= "string" then
                    return false, ("%s.cells[%d][%d] is not text"):format(path, r, c)
                end
            end
        end
    end
    if node.children then
        if not KINDS[node.layout] then
            return false, path .. " has an unknown layout " .. tostring(node.layout)
        end
        for i, child in ipairs(node.children) do
            local ok, why = checkNode(child, path .. ".children[" .. i .. "]")
            if not ok then return false, why end
        end
    end
    return true
end

--- A design from the text of a design file, or nil and a reason. The
--- chunk runs with an empty environment: a design file is data, and one
--- that tries to be more than that gets nothing to work with.
function DesignModel.deserialize(source)
    local chunk, err = load(source, "design", "t", {})
    if not chunk then return nil, err end
    local ok, design = pcall(chunk)
    if not ok then return nil, tostring(design) end
    if type(design) ~= "table" then return nil, "a design file must return a table" end
    if type(design.root) ~= "table" then return nil, "the design has no root" end

    design.version = design.version or 1
    design.window = design.window or {}
    design.window.title = design.window.title or "My App"
    design.window.width = design.window.width or 640
    design.window.height = design.window.height or 480

    local valid, why = checkNode(design.root, "root")
    if not valid then return nil, why end
    if not DesignModel.isContainer(design.root) then
        return nil, "the root must be a container"
    end
    return design
end

--- A subtree as Lua source, for the clipboard.
function DesignModel.fragment(node)
    local out = { "return " }
    emitTable(node, 0, out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

--- Puts a fragment (from `fragment`) into a container. Every widget in it
--- gets a fresh unique name, so a fragment pastes into any design, any
--- number of times. Returns the new node.
function DesignModel.paste(design, parent, source, slot)
    local chunk, err = load(source, "fragment", "t", {})
    if not chunk then return nil, err end
    local ok, node = pcall(chunk)
    if not ok then return nil, tostring(node) end
    local valid, why = checkNode(node, "fragment")
    if not valid then return nil, why end
    if DesignModel.isPseudo(node) then return nil, "nothing to paste" end

    -- Old names go first, or nameFor would count the fragment's own names
    -- as taken -- they are not in the design yet. A paste is new, so it
    -- arrives unlocked, whatever it was copied from.
    local named = {}
    DesignModel.walk(node, function(n)
        n.locked = nil
        if n.name then named[#named + 1] = n; n.name = nil end
    end)
    for _, n in ipairs(named) do n.name = DesignModel.nameFor(design, n.class) end

    local inserted, reason = DesignModel.insert(design, parent, node, slot)
    if not inserted then return nil, reason end
    return DesignModel.parentOf(design, node) and node
        or parent.children[#parent.children]   -- became a page
end

--- A deep copy. Undo keeps whole designs rather than reversible commands:
--- the trees are small, and a copy cannot be undone wrongly.
function DesignModel.snapshot(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = DesignModel.snapshot(item) end
    return copy
end

-- UNDO ----------------------------------------------------------------------

local Undo = {}
Undo.__index = Undo
DesignModel.Undo = Undo

--- A stack of designs. `limit` is how many steps back are kept.
function Undo.new(limit)
    return setmetatable({ limit = limit or 200, stack = {}, at = 0 }, Undo)
end

function Undo:reset(design)
    self.stack, self.at = { design }, 1
end

function Undo:current() return self.stack[self.at] end

--- Records a new state. Anything that had been undone is forgotten.
function Undo:push(design)
    for i = #self.stack, self.at + 1, -1 do self.stack[i] = nil end
    self.stack[#self.stack + 1] = design
    while #self.stack > self.limit + 1 do table.remove(self.stack, 1) end
    self.at = #self.stack
end

function Undo:canUndo() return self.at > 1 end
function Undo:canRedo() return self.at < #self.stack end

function Undo:undo()
    if not self:canUndo() then return nil end
    self.at = self.at - 1
    return self.stack[self.at]
end

function Undo:redo()
    if not self:canRedo() then return nil end
    self.at = self.at + 1
    return self.stack[self.at]
end

-- CODE GENERATION -----------------------------------------------------------

local function setterName(prop)
    return "set" .. prop:sub(1, 1):upper() .. prop:sub(2)
end

-- The arguments a stored property value is set with. Most are one
-- literal; a list is a table literal -- setItems({ "A", "B" }) -- and
-- { args = { 0, 100 } } is spread over several -- setRange(0, 100).
local function callArgs(value)
    if type(value) ~= "table" then return literal(value) end
    local parts = {}
    for _, item in ipairs(value.args or value) do parts[#parts + 1] = literal(item) end
    if value.args then return table.concat(parts, ", ") end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- images.logo, or images["end"] for a name Lua reserves.
local function imageRef(key)
    if RESERVED[key] and key ~= "window" and key ~= "root" and key ~= "M" and key ~= "ui" then
        return ("images[%q]"):format(key)
    end
    return "images." .. key
end

-- Setters run in this order. Most props are independent and go
-- alphabetically, but some define what a widget holds and others pick
-- within it: setCurrentIndex(2) before setItems is clamped against an
-- empty list and lost, and setValue(30) before setRange(10, 50) is clamped
-- to the default range first. Content first, selection last.
local PROP_RANK = {
    items = 1, range = 1, minimum = 1, maximum = 1,
    columnHeaders = 1, columnCount = 1, headerLabels = 1, rowCount = 1, checkable = 1,
    currentIndex = 3, currentRow = 3, currentText = 3, value = 3, checked = 3,
}

local function propOrder(props)
    local keys = sortedKeys(props)
    table.sort(keys, function(a, b)
        local ra, rb = PROP_RANK[a] or 2, PROP_RANK[b] or 2
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    return keys
end

-- Every widget first, so that a layout can refer to any of them.
local function emitWidgets(node, lines)
    if DesignModel.isPseudo(node) then return end
    lines[#lines + 1] = ("w.%s = %s()"):format(node.name, node.class)
    for _, key in ipairs(propOrder(node.props)) do
        lines[#lines + 1] = ("w.%s:%s(%s)"):format(
            node.name, setterName(key), callArgs(node.props[key]))
    end
    for _, slot in ipairs(sortedKeys(node.images)) do
        lines[#lines + 1] = ("w.%s:%s(%s)"):format(
            node.name, setterName(slot), imageRef(node.images[slot]))
    end
    -- A Table's cells, after the setters above have given it its rows and
    -- columns. A blank cell is left alone rather than set to "".
    for r, row in ipairs(node.cells or {}) do
        for c, text in ipairs(row) do
            if text ~= "" then
                lines[#lines + 1] = ("w.%s:setCellText(%d, %d, %s)"):format(node.name, r, c, literal(text))
            end
        end
    end
    for _, child in ipairs(node.children or {}) do emitWidgets(child, lines) end
end

--- Every image name a design uses, sorted, the window's icon included.
function DesignModel.imagesUsed(design)
    local seen, list = {}, {}
    local function add(key)
        if key and not seen[key] then seen[key] = true; list[#list + 1] = key end
    end
    add(design.window.icon)
    DesignModel.walk(design.root, function(node)
        for _, key in pairs(node.images or {}) do add(key) end
    end)
    table.sort(list)
    return list
end

-- Then layouts, innermost first: a container's layout adds children that
-- must already have theirs.
local function emitLayouts(node, lines)
    if not DesignModel.isContainer(node) then return end
    for _, child in ipairs(node.children) do emitLayouts(child, lines) end

    local kind = KINDS[node.layout]
    if not DesignModel.hasLayout(node) then
        if #node.children > 0 then lines[#lines + 1] = "" end
        for _, child in ipairs(node.children) do
            if kind == "tab" then
                lines[#lines + 1] = ("w.%s:addTab(w.%s, %s)"):format(
                    node.name, child.name, literal((child.tab or {}).title or ""))
            elseif kind == "splitter" then
                lines[#lines + 1] = ("w.%s:addChild(w.%s)"):format(node.name, child.name)
            else
                lines[#lines + 1] = ("w.%s:setChild(w.%s)"):format(node.name, child.name)
            end
        end
        return
    end

    local L = node.name .. "Layout"
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("local %s = %s()"):format(L, node.layout)
    for _, child in ipairs(node.children) do
        if child.kind == "stretch" then
            lines[#lines + 1] = ("%s:addStretch(%d)"):format(L, child.stretch or 1)
        elseif child.kind == "spacing" then
            lines[#lines + 1] = ("%s:addSpacing(%d)"):format(L, child.size or 0)
        elseif kind == "grid" then
            local g = child.grid or { row = 1, column = 1 }
            lines[#lines + 1] = ("%s:addChild(w.%s, %d, %d, %d, %d)"):format(
                L, child.name, g.row, g.column, g.rowSpan or 1, g.columnSpan or 1)
        elseif kind == "form" then
            lines[#lines + 1] = ("%s:addChild(%s, w.%s)"):format(
                L, literal((child.form or {}).label or ""), child.name)
        elseif (child.stretch or 0) > 0 then
            lines[#lines + 1] = ("%s:addChild(w.%s, %d)"):format(L, child.name, child.stretch)
        else
            lines[#lines + 1] = ("%s:addChild(w.%s)"):format(L, child.name)
        end
        local align = DesignModel.alignmentOf(child)
        if align then
            lines[#lines + 1] = ("%s:setChildAlignment(w.%s, %s)"):format(L, child.name, align)
        end
    end
    lines[#lines + 1] = ("w.%s:setLayout(%s)"):format(node.name, L)
end

--- A node's alignment as setChildAlignment's arguments -- '"left", "top"' --
--- or nil when it fills both ways.
function DesignModel.alignmentOf(node)
    if DesignModel.isPseudo(node) then return nil end
    local parts = {}
    if node.halign then parts[#parts + 1] = literal(node.halign) end
    if node.valign then parts[#parts + 1] = literal(node.valign) end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

--- The same, as a list of names, for the canvas to apply.
function DesignModel.alignmentNames(node)
    local names = {}
    if not DesignModel.isPseudo(node) then
        names[#names + 1] = node.halign
        names[#names + 1] = node.valign
    end
    return names
end

--- The design as a Lua module whose new() builds a fresh window and
--- returns it with every widget by name, so main.lua can `require` it,
--- call new() -- as often as it likes -- and wire handlers on.
function DesignModel.generate(design, moduleName)
    moduleName = moduleName or "main"
    local lines = {
        ("-- GENERATED by Limer's designer from design/%s.design.lua."):format(moduleName),
        "-- Regenerate from the designer; edits here are overwritten.",
        'local ui = require("limekit.ui")',
    }
    -- Images by name, from the module the images manager keeps current.
    if #DesignModel.imagesUsed(design) > 0 then
        lines[#lines + 1] = 'local images = require("designed.images")'
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "local M = {}"
    lines[#lines + 1] = ""
    -- A factory, not widgets built at require time: require caches the
    -- module, so widgets made on load would be one window for the whole
    -- app, and a designed dialog closed once could never be opened again.
    lines[#lines + 1] = "--- A fresh window and every widget in it, by name."
    lines[#lines + 1] = "function M.new()"
    local body = { "local w = {}", "" }
    emitWidgets(design.root, body)
    emitLayouts(design.root, body)

    local win = design.window
    body[#body + 1] = ""
    body[#body + 1] = ("w.window = ui.Window { title = %s }"):format(literal(win.title or "My App"))
    body[#body + 1] = ("w.window:setSize(%d, %d)"):format(win.width or 640, win.height or 480)
    if win.icon then
        body[#body + 1] = ("w.window:setIcon(%s)"):format(imageRef(win.icon))
    end
    body[#body + 1] = ("w.window:setMainChild(w.%s)"):format(design.root.name)
    body[#body + 1] = "return w"
    for _, line in ipairs(body) do
        lines[#lines + 1] = line == "" and "" or "    " .. line
    end
    lines[#lines + 1] = "end"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "return M"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

return DesignModel
