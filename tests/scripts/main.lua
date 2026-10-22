-- Limer's model tests, as a Limekit project:  python -m limekit tests
-- Limer ships no Python, so its tests are Lua too. Each check prints one
-- line; the process exits non-zero if any failed.
-- The engine puts this project's scripts folder first on package.path;
-- Limer's own scripts folder is two levels up from it.
local here = package.path:match("^([^;]*)[/\\]%?%.lua")
package.path = here .. "/../../scripts/?.lua;" .. package.path

local sys = require("limekit.sys")
local DesignModel = require("app.core.design_model")

local failures, count = 0, 0
local function check(name, fn)
    count = count + 1
    local ok, err = pcall(fn)
    if ok then
        print("ok    " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end
local function eq(a, b, what)
    if a ~= b then
        error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

-- TREE ----------------------------------------------------------------------

check("blank design has a column root", function()
    local d = DesignModel.blank()
    eq(d.root.class, "ui.Container"); eq(d.root.layout, "ui.VLayout"); eq(#d.root.children, 0)
    eq(d.root.name, "root"); eq(d.window.title, "My App")
end)

check("insert by index into a column", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.Label"), DesignModel.node("ui.LineEdit")
    assert(DesignModel.insert(d, d.root, a, { index = 1 }))
    assert(DesignModel.insert(d, d.root, b, { index = 2 }))
    assert(DesignModel.insert(d, d.root, c, { index = 1 }))
    eq(d.root.children[1], c); eq(d.root.children[2], a); eq(d.root.children[3], b)
    eq(a.name, "button1"); eq(b.name, "label1"); eq(a.stretch, 0)
end)

check("insert into a grid refuses an occupied cell", function()
    local d = DesignModel.blank()
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    assert(DesignModel.insert(d, d.root, a, { row = 1, column = 1 }))
    local ok, why = DesignModel.insert(d, d.root, b, { row = 1, column = 1 })
    eq(ok, false); assert(why:find("occupied"), why)
    eq(a.grid.row, 1); eq(a.grid.column, 1); eq(a.grid.rowSpan, 1)
end)

check("insert into a form gives the row a label", function()
    local d = DesignModel.blank()
    assert(DesignModel.setLayout(d, d.root, "ui.FormLayout"))
    local a = DesignModel.node("ui.LineEdit")
    assert(DesignModel.insert(d, d.root, a, { index = 1 }))
    eq(a.form.label, "lineEdit1")
end)

check("stretch and spacing only go in rows and columns", function()
    local d = DesignModel.blank()
    assert(DesignModel.insert(d, d.root, DesignModel.stretch(), { index = 1 }))
    eq(d.root.children[1].kind, "stretch")
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    eq(#d.root.children, 0)
    local ok = DesignModel.insert(d, d.root, DesignModel.spacing(8), { row = 1, column = 1 })
    eq(ok, false)
end)

check("move later within the same parent lands where the user pointed", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    for i, n in ipairs({ a, b, c }) do DesignModel.insert(d, d.root, n, { index = i }) end
    assert(DesignModel.move(d, a, d.root, { index = 3 }))   -- "before c"
    eq(d.root.children[1], b); eq(d.root.children[2], a); eq(d.root.children[3], c)
    assert(DesignModel.move(d, c, d.root, { index = 1 }))
    eq(d.root.children[1], c); eq(d.root.children[2], b); eq(d.root.children[3], a)
end)

check("move across parents converts placement", function()
    local d = DesignModel.blank()
    local grid = DesignModel.container("ui.GridLayout")
    DesignModel.insert(d, d.root, grid, { index = 1 })
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 2 })
    assert(DesignModel.move(d, a, grid, { row = 2, column = 3 }))
    eq(#d.root.children, 1); eq(grid.children[1], a)
    eq(a.grid.row, 2); eq(a.grid.column, 3); eq(a.stretch, nil)
end)

check("move refuses a descendant target and the root", function()
    local d = DesignModel.blank()
    local outer = DesignModel.container("ui.VLayout")
    local inner = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, outer, { index = 1 })
    DesignModel.insert(d, outer, inner, { index = 1 })
    local ok, why = DesignModel.move(d, outer, inner, { index = 1 })
    eq(ok, false); assert(why:find("inside itself"), why)
    eq((DesignModel.move(d, d.root, outer, { index = 1 })), false)
end)

check("remove, and the root cannot be removed", function()
    local d = DesignModel.blank()
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 })
    assert(DesignModel.remove(d, a)); eq(#d.root.children, 0)
    eq((DesignModel.remove(d, d.root)), false)
end)

check("wrap puts a container where the node was, and unwrap undoes it", function()
    local d = DesignModel.blank()
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 }); DesignModel.insert(d, d.root, b, { index = 2 })
    local box = DesignModel.wrap(d, a, "ui.HLayout")
    eq(d.root.children[1], box); eq(box.children[1], a); eq(box.layout, "ui.HLayout")
    eq(box.name, "container1")
    assert(DesignModel.unwrap(d, box)); eq(d.root.children[1], a); eq(d.root.children[2], b)
    eq((DesignModel.unwrap(d, d.root)), false)
    eq((DesignModel.wrap(d, d.root, "ui.VLayout")), nil)
end)

check("setLayout converts placement", function()
    local d = DesignModel.blank()
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 }); DesignModel.insert(d, d.root, b, { index = 2 })
    DesignModel.insert(d, d.root, DesignModel.stretch(), { index = 3 })
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    eq(#d.root.children, 2)                                      -- stretch dropped
    eq(a.grid.row, 1); eq(b.grid.row, 2); eq(b.grid.column, 1)
    b.grid.row, b.grid.column = 1, 2                             -- now a is (1,1), b is (1,2)
    a.grid.row, a.grid.column = 2, 1
    assert(DesignModel.setLayout(d, d.root, "ui.HLayout"))       -- row-major: b then a
    eq(d.root.children[1], b); eq(d.root.children[2], a)
    eq(a.grid, nil); eq(a.stretch, 0)
    assert(DesignModel.setLayout(d, d.root, "ui.FormLayout"))
    eq(a.form.label, "button1"); eq(a.stretch, nil)
    eq((DesignModel.setLayout(d, d.root, "ui.Nope")), false)
end)

