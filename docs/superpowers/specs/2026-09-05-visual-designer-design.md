# Limer Visual Designer — Design

Date: 2026-09-05
Repos: `Limekit` (framework, Python) and `Limer-Limekit` (launcher, Lua)

## Goal

A drag-and-drop designer inside Limer for building Limekit windows. Widgets
are dragged from a palette onto a canvas of real Limekit widgets, arranged
inside layouts, edited through a property panel, saved as a design file the
designer reads back, and generated as a Lua module a project's `main.lua`
requires.

## Decisions (fixed)

1. **Layouts, not coordinates.** A widget goes into a column, row, grid or
   form at a slot. No free placement, no resize handles. Size is a property.
2. **The model is the truth.** The canvas is rebuilt from the model after
   every change. The generated Lua is never read back.
3. **Design files persist** at `design/<name>.design.lua` in the project, one
   per window, as a plain Lua table. Limer reads them back.
4. **Generation writes a module** at `scripts/designed/<name>.lua` that
   returns `{ window = ..., <widgetName> = ... }`. `main.lua` requires it and
   wires handlers by name. `main.lua` is never touched.
5. **Drag and drop lives in Limekit (Python).** Lua cannot see Qt drag events.
   The framework reports *what* was dropped *where*; Limer decides what that
   means for the model.
6. **Undo/redo by snapshot.** Each mutation pushes a deep copy of the model.

## Part 1 — Limekit (framework)

### 1.1 `ui.DesignSurface` gains drop handling

File: `limekit/widgets/designsurface.py` (existing). Additions:

**Drop target resolution.** During a drag, for the cursor position:

- Find the deepest inert widget under the cursor (existing `_deepest_at`).
- Walk up parents until a widget with a `QLayout` of a supported kind is
  found: `QVBoxLayout`, `QHBoxLayout`, `QGridLayout`, `QFormLayout`. This is
  the *target container*. The design child itself is always eligible if it
  has such a layout. If none is found, the drop is refused (cursor shows
  forbidden, no indicator).
- Compute the *slot* by layout kind, using each item's geometry in the
  container's coordinates:
  - Box layouts: index `i` in `1..count+1`. Cut at each item's midpoint along
    the layout axis; the cursor before the midpoint of item `k` gives slot
    `k`; after all, `count+1`. Stretch and spacing items count, so the index
    maps 1:1 to `QLayout.itemAt`.
  - Grid: `row`, `column` from `QGridLayout.cellRect` over the current
    `rowCount()`/`columnCount()`. Past the last row or column extends the
    grid: row `rowCount()+1` or column `columnCount()+1`. Occupied cells are
    still reported; Limer decides whether to allow them.
  - Form: `index` in `1..rowCount()+1`, cut at row midpoints.
- A moved widget cannot be dropped into itself or any of its descendants.

**Indicator painting.** In `paintEvent`, after the selection rectangle:

- Box: a 3px bar across the slot boundary, perpendicular to the axis.
- Grid: the target cell rectangle, 2px outline, 15% fill.
- Form: a 3px horizontal bar at the row boundary.
- Also a 1px outline of the target container, so nested drops read clearly.

**Mime types.**

- `application/x-limekit-class`: payload is the Lime class name, e.g.
  `ui.Button`. Produced by `ui.WidgetPalette`.
- `application/x-limekit-move`: payload is the id of the widget being
  moved; the surface keeps `self._dragging` as the actual reference.
  Produced by the surface itself.

**Starting a move.** `mousePressEvent` records the hit and press position.
`mouseMoveEvent` beyond `QApplication.startDragDistance()` on a hit that is
not the design child starts a `QDrag` with the move mime. Escape cancels it
(Qt handles). Selection happens on press, as today, so a click still selects.

**Events to Lua.**

- `setOnDrop(handler)`: `handler(drop)` where `drop` is a table:
  ```lua
  {
    kind   = "class" | "move",
    class  = "ui.Button",   -- kind == "class"
    widget = <widget>,      -- kind == "move"
    target = <container widget>,
    layout = "vbox" | "hbox" | "grid" | "form",
    index  = 3,             -- vbox, hbox, form
    row    = 2, column = 1, -- grid
  }
  ```
  Handlers go through `guard(...)`. The surface performs no mutation.
- `setOnSelect(handler)`: unchanged.
- `setDropEnabled(bool)`: default true; lets Limer disable while loading.

A pure module-level function `resolve_drop(surface, position, dragging=None)`
returning the slot dict (or `None`) does all hit-testing, so tests call it
without synthesizing a full drag.

### 1.2 `ui.WidgetPalette` (new)

File: `limekit/widgets/widgetpalette.py`. A `QListWidget`-based widget with a
`QLineEdit` filter above it. Items are the classes from
`Introspect.buildableClasses()` that are widgets, shown with the `ui.`
prefix stripped, grouped under headers:

