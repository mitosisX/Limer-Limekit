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
    assert(a:find('M.name:setHint("Your name")', 1, true), a)
    assert(a:find('rootLayout:addChild("Name", M.name)', 1, true), a)
    assert(a:find('container1Layout:addStretch(1)', 1, true), a)
    assert(a:find('container1Layout:addSpacing(6)', 1, true), a)
    assert(a:find('container1Layout:addChild(M.ok, 2)', 1, true), a)
    assert(a:find('M.window = ui.Window { title = "Login" }', 1, true), a)
    assert(a:find('M.window:setSize(400, 200)', 1, true), a)
    assert(a:find('M.window:setMainChild(M.root)', 1, true), a)
    assert(a:find('design/login.design.lua', 1, true), a)

    local M = runGenerated(a)
    assert(M.window and M.root and M.name and M.ok and M.container1)
    eq(M.window.title, "Login")
end)

check("generate emits grid placement", function()
    local d = DesignModel.blank()
    DesignModel.setLayout(d, d.root, "ui.GridLayout")
    local a = DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { row = 2, column = 3 })
    a.grid.columnSpan = 2
    local text = DesignModel.generate(d, "grid")
    assert(text:find("rootLayout:addChild(M.button1, 2, 3, 1, 2)", 1, true), text)
    runGenerated(text)
end)

check("generate builds inner layouts before the outer one uses them", function()
    local d = DesignModel.blank()
    local box = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, box, { index = 1 })
    DesignModel.insert(d, box, DesignModel.node("ui.Label"), { index = 1 })
    local text = DesignModel.generate(d, "nested")
    local inner = text:find("M.container1:setLayout(container1Layout)", 1, true)
    local outer = text:find("rootLayout:addChild(M.container1)", 1, true)
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
    assert(text:find('M.tab1:addTab(M.container1, "First")', 1, true), text)
    assert(text:find("M.splitter1:addChild(M.listBox1)", 1, true), text)
    assert(text:find("M.scroller1:setChild(M.label1)", 1, true), text)
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

print(string.format("\n%d checks, %d failed", count, failures))
sys.System.exit(failures == 0 and 0 or 1)