check("rename validates", function()
    local d = DesignModel.blank()
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 }); DesignModel.insert(d, d.root, b, { index = 2 })
    assert(DesignModel.rename(d, a, "okButton")); eq(a.name, "okButton")
    eq((DesignModel.rename(d, b, "okButton")), false)
    eq((DesignModel.rename(d, b, "end")), false)
    eq((DesignModel.rename(d, b, "1abc")), false)
    eq((DesignModel.rename(d, b, "window")), false)
    eq((DesignModel.rename(d, b, "")), false)
    assert(DesignModel.rename(d, b, "b"))
end)

check("names stay unique after a load", function()
    local d = DesignModel.blank()
    DesignModel.insert(d, d.root, DesignModel.node("ui.Button"), { index = 1 })
    eq(DesignModel.nameFor(d, "ui.Button"), "button2")
end)

check("parentOf and indexOf find nodes anywhere", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, box, a, { index = 1 })
    eq(DesignModel.parentOf(d, a), box); eq(DesignModel.indexOf(box, a), 1)
    eq(DesignModel.parentOf(d, d.root), nil)
    eq(DesignModel.parentOf(d, DesignModel.node("ui.Label")), nil)
end)

-- FILES ---------------------------------------------------------------------

check("serialize round-trips through deserialize", function()
    local d = DesignModel.blank()
    d.window.title = "Login \"quoted\""
    DesignModel.setLayout(d, d.root, "ui.FormLayout")
    local e = DesignModel.node("ui.LineEdit"); e.props.hint = "Your name"
    DesignModel.insert(d, d.root, e, { index = 1 })
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 2 })
    DesignModel.insert(d, box, DesignModel.stretch(2), { index = 1 })
    local ok = DesignModel.node("ui.Button"); ok.props.text = "OK"; ok.props.flat = true
    DesignModel.insert(d, box, ok, { index = 2 })

    local text = DesignModel.serialize(d)
    assert(text:sub(1, 8) == "return {", text:sub(1, 20))
    local back, why = DesignModel.deserialize(text)
    assert(back, why)
    eq(DesignModel.serialize(back), text, "second serialize")
    eq(back.window.title, d.window.title)
    eq(back.root.children[2].children[2].props.flat, true)
    eq(back.root.children[2].children[1].kind, "stretch")
    eq(back.root.children[2].children[1].stretch, 2)
    eq(back.root.children[1].form.label, "lineEdit1")
end)

check("deserialize rejects junk and the wrong shape", function()
    local d, why = DesignModel.deserialize("return 42")
    eq(d, nil); assert(why)
    d, why = DesignModel.deserialize("this is not lua")
    eq(d, nil); assert(why)
    d, why = DesignModel.deserialize("return { version = 1 }")
    eq(d, nil); assert(why:find("root"), why)
    d, why = DesignModel.deserialize("return { root = { class = 'ui.Container', name = 'root', layout = 'ui.Nope', children = {} } }")
    eq(d, nil); assert(why:find("layout"), why)
end)

check("deserialize runs the file with no access to the environment", function()
    local d = DesignModel.deserialize("os.exit(3)")
    eq(d, nil)
end)

check("deserialize fills in window defaults", function()
    local d = assert(DesignModel.deserialize("return { root = { class = 'ui.Container', name = 'root', layout = 'ui.VLayout', children = {} } }"))
    eq(d.window.width, 640); eq(d.window.title, "My App"); eq(d.version, 1)
end)

check("snapshot is a deep copy", function()
    local d = DesignModel.blank()
    local a = DesignModel.node("ui.Button"); a.props.text = "a"
    DesignModel.insert(d, d.root, a, { index = 1 })
    local copy = DesignModel.snapshot(d)
    copy.root.children[1].props.text = "b"
    eq(a.props.text, "a")
end)