- Containers: Container, GroupBox, Scroller, Splitter, Tab, Accordion
- Inputs: Button, CheckBox, RadioButton, LineEdit, TextField, ComboBox,
  FontComboBox, Spinner, DoubleSpinner, Slider, AdvancedSlider, Knob,
  DatePicker, TimePicker, Calendar
- Display: Label, Image, ProgressBar, LCDNumber, GifPlayer, HLine, VLine,
  Separator
- Data: ListBox, Table, TreeView, TreeWidget
- Anything buildable but unlisted: Other

Grouping is a static table in the module; a new widget lands in Other
without editing the palette. Only classes present in `buildableClasses()`
are shown, so nothing offered can fail to build.

Items are drag sources: `startDrag` builds a `QDrag` with
`application/x-limekit-class`. Double-click emits `onPick(className)` so
keyboard-only use still works. Methods: `setOnPick(handler)`,
`getSelectedClass()`, `setFilter(text)`, `getClasses()`.

Registered in the manifest and stubs via the existing generators
(`tools/generate_manifest.py`, `tools/generate_stubs.py`,
`tools/generate_api_index.py`).

### 1.3 Tests (pytest, offscreen)

`tests/widgets/test_designsurface_drop.py`:

- vbox: cursor above midpoint of child 2 → index 2; below last → count+1.
- hbox: same along x.
- grid 2x2: cursor in cell (2,1) → row 2, column 1; right of last column →
  column 3.
- form with 2 rows: cursor between rows → index 2.
- nested: a Container inside a Container; cursor over the inner one targets
  the inner; over the outer's margin targets the outer.
- move source cannot target itself or its descendant.
- a synthesized `QDropEvent` with class mime calls `onDrop` with
  `kind == "class"` and the resolved slot; the surface adds no widget.

`tests/widgets/test_widgetpalette.py`:

- every item's class is buildable; filter narrows; double-click emits pick;
  mime data for an item carries the class.

Manifest, stubs and API index tests already exist and will catch the new
class if the generators are not re-run.

## Part 2 — Limer (designer)

### 2.1 Model (`scripts/app/core/design_model.lua`)

Node shape:

```lua
{
  class    = "ui.Button",         -- Lime class
  name     = "button1",           -- unique per design, Lua identifier
  props    = { text = "OK" },     -- only values the user set
  -- containers only:
  layout   = "ui.VLayout" | "ui.HLayout" | "ui.GridLayout" | "ui.FormLayout",
  children = { ... },
  -- placement, read by the parent's layout:
  grid     = { row = 1, column = 1, rowSpan = 1, columnSpan = 1 },  -- in a grid
  form     = { label = "Name" },                                    -- in a form
  stretch  = 0,                                                     -- in a box
}
```

Pseudo-nodes for box layouts: `{ kind = "stretch", stretch = 1 }` and
`{ kind = "spacing", size = 12 }`. They have no `class` and no name.

Design shape, and the file at `design/<name>.design.lua`:

```lua
return {
  version = 1,
  window  = { title = "My App", width = 640, height = 480 },
  root    = <node>,
}
```

Operations, all pure, mutations returning `true` or `false, reason`:

- `blank()`, `node(class)`, `container(layout)`, `stretch()`, `spacing(n)`
- `insert(design, parent, node, slot)` where slot is `{ index = }` or
  `{ row =, column = }`; a grid drop into an occupied cell is refused.
- `move(design, node, parent, slot)`: remove then insert, index adjusted
  when moving within the same parent to a later slot. Refuses descendants.
- `remove(design, node)`, `wrap(design, node, layout)` (replace node with a
  new container holding it), `unwrap(design, container)` (only if it has
  exactly one child).
- `setLayout(container, layout)`: converts placement data. Box→grid puts
  children down one column; grid→box orders children row-major; anything→form
  gives label = name. Pseudo-nodes are dropped when leaving a box layout.
- `rename(design, node, name)`: must be a Lua identifier, unique in the
  design, not a reserved word, not `window` or `root`.
- `serialize(design)` → Lua source of the design table, keys sorted;
  `deserialize(source)` → design or `nil, reason`. Loading runs the chunk in
  an empty environment.
- `snapshot(design)` deep copy; `Undo.new()` with `push`, `undo`, `redo`,
  `canUndo`, `canRedo`, depth-limited to 200.
- `generate(design, moduleName)` → Lua source:

```lua
-- GENERATED by Limer's designer from design/login.design.lua.
-- Regenerate from the designer; edits here are overwritten.
local ui = require("limekit.ui")

local M = {}

M.root = ui.Container()
M.name = ui.LineEdit()
M.name:setHint("Your name")
M.ok = ui.Button()
M.ok:setText("OK")

local rootLayout = ui.FormLayout()
rootLayout:addChild("Name", M.name)
rootLayout:addChild("", M.ok)
M.root:setLayout(rootLayout)

M.window = ui.Window { title = "Login" }
M.window:setSize(400, 200)
M.window:setMainChild(M.root)

return M
```