check("undo and redo walk the stack", function()
    local undo = DesignModel.Undo.new(3)
    local d = DesignModel.blank()
    undo:reset(d)
    eq(undo:canUndo(), false); eq(undo:canRedo(), false)
    for _ = 1, 4 do
        d = DesignModel.snapshot(d)
        DesignModel.insert(d, d.root, DesignModel.node("ui.Button"), { index = 1 })
        undo:push(d)
    end
    eq(#undo:current().root.children, 4)
    eq(#undo:undo().root.children, 3)
    eq(#undo:undo().root.children, 2)
    eq(#undo:undo().root.children, 1)
    eq(undo:undo(), nil)                        -- limited to 3 back
    eq(#undo:redo().root.children, 2)
    d = DesignModel.snapshot(undo:current())
    DesignModel.remove(d, d.root.children[1])
    undo:push(d)
    eq(undo:canRedo(), false)
    eq(#undo:current().root.children, 1)
end)

-- GENERATION ----------------------------------------------------------------

local function stubUi()
    -- A fake `ui` recording calls, so generated code can run without Qt.
    local calls = {}
    local function widget(class)
        return setmetatable({ class = class }, { __index = function(_, method)
            return function(self, ...) calls[#calls + 1] = class .. ":" .. method; return self end
        end })
    end
    local ui = setmetatable({}, { __index = function(_, class) return function() return widget(class) end end })
    ui.Window = function(opts) local w = widget("Window"); w.title = opts.title; return w end
    return ui, calls
end

local function runGenerated(text)
    local ui, calls = stubUi()
    local env = { require = function(name) assert(name == "limekit.ui", name); return ui end }
    local chunk = assert(load(text, "generated", "t", env))
    return chunk(), calls
end

check("generate is deterministic and returns the named widgets", function()
    local d = DesignModel.blank()
    d.window.title = "Login"; d.window.width, d.window.height = 400, 200
    DesignModel.setLayout(d, d.root, "ui.FormLayout")
    local e = DesignModel.node("ui.LineEdit"); e.props.hint = "Your name"
    DesignModel.insert(d, d.root, e, { index = 1 })
    DesignModel.rename(d, e, "name")
    e.form.label = "Name"
    local row = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, row, { index = 2 })
    DesignModel.insert(d, row, DesignModel.stretch(), { index = 1 })
    DesignModel.insert(d, row, DesignModel.spacing(6), { index = 2 })
    local ok = DesignModel.node("ui.Button"); ok.props.text = "OK"
    DesignModel.insert(d, row, ok, { index = 3 })
    DesignModel.rename(d, ok, "ok")
    ok.stretch = 2

    local a, b = DesignModel.generate(d, "login"), DesignModel.generate(d, "login")
    eq(a, b, "determinism")
    assert(a:find('w.name:setHint("Your name")', 1, true), a)
    assert(a:find('rootLayout:addChild("Name", w.name)', 1, true), a)
    assert(a:find('container1Layout:addStretch(1)', 1, true), a)
    assert(a:find('container1Layout:addSpacing(6)', 1, true), a)
    assert(a:find('container1Layout:addChild(w.ok, 2)', 1, true), a)
    assert(a:find('w.window = ui.Window { title = "Login" }', 1, true), a)
    assert(a:find('w.window:setSize(400, 200)', 1, true), a)
    assert(a:find('w.window:setMainChild(w.root)', 1, true), a)
    assert(a:find('design/login.design.lua', 1, true), a)

    local M = runGenerated(a)
    local w = M.new()
    assert(w.window and w.root and w.name and w.ok and w.container1)
    eq(w.window.title, "Login")
end)

check("generate exports a factory, so a designed window opens twice", function()
    local d = DesignModel.blank()
    DesignModel.insert(d, d.root, DesignModel.node("ui.Button"), { index = 1 })
    local text = DesignModel.generate(d, "dialog")
    assert(text:find("function M.new()", 1, true), text)
    local M, calls = runGenerated(text)
    -- Requiring builds nothing; only new() does.
    eq(#calls, 0, "calls at require time")
    eq(type(M.new), "function")
    eq(M.window, nil, "a window at module level")
    local first, second = M.new(), M.new()
    assert(first.window and second.window and first.button1 and second.button1)
    assert(first.window ~= second.window, "both calls returned the same window")
    assert(first.button1 ~= second.button1, "both calls returned the same button")
end)

check("generate sets what a widget holds before what it selects", function()
    local d = DesignModel.blank()
    local combo = DesignModel.node("ui.ComboBox")
    combo.props.items = { "Red", "Green", "Blue" }
    combo.props.currentIndex = 2
    local spin = DesignModel.node("ui.Spinner")
    spin.props.range = { args = { 10, 50 } }
    spin.props.value = 30
    local button = DesignModel.node("ui.Button")
    button.props.checked = true
    button.props.checkable = true
    assert(DesignModel.insert(d, d.root, combo, { index = 1 }))
    assert(DesignModel.insert(d, d.root, spin, { index = 2 }))
    assert(DesignModel.insert(d, d.root, button, { index = 3 }))
    local src = DesignModel.generate(d, "main")
    local function before(a, b)
        local i, j = src:find(a, 1, true), src:find(b, 1, true)
        assert(i and j, src)
        assert(i < j, a .. " must come before " .. b .. "\n" .. src)
    end
    before("w.comboBox1:setItems(", "w.comboBox1:setCurrentIndex(2)")
    before("w.spinner1:setRange(10, 50)", "w.spinner1:setValue(30)")
    before("w.button1:setCheckable(true)", "w.button1:setChecked(true)")
end)

check("generate emits grid placement", function()
    local d = DesignModel.blank()
    DesignModel.setLayout(d, d.root, "ui.GridLayout")
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { row = 2, column = 3 })
    a.grid.columnSpan = 2
    local text = DesignModel.generate(d, "grid")
    assert(text:find("rootLayout:addChild(w.button1, 2, 3, 1, 2)", 1, true), text)
    runGenerated(text)
end)

check("generate builds inner layouts before the outer one uses them", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    DesignModel.insert(d, box, DesignModel.node("ui.Label"), { index = 1 })
    local text = DesignModel.generate(d, "nested")
    local inner = text:find("w.container1:setLayout(container1Layout)", 1, true)
    local outer = text:find("rootLayout:addChild(w.container1)", 1, true)
    assert(inner and outer and inner < outer, text)
    runGenerated(text)
end)

-- HOLDERS -------------------------------------------------------------------

check("a widget dropped on a tab gets a page made around it", function()
    local d = DesignModel.blank()
    local tab = DesignModel.node("ui.Tab")
    assert(tab.children and tab.layout == "tab")
    assert(DesignModel.insert(d, d.root, tab, { index = 1 }))
    local b = DesignModel.node("ui.Button")
    assert(DesignModel.insert(d, tab, b, { index = 1 }))
    local page = tab.children[1]
    eq(page.class, "ui.Container"); eq(page.children[1], b); eq(page.tab.title, "Page 1")
    local box = DesignModel.container("ui.HLayout")
    assert(DesignModel.insert(d, tab, box, { index = 2 }))
    eq(tab.children[2], box); eq(box.tab.title, "Page 2")
    eq((DesignModel.insert(d, tab, DesignModel.stretch(), { index = 1 })), false)
    eq((DesignModel.setLayout(d, tab, "ui.VLayout")), false)
end)

check("moving a plain widget into a tab wraps it too", function()
    local d = DesignModel.blank()
    local tab = DesignModel.node("ui.Tab")
    DesignModel.insert(d, d.root, tab, { index = 1 })
    local b = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, b, { index = 2 })
    assert(DesignModel.move(d, b, tab, { index = 1 }))
    eq(#d.root.children, 1); eq(tab.children[1].children[1], b)
end)

check("a scroller holds one, a splitter holds many", function()
    local d = DesignModel.blank()
    local s = DesignModel.node("ui.Scroller")
    DesignModel.insert(d, d.root, s, { index = 1 })
    assert(DesignModel.insert(d, s, DesignModel.node("ui.Label"), { index = 1 }))
    local ok, why = DesignModel.insert(d, s, DesignModel.node("ui.Label"), { index = 1 })
    eq(ok, false); assert(why:find("one widget"), why)
    local split = DesignModel.node("ui.Splitter")
    DesignModel.insert(d, d.root, split, { index = 2 })
    assert(DesignModel.insert(d, split, DesignModel.node("ui.ListBox"), { index = 1 }))
    assert(DesignModel.insert(d, split, DesignModel.node("ui.TextField"), { index = 1 }))
    eq(split.children[1].class, "ui.TextField")
end)

check("holders generate addTab, addChild and setChild", function()
    local d = DesignModel.blank()
    local tab = DesignModel.node("ui.Tab"); DesignModel.insert(d, d.root, tab, { index = 1 })
    DesignModel.insert(d, tab, DesignModel.node("ui.Button"), { index = 1 })
    tab.children[1].tab.title = "First"
    local split = DesignModel.node("ui.Splitter"); DesignModel.insert(d, d.root, split, { index = 2 })
    DesignModel.insert(d, split, DesignModel.node("ui.ListBox"), { index = 1 })
    local s = DesignModel.node("ui.Scroller"); DesignModel.insert(d, d.root, s, { index = 3 })
    DesignModel.insert(d, s, DesignModel.node("ui.Label"), { index = 1 })
    local text = DesignModel.generate(d, "holders")
    assert(text:find('w.tab1:addTab(w.container1, "First")', 1, true), text)
    assert(text:find("w.splitter1:addChild(w.listBox1)", 1, true), text)
    assert(text:find("w.scroller1:setChild(w.label1)", 1, true), text)
    assert(not text:find("tab1Layout", 1, true), text)
    runGenerated(text)
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.root.children[1].layout, "tab")
end)

-- CLIPBOARD -----------------------------------------------------------------

check("a fragment pastes with fresh names, anywhere, repeatedly", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    local b = DesignModel.node("ui.Button"); b.props.text = "Go"
    DesignModel.insert(d, box, b, { index = 1 })
    local text = DesignModel.fragment(box)
    local first = assert(DesignModel.paste(d, d.root, text, { index = 2 }))
    local second = assert(DesignModel.paste(d, d.root, text, { index = 3 }))
    eq(#d.root.children, 3)
    eq(first.name, "container2"); eq(second.name, "container3")
    eq(first.children[1].name, "button2"); eq(second.children[1].name, "button3")
    eq(second.children[1].props.text, "Go")
    eq((DesignModel.paste(d, d.root, "nonsense", {})), nil)
    eq((DesignModel.paste(d, d.root, "return { kind = 'stretch' }", {})), nil)
end)

-- PALETTE -------------------------------------------------------------------

check("a Container or GroupBox from the palette can be dropped into", function()
    eq(DesignModel.node("ui.Container").layout, "ui.VLayout")
    eq(#DesignModel.node("ui.Container").children, 0)
    local group = DesignModel.node("ui.GroupBox")
    eq(group.layout, "ui.VLayout"); eq(group.props.title, "Group")
    local d = DesignModel.blank()
    local box = DesignModel.node("ui.Container")
    assert(DesignModel.insert(d, d.root, box, { index = 1 }))
    assert(DesignModel.insert(d, box, DesignModel.node("ui.Button"), { index = 1 }))
    eq(#box.children, 1)
end)

check("a layout entry from the palette is a container named after it", function()
    local d = DesignModel.blank()
    local row = DesignModel.fromPalette(d, "layout:ui.HLayout")
    eq(row.class, "ui.Container"); eq(row.layout, "ui.HLayout"); eq(row.name, "row1")
    assert(DesignModel.insert(d, d.root, row, { index = 1 }))
    eq(DesignModel.fromPalette(d, "layout:ui.HLayout").name, "row2")
    eq(DesignModel.fromPalette(d, "layout:ui.GridLayout").name, "grid1")
    eq(DesignModel.fromPalette(d, "ui.Button").class, "ui.Button")
end)

-- IMAGES --------------------------------------------------------------------

local Images = require("app.core.images")
local fs = require("limekit.fs")
local FS = fs.FileSystem

check("image names are Lua identifiers, matching the browser's", function()
    eq(Images.key("my-logo@2x"), "my_logo_2x")
    eq(Images.key("2fast"), "_2fast")
    eq(Images.key("---"), "image")
    eq(Images.reference("logo"), "images.logo")
    eq(Images.reference("end"), 'images["end"]')
end)

check("a scan names every image in every folder, shallowest wins a clash", function()
    local project = FS.joinPaths(os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp",
        "limer-images-check-" .. tostring(os.time()))
    local root = FS.joinPaths(project, "images")
    FS.createFolder(project); FS.createFolder(root)
    FS.createFolder(FS.joinPaths(root, "icons")); FS.createFolder(FS.joinPaths(root, "brand"))
    for _, rel in ipairs({ "save.png", "icons/save.png", "icons/open.svg", "brand/logo.png",
                           "notes.txt", "icons/.hidden.png" }) do
        FS.writeFile(FS.joinPaths(root, (rel:gsub("/", package.config:sub(1, 1)))), "x")
    end
    local list = Images.scan(project)
    local byKey = {}
    for _, image in ipairs(list) do byKey[image.key] = image.path end
    eq(byKey.save, "save.png"); eq(byKey.icons_save, "icons/save.png")
    eq(byKey.open, "icons/open.svg"); eq(byKey.logo, "brand/logo.png")
    eq(byKey.notes, nil); eq(byKey.hidden, nil)
    eq(#list, 4)

    -- Writing the module, and only when it changes.
    Images.refresh(project)
    local path = Images.modulePath(project)
    assert(FS.exists(path), "images.lua written")
    local source = FS.readFile(path)
    assert(source:find('logo = res.Resources.images("brand/logo.png")', 1, true), source)
    eq(Images.keyFor("icons/save.png"), "icons_save")
    eq(Images.path("nope"), nil)
    assert(Images.path("logo"):find("logo.png", 1, true))
    -- fs has no recursive delete; the folder is in TEMP and named uniquely.
end)

check("the images module loads and maps names to resource paths", function()
    local source = Images.module({ { key = "logo", path = "brand/logo.png" }, { key = "end", path = "end.png" } })
    local env = { require = function()
        return { Resources = { images = function(p) return "IMG:" .. p end } }
    end }
    local images = assert(load(source, "images", "t", env))()
    eq(images.logo, "IMG:brand/logo.png"); eq(images["end"], "IMG:end.png")
end)

check("a design names its images, and generates them by name", function()
    local d = DesignModel.blank()
    d.window.icon = "logo"
    local b = DesignModel.node("ui.Button")
    b.images = { icon = "save" }
    assert(DesignModel.insert(d, d.root, b, { index = 1 }))
    eq(table.concat(DesignModel.imagesUsed(d), ","), "logo,save")
    eq(DesignModel.imageSlots("ui.Button")[1], "icon")
    eq(DesignModel.imageSlots("ui.Image")[1], "image")
    eq(#DesignModel.imageSlots("ui.LineEdit"), 0)
    local src = DesignModel.generate(d, "main")
    assert(src:find('local images = require("designed.images")', 1, true), src)
    assert(src:find("w.button1:setIcon(images.save)", 1, true), src)
    assert(src:find("w.window:setIcon(images.logo)", 1, true), src)
    -- and a design with none does not require the module at all
    assert(not DesignModel.generate(DesignModel.blank(), "x"):find("designed.images", 1, true))
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.window.icon, "logo"); eq(back.root.children[1].images.icon, "save")
end)

-- FILES ---------------------------------------------------------------------

local Files = require("gui.views.designer.files")

check("a design cannot take a module name Limer generates itself", function()
    eq(Files.validName("login"), true)
    local ok, why = Files.validName("images")
    eq(ok, false); assert(why and why:find("reserved", 1, true), tostring(why))
    ok, why = Files.validName("2fast")
    eq(ok, false); assert(why and why:find("identifier", 1, true), tostring(why))
    -- and the writer refuses it too, before touching the disk
    local path, err = Files.writeGenerated("no/such/project", "images", "return {}")
    eq(path, nil); assert(err and err:find("reserved", 1, true), tostring(err))
end)

-- CATALOGUE -----------------------------------------------------------------

local Catalog = require("gui.views.designer.catalog")

check("catalogue values parse from what is typed, and show back", function()
    eq(Catalog.parse("int", " 42 "), 42); eq(Catalog.parse("int", "x"), nil)
    eq(Catalog.parse("int", "  "), false)
    local pair = Catalog.parse("pair", "0, 100")
    eq(pair.args[1], 0); eq(pair.args[2], 100)
    eq(Catalog.parse("pair", "0"), nil)
    local list = Catalog.parse("list", "Red, , Green ,Blue")
    eq(#list, 3); eq(list[2], "Green")
    eq(Catalog.show("pair", pair), "0, 100"); eq(Catalog.show("list", list), "Red, Green, Blue")
    assert(Catalog.forClass("ui.Button") and Catalog.forClass("ui.LineEdit"))
end)

check("lists and argument lists generate as one table and as spread args", function()
    local d = DesignModel.blank()
    local spin = DesignModel.node("ui.Spinner")
    spin.props.range = { args = { 0, 50 } }
    local combo = DesignModel.node("ui.ComboBox")
    combo.props.items = { "Red", "Green" }
    assert(DesignModel.insert(d, d.root, spin, { index = 1 }))
    assert(DesignModel.insert(d, d.root, combo, { index = 2 }))
    local src = DesignModel.generate(d, "main")
    assert(src:find("w.spinner1:setRange(0, 50)", 1, true), src)
    assert(src:find('w.comboBox1:setItems({ "Red", "Green" })', 1, true), src)
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.root.children[1].props.range.args[2], 50)
end)

-- WRAP IN -------------------------------------------------------------------

check("wrap in each layout places the node the way that layout reads", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.LineEdit"), DesignModel.node("ui.Label")
    DesignModel.insert(d, d.root, a, { index = 1 })
    DesignModel.insert(d, d.root, b, { index = 2 })
    DesignModel.insert(d, d.root, c, { index = 3 })
    local grid = assert(DesignModel.wrap(d, a, "ui.GridLayout"))
    eq(grid.layout, "ui.GridLayout"); eq(a.grid.row, 1); eq(a.grid.column, 1); eq(a.stretch, nil)
    local form = assert(DesignModel.wrap(d, b, "ui.FormLayout"))
    eq(form.layout, "ui.FormLayout"); eq(b.form.label, "lineEdit1")
    local row = assert(DesignModel.wrap(d, c, "ui.HLayout"))
    eq(c.stretch, 0)
    -- every box takes the place its widget had, and is named as before
    eq(d.root.children[1], grid); eq(d.root.children[3], row)
    eq(grid.stretch, 0); eq(grid.name, "container1"); eq(row.name, "container3")
end)

check("wrap in a holder makes that widget, with a page made for a tab", function()
    local d = DesignModel.blank()
    local nodes = {}
    for i = 1, 4 do
        nodes[i] = DesignModel.node("ui.Button")
        DesignModel.insert(d, d.root, nodes[i], { index = i })
    end
    local group = assert(DesignModel.wrap(d, nodes[1], "ui.GroupBox"))
    eq(group.class, "ui.GroupBox"); eq(group.name, "groupBox1"); eq(group.props.title, "Group")
    eq(group.layout, "ui.VLayout"); eq(group.children[1], nodes[1]); eq(nodes[1].stretch, 0)
    local scroller = assert(DesignModel.wrap(d, nodes[2], "ui.Scroller"))
    eq(scroller.layout, "scroller"); eq(scroller.children[1], nodes[2]); eq(nodes[2].stretch, nil)
    local split = assert(DesignModel.wrap(d, nodes[3], "ui.Splitter"))
    eq(split.layout, "splitter"); eq(split.children[1], nodes[3])
    local tab = assert(DesignModel.wrap(d, nodes[4], "ui.Tab"))
    local page = tab.children[1]
    eq(tab.layout, "tab"); eq(page.class, "ui.Container"); eq(page.tab.title, "Page 1")
    eq(page.children[1], nodes[4]); eq(nodes[4].stretch, 0)
    eq(#d.root.children, 4); eq(d.root.children[4], tab)
    local none, why = DesignModel.wrap(d, nodes[1], "ui.Button")
    eq(none, nil); assert(why and why:find("cannot wrap", 1, true), tostring(why))
end)

check("a wrap in a grid keeps the cell, and a wrapped tab page keeps its title", function()
    local d = DesignModel.blank()
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { row = 2, column = 3 })
    local box = assert(DesignModel.wrap(d, a, "ui.VLayout"))
    eq(box.grid.row, 2); eq(box.grid.column, 3); eq(a.grid, nil)

    local d2 = DesignModel.blank()
    local tab = DesignModel.node("ui.Tab"); DesignModel.insert(d2, d2.root, tab, { index = 1 })
    DesignModel.insert(d2, tab, DesignModel.node("ui.Button"), { index = 1 })
    local page = tab.children[1]
    page.tab.title = "First"
    local wrapped = assert(DesignModel.wrap(d2, page, "ui.HLayout"))
    eq(tab.children[1], wrapped); eq(wrapped.tab.title, "First"); eq(page.tab, nil)
    local text = DesignModel.generate(d2, "pages")
    assert(text:find(('w.tab1:addTab(w.%s, "First")'):format(wrapped.name), 1, true), text)
    runGenerated(text)
end)

check("unwrap will not leave a plain widget straight inside a tab", function()
    local d = DesignModel.blank()
    local tab = DesignModel.node("ui.Tab"); DesignModel.insert(d, d.root, tab, { index = 1 })
    local b = DesignModel.node("ui.Button")
    DesignModel.insert(d, tab, b, { index = 1 })
    local ok, why = DesignModel.unwrap(d, tab.children[1])
    eq(ok, false); assert(why:find("pages", 1, true), why)
    eq(tab.children[1].children[1], b)
end)

check("a widget wrapped in every wrapper generates code that runs", function()
    for _, how in ipairs(DesignModel.WRAPPERS) do
        local d = DesignModel.blank()
        local b = DesignModel.node("ui.Button")
        DesignModel.insert(d, d.root, b, { index = 1 })
        assert(DesignModel.wrap(d, b, how), how)
        local back = assert(DesignModel.deserialize(DesignModel.serialize(d)), how)
        eq(back.root.children[1].children ~= nil, true, how)
        local M = runGenerated(DesignModel.generate(d, "wrapped"))
        assert(M.new().button1, how)
    end
end)

-- ORDER AND LOCK ------------------------------------------------------------

check("reorder moves a widget to the start or the end of its container", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    for i, n in ipairs({ a, b, c }) do DesignModel.insert(d, d.root, n, { index = i }) end
    assert(DesignModel.reorder(d, c, "first"))
    eq(d.root.children[1], c); eq(d.root.children[2], a); eq(d.root.children[3], b)
    assert(DesignModel.reorder(d, c, "last"))
    eq(d.root.children[3], c); eq(d.root.children[1], a)
    local ok, why = DesignModel.reorder(d, c, "last")
    eq(ok, false); assert(why:find("already at the end", 1, true), why)
    eq((DesignModel.reorder(d, d.root, "first")), false)
    eq((DesignModel.reorder(d, a, "middle")), false)
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    ok, why = DesignModel.reorder(d, a, "last")
    eq(ok, false); assert(why:find("grid", 1, true), why)
end)

check("a locked widget is not moved, wrapped, reordered or deleted", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Label")
    DesignModel.insert(d, box, a, { index = 1 })
    DesignModel.insert(d, d.root, b, { index = 2 })
    assert(DesignModel.setLocked(d, a, true))
    eq(a.locked, true); eq(DesignModel.lockedWithin(box), a)
    -- wrap answers nil where the rest answer false; either way, no.
    local function refused(ok, why)
        assert(not ok, "a locked widget was changed")
        assert(why and why:find("button1 is locked", 1, true), tostring(why))
    end
    refused(DesignModel.move(d, a, d.root, { index = 1 }))
    refused(DesignModel.remove(d, a))
    refused(DesignModel.remove(d, box))      -- would take the locked button with it
    refused(DesignModel.reorder(d, a, "last"))
    refused(DesignModel.wrap(d, a, "ui.VLayout"))
    eq(box.children[1], a); eq(d.root.children[1], box)
    -- the container around it still moves, taking it along
    assert(DesignModel.move(d, box, d.root, { index = 3 }))
    eq(d.root.children[2], box)
    eq((DesignModel.setLocked(d, d.root, true)), false)
    assert(DesignModel.setLocked(d, a, false))
    eq(a.locked, nil); eq(DesignModel.lockedWithin(box), nil)
    assert(DesignModel.remove(d, a))
end)

check("a lock is saved, never generated, and a paste arrives unlocked", function()
    local d = DesignModel.blank()
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 })
    assert(DesignModel.setLocked(d, a, true))
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.root.children[1].locked, true)
    assert(not DesignModel.generate(d, "main"):find("ocked", 1, true))
    local copy = assert(DesignModel.paste(d, d.root, DesignModel.fragment(a), { index = 2 }))
    eq(copy.locked, nil); eq(a.locked, true); eq(copy.name, "button2")
end)

-- TABLE CONTENTS ------------------------------------------------------------

check("table contents pad every row and the titles to one width", function()
    local t = DesignModel.node("ui.Table")
    t.props.columnHeaders = { "Name" }
    t.props.rowCount = 3
    t.cells = { { "Ada", "1815" } }
    local c = DesignModel.tableContents(t)
    eq(#c.headers, 2); eq(c.headers[1], "Name"); eq(c.headers[2], "")
    eq(#c.rows, 3); eq(c.rows[1][2], "1815"); eq(c.rows[3][1], ""); eq(#c.rows[3], 2)
    local empty = DesignModel.tableContents(DesignModel.node("ui.Table"))
    eq(#empty.headers, 0); eq(#empty.rows, 0)
end)

check("setting table contents writes titles, counts and only filled cells", function()
    local t = DesignModel.node("ui.Table")
    DesignModel.setTableContents(t, { headers = { "Name", "Born" },
        rows = { { "Ada", "1815" }, { "Grace", "" } } })
    eq(t.props.columnHeaders[2], "Born"); eq(t.props.columnCount, nil); eq(t.props.rowCount, 2)
    eq(t.cells[2][1], "Grace"); eq(t.cells[2][2], "")
    -- untitled columns are a count, not a row of blank titles
    DesignModel.setTableContents(t, { headers = { "", "", "" }, rows = { { "", "", "" } } })
    eq(t.props.columnHeaders, nil); eq(t.props.columnCount, 3); eq(t.props.rowCount, 1)
    eq(t.cells, nil)
    DesignModel.setTableContents(t, { headers = {}, rows = {} })
    eq(t.props.columnCount, nil); eq(t.props.rowCount, nil)
end)

check("a table's cells generate after its rows and columns, and round-trip", function()
    local d = DesignModel.blank()
    local t = DesignModel.node("ui.Table")
    DesignModel.insert(d, d.root, t, { index = 1 })
    DesignModel.setTableContents(t, { headers = { "Name", "Born" },
        rows = { { "Ada", "1815" }, { "", "1906" } } })
    local text = DesignModel.generate(d, "people")
    local headers = text:find('w.table1:setColumnHeaders({ "Name", "Born" })', 1, true)
    local count = text:find("w.table1:setRowCount(2)", 1, true)
    local first = text:find('w.table1:setCellText(1, 1, "Ada")', 1, true)
    assert(headers and count and first and headers < first and count < first, text)
    assert(text:find('w.table1:setCellText(2, 2, "1906")', 1, true), text)
    assert(not text:find("setCellText(2, 1,", 1, true), text)
    local M = runGenerated(text)
    assert(M.new().table1)
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.root.children[1].cells[1][2], "1815")
end)

check("deserialize refuses cells that are not rows of text", function()
    local d = DesignModel.blank()
    local t = DesignModel.node("ui.Table")
    DesignModel.insert(d, d.root, t, { index = 1 })
    t.cells = { { "fine", 42 } }
    local design, why = DesignModel.deserialize(DesignModel.serialize(d))
    eq(design, nil); assert(why:find("is not text", 1, true), why)
    t.cells = { "flat" }
    design, why = DesignModel.deserialize(DesignModel.serialize(d))
    eq(design, nil); assert(why:find("is not a row", 1, true), why)
end)

-- SEVERAL AT ONCE -----------------------------------------------------------

local function columnOf(d, ...)
    local nodes = {}
    for i, class in ipairs({ ... }) do
        nodes[i] = DesignModel.node(class)
        DesignModel.insert(d, d.root, nodes[i], { index = i })
    end
    return nodes
end

check("several move into a container side by side, in the order given", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    local a, b, c = table.unpack(columnOf(d, "ui.Button", "ui.Label", "ui.LineEdit"))
    -- columnOf put them first: root = a, b, c, box
    assert(DesignModel.moveMany(d, { a, c }, box, { index = 1 }))
    eq(box.children[1], a); eq(box.children[2], c); eq(#d.root.children, 2)
    eq(a.stretch, 0)
    -- within the same container, to its end
    assert(DesignModel.moveMany(d, { box, b }, d.root, { index = 1 }))
    eq(d.root.children[1], box); eq(d.root.children[2], b)
end)

check("several moving into a grid take one row after another", function()
    local d = DesignModel.blank()
    local grid = DesignModel.container("ui.GridLayout")
    DesignModel.insert(d, d.root, grid, { index = 1 })
    local a, b = table.unpack(columnOf(d, "ui.Button", "ui.Button"))
    assert(DesignModel.moveMany(d, { a, b }, grid, { row = 2, column = 3 }))
    eq(a.grid.row, 2); eq(b.grid.row, 3); eq(b.grid.column, 3)
end)

check("a node inside another of the same selection moves with it, not twice", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    local inner = DesignModel.node("ui.Button")
    DesignModel.insert(d, box, inner, { index = 1 })
    local target = DesignModel.container("ui.VLayout")
    DesignModel.insert(d, d.root, target, { index = 2 })
    assert(DesignModel.moveMany(d, { box, inner }, target, { index = 1 }))
    eq(target.children[1], box); eq(box.children[1], inner)
end)

check("a refused move of several leaves nothing half done for the snapshot to undo", function()
    local d = DesignModel.blank()
    local a, b = table.unpack(columnOf(d, "ui.Button", "ui.Button"))
    assert(DesignModel.setLocked(d, b, true))
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 3 })
    local ok, why = DesignModel.moveMany(d, { a, b }, box, { index = 1 })
    eq(ok, false); assert(why:find("locked", 1, true), why)
end)

check("deleting several is refused whole if any holds a lock", function()
    local d = DesignModel.blank()
    local a, b, c = table.unpack(columnOf(d, "ui.Button", "ui.Button", "ui.Button"))
    assert(DesignModel.setLocked(d, c, true))
    local ok, why = DesignModel.removeMany(d, { a, c })
    eq(ok, false); assert(why:find("locked", 1, true), why); eq(#d.root.children, 3)
    assert(DesignModel.removeMany(d, { a, b }))
    eq(#d.root.children, 1); eq(d.root.children[1], c)
end)

-- ALIGN AND DISTRIBUTE ------------------------------------------------------

check("aligning sets where a widget sits in its slot, and fill clears it", function()
    local d = DesignModel.blank()
    local a, b = table.unpack(columnOf(d, "ui.Button", "ui.Button"))
    assert(DesignModel.align(d, { a, b }, "right"))
    eq(a.halign, "right"); eq(b.halign, "right")
    assert(DesignModel.align(d, { a }, "bottom"))
    eq(a.valign, "bottom"); eq(a.halign, "right")
    assert(DesignModel.align(d, { a }, "hfill"))
    eq(a.halign, nil); eq(a.valign, "bottom")
    eq((DesignModel.align(d, { d.root }, "left")), false)
    eq((DesignModel.align(d, { a }, "sideways")), false)
    -- a pane fills its splitter: there is no slot to align in
    local split = DesignModel.node("ui.Splitter")
    DesignModel.insert(d, d.root, split, { index = 3 })
    local pane = DesignModel.node("ui.Label")
    DesignModel.insert(d, split, pane, { index = 1 })
    local ok, why = DesignModel.align(d, { pane }, "left")
    eq(ok, false); assert(why:find("fills", 1, true), why)
end)

check("an alignment generates after the widget is added, and round-trips", function()
    local d = DesignModel.blank()
    local a = columnOf(d, "ui.Button")[1]
    assert(DesignModel.align(d, { a }, "hcenter"))
    assert(DesignModel.align(d, { a }, "top"))
    local text = DesignModel.generate(d, "aligned")
    local added = text:find("rootLayout:addChild(w.button1)", 1, true)
    local aligned = text:find('rootLayout:setChildAlignment(w.button1, "hcenter", "top")', 1, true)
    assert(added and aligned and added < aligned, text)
    runGenerated(text)
    local back = assert(DesignModel.deserialize(DesignModel.serialize(d)))
    eq(back.root.children[1].halign, "hcenter")
    back.root.children[1].halign = "top"          -- a vertical name on the horizontal axis
    local bad, why = DesignModel.deserialize(DesignModel.serialize(back))
    eq(bad, nil); assert(why:find("horizontal alignment", 1, true), why)
end)

check("distributing gives a row's or column's widgets the same stretch", function()
    local d = DesignModel.blank()
    local a, b = table.unpack(columnOf(d, "ui.Button", "ui.Button"))
    assert(DesignModel.distribute(d, { a, b }))
    eq(a.stretch, 1); eq(b.stretch, 1)
    eq((DesignModel.distribute(d, { a })), false)
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 3 })
    local c = DesignModel.node("ui.Button")
    DesignModel.insert(d, box, c, { index = 1 })
    local ok, why = DesignModel.distribute(d, { a, c })
    eq(ok, false); assert(why:find("same row or column", 1, true), why)
end)

-- PREVIEW -------------------------------------------------------------------

check("a preview carries the images its design names, and their map", function()
    local Files = require("gui.views.designer.files")
    local sep = package.config:sub(1, 1)
    local project = FS.joinPaths(os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp",
        "limer-preview-check-" .. tostring(os.time()))
    local root = FS.joinPaths(project, "images")
    FS.createFolder(FS.joinPaths(root, "brand"))
    FS.writeFile(FS.joinPaths(root, "brand" .. sep .. "logo.png"), "png")
    FS.writeFile(FS.joinPaths(root, "unused.png"), "png")

    local d = DesignModel.blank()
    d.window.icon = "logo"
    local dir = assert(Files.writePreview(project, "main", DesignModel.generate(d, "main"), d))
    local copied = FS.joinPaths(dir, "images" .. sep .. "brand" .. sep .. "logo.png")
    assert(FS.exists(copied), "logo.png copied, folder kept")
    assert(not FS.exists(FS.joinPaths(dir, "images" .. sep .. "unused.png")), "only what the design uses")
    local map = FS.readFile(FS.joinPaths(dir, "scripts" .. sep .. "designed" .. sep .. "images.lua"))
    assert(map:find('logo = res.Resources.images("brand/logo.png")', 1, true), map)
    assert(not map:find("unused", 1, true), map)

    -- A design with no images gets no images folder and no map.
    local plain = FS.joinPaths(project, "plain")
    FS.createFolder(plain)
    local d2 = DesignModel.blank()
    local dir2 = assert(Files.writePreview(plain, "main", DesignModel.generate(d2, "main"), d2))
    assert(not FS.exists(FS.joinPaths(dir2, "scripts" .. sep .. "designed" .. sep .. "images.lua")))
end)

print(string.format("\n%d checks, %d failed", count, failures))
sys.System.exit(failures == 0 and 0 or 1)