Box children: `addChild(w, stretch)`, `addStretch(n)`, `addSpacing(n)`.
Grid: `addChild(w, row, column, rowSpan, columnSpan)`. Form:
`addChild(label, w)`. Nested containers emit their own layout local named
`<name>Layout`. Output is deterministic: props sorted by key, children in
order. Values: strings via `%q`, numbers, booleans. The generate dialog
shows the `main.lua` usage:

```lua
local login = require("designed.login")
login.ok:setOnClick(function() ... end)
login.window:show()
```

### 2.2 View (`scripts/gui/views/designer/`)

Split into modules, each with one job:

- `view.lua` — assembles the tab, owns the designer state, routes events.
- `canvas.lua` — builds widgets from the model onto the surface
  (`rebuild`), maps node↔widget, translates surface drop events into model
  slots (target widget → node).
- `outline.lua` — a `ui.TreeView` mirroring the model; click selects;
  expanded by default.
- `properties.lua` — a `ui.Table` of the selected node's settable
  properties: booleans as `ui.CheckBox` cell children, enums as
  `ui.ComboBox` cell children, ints/floats/strings as editable text. Plus a
  fixed top section: `name`, layout kind (containers), placement (grid
  row/column/spans, form label, box stretch). Value column stretches.
- `preview.lua` — a read-only `ui.TextField` showing `generate()` output,
  refreshed after every model change.
- `files.lua` — lists `design/*.design.lua` for the open project; open,
  save, save-as, new; tracks dirty state and asks before discarding.

Layout of the tab:

```
[toolbar: New Open Save | Undo Redo | Wrap Row  Wrap Column  Delete | Generate]
[design picker v]  [title ____] [w ___] [h ___]
+---------+--------------------------------+------------------------+
| palette |  canvas (surface, framed to    | tabs: Outline | Props  |
| search  |  window width x height,        |       | Code            |
| groups  |  scrollable if larger)         |                        |
+---------+--------------------------------+------------------------+
[status]
```

Behaviour:

- Drop from palette: `insert` at slot, select the new node.
- Drop of a placed widget: `move`.
- Palette double-click: insert into the selection if it is a container,
  else after the selection, else at the end of the root.
- Delete key / button: `remove`. Root cannot be removed.
- Ctrl+Z / Ctrl+Y, Ctrl+S, Ctrl+Shift+S; arrow Up/Down move within siblings.
- Wrap Row/Column: `wrap` the selection.
- Right-click on canvas or outline: context menu with Wrap, Unwrap, Delete,
  Add stretch, Add spacing, Change layout (Column, Row, Grid, Form).
- Every mutation: push undo, rebuild canvas, refresh outline, refresh
  preview, mark dirty, set status.
- Generate: writes `scripts/designed/<name>.lua`, creating the folder, logs
  the path to the console, shows the require snippet. Never touches
  `main.lua`.
- Opening a project loads the first design file if any; otherwise a blank
  unsaved design named `main`.

### 2.3 Wiring

- `project_tab_container.lua`: show the Designer tab again.
- `README.md`: rewrite "The Designer" section; drop "No widget palette in the
  dock" (the palette now lives inside the designer tab, where there is a
  canvas).
- `scripts/data/api_index.lua`: regenerate from Limekit.

### 2.4 Tests

Limer ships no Python, so its tests are a Limekit project:
`Limer-Limekit/tests/` with `app.json` and `scripts/main.lua` that adds
`../../scripts/?.lua` to `package.path`, requires the model, runs check
functions, prints `ok`/`FAIL` lines and exits non-zero on failure. Run with:

```
python -m limekit tests
```

Checks: insert/move/remove across all four layouts, grid occupied refusal,
descendant-move refusal, wrap/unwrap, setLayout conversions, rename
validation, serialize→deserialize round trip, undo/redo, generate
determinism (same design twice → same text) and generate output loads as Lua
and returns a table with the expected keys when run against a stub `ui`.

## Error handling

- A class that fails to build on the canvas shows a placeholder `ui.Label`
  reading `<class> failed: <error>` in red, and the node is kept. The
  generator still emits it.
- A design file that fails to load is reported in the status bar and the
  console; the current design is untouched.
- Property set failures revert the model value and show the reason.
- Drops with no valid target are refused by the surface; nothing reaches Lua.

## Out of scope

Free placement and resize handles; event wiring in the designer (handlers
belong in `main.lua`); menus, toolbars, docks and status bars; multiple
windows in one design; reading generated Lua back.
