# Designer Pixel-Perfect Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gap between Limer's drag-and-drop designer and a canvas that feels pixel-perfect (DecSoft AppBuilder was the reference point: snap-to-grid, smart alignment guide lines, zoom, multi-select, align/distribute, z-order), and fix the properties editor so a Table or ComboBox can actually be populated with design-time data instead of a flattened comma string.

**Origin:** Reverse-engineered DecSoft AppBuilder (`C:\Program Files\DecSoft\AppBuilder\AppBuilder.exe`, a Delphi/VCL app) to see what its canvas is built from — `TcyGuideLines`, `TcyResizer`, `TcyGrid`, and actions `AlignLeftAction`/`AlignRightAction`/`HorizontalCentersAction`/`VerticalCentersAction`/`AlignToGridAction`/`ZoomInAction`/`ZoomOutAction`/`ZoomResetAction` — found as strings in the binary. Cross-checked against this repo's `ui.DesignSurface` (`scripts/data/api_index.lua:642-689`) and `scripts/gui/views/designer/{canvas,properties,view}.lua` to find exactly what exists today and what's missing.

**Architecture:** Two repos, same split as the original designer build:
- `D:\Personal Dev\Limekit Project\Limekit` (Python/PySide6) — owns `ui.DesignSurface` itself. Phase 2 of this plan lives here.
- `D:\Personal Dev\Limekit Project\Limer-Limekit` (Lua, branch `limekit-2.0-port`) — owns the design model, the canvas/properties/view wiring, and everything that doesn't need a new native capability. Phase 1 and Phase 3 live here.

**Tech stack:** PySide6 (DesignSurface), Lua 5.4 via the Limekit 2.0 engine (designer UI and model).

## Global constraints

- Limer ships no Python; nothing Python goes into `Limer-Limekit`.
- `design_model.lua` generation is **one-way**: the designer never reads a generated file back. Nothing in this plan changes that — event/script wiring stays in `main.lua`, by hand, same as today.
- After any change to `ui.DesignSurface` in the Limekit repo, regenerate Limer's `scripts/data/api_index.lua` (`python tools/generate_api_index.py` from the Limekit repo) before touching the Lua side that depends on the new API.
- Every index crossing into Lua is 1-based; Qt/PySide is 0-based. Translate at the boundary, as the rest of `design_model.lua` already does.

---

## Status

| # | Phase | Task | Depends on | Status |
|---|-------|------|------------|--------|
| 1.1 | 1 — Lua-only (Limer) | Generalize "Wrap in ▸" (Row, Column, Grid, Form, Scroller, GroupBox, Splitter, Tab) | — | Done (2026-10-22) |
| 1.2 | 1 — Lua-only (Limer) | Z-order: bring to front / send to back — built as "Move to start / Move to end" | — | Done (2026-10-22) |
| 1.3 | 1 — Lua-only (Limer) | Lock widget | — | Done (2026-10-22) |
| 1.4a | 1 — Lua-only (Limer) | Structured list editor modal (ComboBox/ListBox/Dropdown items) | — | Done (2026-10-22) |
| 1.4b | 1 — Lua-only (Limer) | Table data editor modal (cell data, not just headers) | `ui.Table:setCellText` exists — met | Done (2026-10-22) |
| F1 | Fixes — Lua (Limer) | Console readable in dark mode (black `inherit` text, light-only colours) | — | Done (2026-10-22) |
| F2 | Fixes — Lua (Limer) | Form rows editable from the form itself (a "Rows" section in Properties) | — | Done (2026-10-22) |
| F3 | Fixes — Native theming (Limekit) | No pure-black tables/headers in dark mode (qdarktheme `QTableView` rule, palette never applied) | — | Done (2026-10-22) |
| F4 | Fixes — Native DesignSurface (Limekit) | Hover/click/double-click/right-click land on the design widget, never a Qt internal ("QWidget") | — | Done (2026-10-22) |
| F5 | Fixes — Native + Lua (both) | Form labels selectable and editable on the canvas | F4 | Done (2026-10-22) |
| F6 | Fixes — Native DesignSurface (Limekit) | A white, blue-edged box the size of the design flashes at the canvas's top-left on save and edits | — | Done (2026-10-22) |
| F7 | Fixes — Lua (Limer) | Run fails once a design uses an image: the preview project gets no `designed/images.lua` or `images/` | — | Done (2026-10-22) |
| 2.1 | 2 — Native DesignSurface (Limekit) | Zoom (in/out/reset, correct hit-testing at scale) | — | Done (2026-10-22) |
| 2.2 | 2 — Native DesignSurface (Limekit) | Grid + snap-to-grid (a resize snaps; the backdrop dots are the grid) | — | Done (2026-10-22) |
| 2.3 | 2 — Native DesignSurface (Limekit) | True multi-select (marquee + Ctrl/Shift-click) | — | Done (2026-10-22) |
| 2.4 | 2 — Native DesignSurface (Limekit) | Multi-widget resize/move | 2.3, benefits from 2.2 | Done (2026-10-22) |
| 2.5 | 2 — Native DesignSurface (Limekit) | Smart guide lines while resizing (edges and sizes) | 2.2 | Done (2026-10-22) |
| 3.1 | 3 — Lua, unlocked by Phase 2 (Limer) | Align in slot / match size / distribute evenly | 2.3 | Done (2026-10-22) |

**Build order:** 1.1 → 1.2/1.3 → 1.4a → 1.4b → F1 → F2 → F3 → F4 → F5 → F6 → F7 → 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 3.1

The fixes go before Phase 2 on purpose: F4 rewrites how `ui.DesignSurface` decides what is under the mouse, and zoom (2.1), snapping (2.2) and multi-select (2.3) all build on that same hit-testing.

---

## Phase 1 — Lua-only, ship these first

No native changes needed; all in `Limer-Limekit`.

**Done 2026-10-22.** What shipped, and where it differs from the tasks below:
- 1.1 — `DesignModel.wrap(design, node, how)` takes any of `DesignModel.WRAPPERS`; the Arrange menu and right-click have a "Wrap in" submenu (the Row/Column toolbar buttons stay). Wrapping also keeps a tab page's title now, and `unwrap` refuses to leave a plain widget straight inside a Tab.
- 1.2 — In a laid-out design siblings never overlap, so z-order *is* layout order: `DesignModel.reorder(design, node, "first"|"last")`, as **Move to start / Move to end** (Ctrl+Shift+Up/Down). Refused in a grid, like Move up/down.
- 1.3 — `node.locked`, enforced in the model (`move`, `remove`, `wrap`, `unwrap`, `reorder` refuse; `remove` also refuses a container holding a locked widget) and by the resize handle in the view. Lock is in Arrange (Ctrl+L), right-click and Properties; the outline and the canvas tag mark it. A paste arrives unlocked. Never generated.
- 1.4a — `gui/modals/list_editor.lua`. Every `list` catalogue row (ComboBox/ListBox items, TreeView header labels) is a button that opens it; double-clicking the widget does too.
- 1.4b — `gui/modals/table_editor.lua`, plus `DesignModel.tableContents` / `setTableContents` and a new `node.cells` field (rows of strings, validated on load). The Table's `columnHeaders`/`rowCount` catalogue rows were replaced by one "contents" row; blank titles become `columnCount`. Cells generate as `setCellText(r, c, text)` after the row and column setters.
- Checks: 12 new model checks in `tests/scripts/main.lua` (51 total, all passing), plus an offscreen run of the real designer window that drives the real editors.

### Task 1.1: Generalize "Wrap in ▸"

**Files:**
- Modify: `scripts/app/core/design_model.lua` — extend `wrap()` so it can build a `Tab`/`Splitter`/`Scroller`/`GroupBox` holder, not only a layout `Container` (today it always calls `DesignModel.container(layout)`)
- Modify: `scripts/gui/views/designer/view.lua` — replace the two "Wrap in a row"/"Wrap in a column" items (`view.lua:700-702,835-837,874-877`) with a "Wrap in ▸" submenu: Row, Column, Grid, Form, Scroller, GroupBox, Splitter, Tab

**Done when:** right-click any non-root widget shows "Wrap in ▸" with all 8 options; each produces a valid design; `unwrap()` still reverses each.

### Task 1.2: Z-order (bring to front / send to back)

**Files:**
- Modify: `scripts/app/core/design_model.lua` — new `DesignModel.reorder(design, node, direction)`, moves the node within `parent.children`
- Modify: `scripts/gui/views/designer/view.lua` — two new menu items + shortcuts, same pattern as Duplicate/Delete

**Done when:** overlapping siblings inside a `Container` visibly reorder; undo works through the same path as Duplicate/Delete.

### Task 1.3: Lock widget

**Files:**
- Modify: `scripts/app/core/design_model.lua` — a `node.locked` flag
- Modify: `scripts/gui/views/designer/canvas.lua` — `onSelect`/`onDrop` ignore a locked node as a drag source
- Modify: `scripts/gui/views/designer/view.lua` — menu toggle
- Modify: `scripts/gui/views/designer/properties.lua` — show lock state

**Done when:** a locked widget can't be dragged or resized, but can be unlocked via outline or menu.

### Task 1.4a: Structured list editor

**Files:**
- Create: `scripts/gui/modals/list_editor.lua` — a small modal: one-column `ui.Table`, add/remove/reorder rows, OK writes back the same `{ "A", "B", "C" }` shape `Catalog.parse("list", ...)` already produces
- Modify: `scripts/gui/views/designer/properties.lua` — new row kind (e.g. `"list-editor"`) replacing the `"parsed"` comma-cell for `items`-type catalog entries

**Done when:** ComboBox/ListBox/Dropdown `items` are edited through the modal, not a comma-separated cell; `onProp`/`Canvas.apply` need no changes since the stored shape is unchanged.

### Task 1.4b: Table data editor

**Files:**
- Modify: `scripts/app/core/design_model.lua` — a `node.props.data` shape (array of row arrays) alongside existing `columnHeaders`/`rowCount`, plus generation support
- Modify: `scripts/gui/views/designer/properties.lua` — button cell opening the editor
- Create: `scripts/gui/modals/table_editor.lua` — modal `ui.Table` sized to `columnHeaders` × `rowCount`, editable per cell
- Modify: `scripts/gui/views/designer/canvas.lua` — in `Canvas.apply`/`build`, after `setColumnHeaders`/`setRowCount`, loop `data` and set each cell

**Precondition:** confirm `ui.Table`/`ui.TableItem` exposes a per-cell setter in `scripts/data/api_index.lua`. If it doesn't, this is a Limekit (Python) framework ask first — add the setter there, regenerate `api_index.lua`, then do this task.

**Done when:** a Table dropped on the canvas can have its actual cell values set at design time and they show up both in the canvas preview and the generated module.

---

## Fixes found in use

Reported after Phase 1 shipped (2026-10-22), each traced to its cause before being written down.

**Done 2026-10-22** (F1–F5 complete; F6 partly). What shipped, and where it differs from the tasks below:
- F1 — `console.lua` keeps each line as `{ kind, prefix, text }` (the last 3000) and re-renders them on `Theme.observe`; light and dark colour sets; plain lines carry an uncoloured `<span>` (without any tag, Qt's `append` takes the text as plain and the escaped `>>` showed as `&gt;&gt;`). Verified by reading the rendered document's colours in both themes.
- F2 — a "Rows" section on a FormLayout container's Properties, one row per field.
- F3 — `_set_darklight` applies `qdarktheme.load_palette` and, for dark only, overrides `QTableView` and its header with the palette's Base (`#202124`, what lists and trees already sit on). Measured: tables were `#000000`, now `#202124`; light tables still `#ffffff`. Fixes every `ui.Table` — canvas, designer Properties, the Phase 1 editors, Limer's Inspector.
- F4 — `DesignSurface._design_widget` / `_hit` climb from Qt's innermost widget to the nearest labelled widget (or nearest Limekit widget when nothing is labelled), for press/select, drag start, context menu, double-click and hover; `_label` falls back to the Limekit class name. **Also found and fixed:** a drop on a composite widget (a Calendar, built from Qt's own `QVBoxLayout`) landed *inside* it and gave it a container outline — `_container_kind` now counts only Limekit's own layouts and holders.
- F5 — `FormLayout:addChild(labelWidget, field)` (Limekit); the canvas builds each row's label as a `ui.Label`, maps it to its field (`Canvas.formLabels`, `Canvas:isFormLabel`); click selects the field, drag moves it, double-click renames the label. Generated code still uses the string form.
- F6 — `setDesignChild` now clears a running flash (it outlived the design it lit). `LIMEKIT_DEBUG_PAINT=1` (stderr) or `=<path>` logs top-level shows, native handles, and Show/Paint/Move/Resize of large widgets in a surface's window, deduplicated per widget. Replaying the user's own design (`Limer GUI Check/design/main.design.lua`) natively through saves, an edit then a save mid-flash, and undo: nothing appears at the surface's top-left. The box is still unexplained; the log is the next step, run inside real Limer.
- Checks: Limekit — `tests/widgets/test_designsurface_hits.py` (8), `test_designsurface_flash.py` (4), two theming checks, one FormLayout check; each new check confirmed to fail on the old code; the whole suite passes. Limer — model checks 51/51, the Phase 1 smoke run 9/9, and a 12-check run with real mouse events (QTest) on the real designer for F2/F4/F5.

### Task F1: Console readable in dark mode (Limer)

**Cause:** `Console.log` writes every plain line as `<span style='color:inherit;'>` (`scripts/gui/views/console/console.lua`, the `log` entry of `api`). Qt's rich text has no `inherit`, so the colour comes out invalid and draws black, whatever the theme. The other `COLOURS` (`#2d7d46`, `#1f6feb`, `#c0392b`, `#7a7a7a`) were picked against a white background and lose contrast on a dark one.

**Files:**
- Modify: `scripts/gui/views/console/console.lua` — plain lines carry no colour span at all, so the widget's own text colour applies; each of `COLOURS` gets a light and a dark value, chosen by `Theme.active`
- Modify: the same file — on `Theme.observe`, re-render the log from the entries it keeps (colours are baked into appended HTML, so lines already written would otherwise keep the old theme's colours); or, if keeping entries is too costly, pick single mid-tone colours that read on both backgrounds

**Also check:** the "black parts" around the console. Its `ui.TextField` gets qdarktheme's `QTextEdit` background, `rgba(30,29,30)`, against a `#202124` window, and the Inspector tab beside it holds a `ui.Table` (`scripts/gui/views/inspector/view.lua:188`), which is F3. Screenshot both before deciding which is which.

**Done when:** in the dark theme every console line (log, stream, warn, error, rule, repeat count) and the status line read clearly, and switching theme mid-session re-colours what is already there.

### Task F2: Form rows editable from the form itself (Limer)

**Cause:** a form row's label is stored on the field (`node.form.label`) and only shows in Properties under the *field's* Placement section. Selecting the form container shows nothing about its rows, so there is no visible place to edit them.

**Files:**
- Modify: `scripts/gui/views/designer/properties.lua` — for a container whose layout is `ui.FormLayout`, a "Rows" section: one string row per field, labelled with the field's name, value = its label, applied through the existing `cb.onPlacement(child, "form.label", value)`

**Done when:** selecting a form shows and edits every row's label in one place; each edit is one undo step.

### Task F3: No pure-black tables in dark mode (Limekit)

**Cause:** the `darklight` family (`limekit/services/theming.py`, `_set_darklight`) applies `qdarktheme.load_stylesheet(name)` only. qdarktheme's dark sheet hard-codes `QTableView { background-color: rgba(0,0,0,1) }` and `QTableView QHeaderView { background-color: rgba(0,0,0,1) }`, and `qdarktheme.load_palette(name)` (Base `#202124`, Text `#eff1f1`) is never applied, so palette roles stay at Qt's defaults. Every `ui.Table` is affected: tables on the designer canvas, the designer's Properties panel (seen in the screenshot), the list and table editors from Phase 1, Limer's Inspector, and the routes table in the app's Properties tab.

**Files:**
- Modify: `limekit/services/theming.py` — `_set_darklight` also applies `load_palette(name)` with `setPalette`, and appends a short override that gives `QTableView` and its header the palette's Base colour instead of black
- Test: a `tests/` check that, after `setTheme("darklight", "dark")`, a `ui.Table`'s viewport background is not black

**Done when:** in the dark theme no table, header, or empty table area draws pure black; the light theme is unchanged. Check with screenshots of both.

### Task F4: The surface hits design widgets, never Qt internals (Limekit)

**Cause:** `ui.DesignSurface` hit-tests with `_deepest_at` (`limekit/widgets/designsurface.py:69`), the innermost visible Qt widget under the mouse. For a composite widget that is an internal part the designer never created: a Table's or ListBox's viewport, a TextField's viewport, a Scroller's viewport, a Splitter handle, a Tab's page stack, a form row's label. Those have no label, and `_label` (`:523-524`) falls back to `type(widget).__name__`, hence "QWidget" and "QLabel" on hover. The same raw hit is used for press/select (`:707`), the context menu (`:722`), double-click (`:728`) and hover (`:751`). So clicking the body of a Table selects nothing (Limer's canvas has no node for the viewport), and the Phase 1 double-click-to-edit on a Table or ListBox only fires on its frame.

**Files:**
- Modify: `limekit/widgets/designsurface.py` — one helper that climbs from the raw hit through `parentWidget()` to the nearest widget given a label with `setWidgetLabel` (Limer labels every design widget), stopping at the design child; used for hover, press/select, drag start, context menu and double-click. `_label`'s fallback becomes the Limekit class name (`__lime__`, e.g. "Table"), never a Qt class name
- Test: `tests/widgets/test_designsurface_*.py` — a click on a Table's viewport reports the Table; a hover tag on an unlabelled widget shows no "Q" class name

**Done when:** hovering anywhere on any widget names that widget as the outline does ("table1 · Table"); clicking anywhere on it selects it; double-clicking a Table's cells opens the table editor.

### Task F5: Form labels selectable and editable on the canvas (both repos)

**Cause:** `FormLayout:addChild(title, child)` (`limekit/layouts/formlayout.py:15`) takes the title only as a string and passes it to `QFormLayout.addRow`, which makes a plain `QLabel` that Lua never gets a handle to. So the canvas cannot label it, select through it, or edit it.

**Files:**
- Modify (Limekit): `limekit/layouts/formlayout.py` — `addChild(labelWidget, field)` also accepted, mapping to `QFormLayout.addRow(QWidget, QWidget)`; string titles behave as today. Regenerate Limer's `api_index.lua`
- Modify (Limer): `scripts/gui/views/designer/canvas.lua` — a form row is built with a real `ui.Label`, labelled on the surface as "<field> · label", and mapped to its field node, so clicking it selects the field and double-clicking it edits `form.label` (`scripts/gui/views/designer/view.lua`, `callbacks.onDoubleClick`). Generated code keeps the string form (`addChild("Name", w.name)`)

**Depends on:** F4 (the label must be hit as itself, not climbed past).

**Done when:** a form's labels hover with a proper name, click to select their field, and double-click to rename.

### Task F6: The white box at the canvas's top-left

**Cause (found 2026-10-22, by another session's trace, then confirmed here):** `setDesignChild` added the new design to the surface's layout, but a widget added to a layout is still hidden -- Qt shows it on a later turn of the event loop -- and a layout skips hidden widgets. So until that turn the design sat at (0, 0). The mock window frame (`paintEvent`) and the selection outline (`_paint_overlay`) are drawn from the design's geometry, so a paint landing in that gap drew the frame at (0, −28): the title bar off the top, a white design-sized body with a blue edge at the top-left. Measured: right after the call the design was at 0,0 and hidden; it settled at 330,224.

**Fixed:** `setDesignChild` shows the new design and activates the layout before returning, so it is in place before anything can paint (`test_a_new_design_is_in_place_before_anything_can_paint` fails without it). Why the harness runs below missed it: they logged the design's first Show and Paint, which come after the layout pass, not paints of the surface inside the gap; real Limer evidently gets one there.

### Task F7: Run fails once a design uses an image (Limer)

**Reported (another session, not yet verified here):** `Files.writePreview` writes a throwaway project for Run, but not the image map (`designed/images.lua`) or the `images/` folder, so a design whose window has an icon -- or any widget an image -- fails to run.

**Proposed:** when writing the preview, copy the images the design uses (`DesignModel.imagesUsed`) and write a matching image map. About 15 lines in `scripts/gui/views/designer/files.lua`.

### Earlier F6 investigation (kept for the record)

**Seen (screenshot, light theme, 2026-10-22):** after a save, a white box with a blue edge, the design's size (640×480), sits at the canvas viewport's top-left, under the design where they overlap.

**Ruled out, with a harness that runs the real designer under the engine and logs from an app-wide Qt event filter (`D:\tmp\re\flash\watch*.py`), on both the offscreen and the native Windows platform, through Ctrl+S saves (first save's name prompt included), undo, redo, select and add:**
- The new design child shown before its layout places it: at its first Show and Paint it is already centred.
- The surface's mock window frame (`designsurface.py:950-966`) or the overlay drawn from a stale geometry: at every surface and overlay paint the child is centred.
- `flash()` lighting a detached old root: the flash is orange (`#FF6D00`, `:42`), not white. Still a real bug: `setDesignChild` does not clear `_flash`, so a rebuild mid-flash flashes a widget that is no longer in the design. Fix that whatever F6 turns out to be.
- A stray top-level window (the old child after `setParent(None)` at `:486`): none is shown; no native handle is created for any design widget.
- The event loop spun mid-rebuild: nothing in the engine calls `processEvents` or `repaint()`.

**Not yet covered:** the designer opened from inside real Limer (its console logging, image watching and project open path), real mouse state over the canvas, and display scaling.

**Next step:** run the same event filter inside real Limer (a `LIMEKIT_DEBUG_PAINT=1` switch in the engine that installs it and logs every Show/Paint in the designer window with its surface-relative position and parent chain), reproduce, read the log.

---

## Phase 2 — Native `ui.DesignSurface` foundation (Limekit repo)

**Done 2026-10-22, with Phase 3 and F7.** A design here is laid out, not positioned -- widgets have no x and y -- so each feature means what it can in a layout:
- 2.1 Zoom — `setZoom/getZoom/zoomIn/zoomOut/resetZoom`, `setOnZoomChange`, Ctrl+wheel. Qt draws a widget at one size only, so at any zoom but 1 the design is laid out at its real size on a stage far off the surface and drawn, scaled, by a proxy that holds its place in the surface's layout. Every mouse position goes through `_to_design` and every frame through `_rect_in`; at zoom 1 they are plain maps and nothing behaves differently. Limer: View > Zoom in (Ctrl+= / Ctrl++), Zoom out (Ctrl+-), Actual size (Ctrl+0); a toolbar −, %, + group.
- 2.2 Grid — `setGridSize` (16 px), `setSnapToGrid`. Snapping applies to the one thing set in px, a resize; the backdrop's dots are the grid, one step apart at the current zoom and in line with the design's corner. Limer: View > Snap to grid.
- 2.3 Multi-select — Ctrl/Shift-click adds and removes; a drag from the window or the backdrop draws a marquee taking the outermost widgets it encloses (a row taken whole takes its children with it). `setSelection/getSelection`, `setOnSelectionChange`. Limer keeps a selection of several through edits and undo.
- 2.4 Several at once — dragging one of several moves them all, side by side into the slot (`DesignModel.moveMany`; in a grid, row after row); a handle pulls every selected widget by the same amount (`setOnResizeSelection`), one undo step; Delete and Lock act on all.
- 2.5 Guides — while resizing, the pulled edge snaps within 5 screen px to another widget's edge, or to the size that matches another widget's width or height, drawn as a dashed line and named on the size tag. `setGuidesEnabled`. Guides for *moves* would mean nothing in a layout: a move goes into a slot, which the drop indicator already shows.
- 3.1 — **Align** (Left, Centre, Right, Fill across / Top, Middle, Bottom, Fill down): where a widget sits in its layout slot -- aligned one way it keeps its own size that way, instead of stretching. New engine call `Layout:setChildAlignment(child, ...)`; stored as `halign`/`valign` on the node. **Match size** (same width/height/size as the last selected), from `DesignSurface:getWidgetSize`. **Distribute evenly**: equal stretch across a row's or column's widgets.
- F7 — `Files.writePreview(project, name, source, design)` copies the images the design names, folders kept, and writes their map. Verified: the old preview failed with `module 'designed.images' not found`, the new one runs.
- Checks: Limekit -- `tests/widgets/test_designsurface_zoom.py` (20), the whole suite passing; Limer -- model checks 60/60, the Phase 1 smoke run 9/9, the F-fix run 12/12, and a 20-check run of Phase 2 and 3 with real Qt mouse, wheel and key events on the real designer.

Do in this order — each builds on the last. Regenerate Limer's `api_index.lua` after each lands.

### Task 2.1: Zoom

Scale the whole surface (transform, not re-layout) while keeping hit-testing, drop targets, and selection outlines correct at any zoom level.

**Exposes:** `setZoom(factor)` / `getZoom()`, `zoomIn()` / `zoomOut()` / `resetZoom()` on `ui.DesignSurface`.

**Depends on:** nothing — do this first, isolated and highest value-to-effort.

**Lua follow-up (Limer):** toolbar buttons + Ctrl+/Ctrl- shortcuts in `view.lua`.

### Task 2.2: Grid + snap-to-grid

A visible dot/line grid under the design; drop/resize math rounds x/y to a configurable grid step.

**Exposes:** `setGridSize(px)`, `setSnapToGrid(enabled)` on `ui.DesignSurface`.

### Task 2.3: True multi-select

Rubber-band marquee + shift-click; `getSelected()` returns a list, `setSelected()` accepts a list.

**Exposes:** `onSelect` passes a list (or a new `onMultiSelect`), `setSelected(widgets)` accepts a table.

**Depends on:** nothing additional, but every Phase 3 item needs this.

### Task 2.4: Multi-widget resize/move

Resize handles operate on the selection's bounding box; move drags all selected together.

**Depends on:** 2.3 (multi-select), benefits from 2.2 (so multi-drag snaps too).

### Task 2.5: Smart alignment guide lines

While dragging, compare the moving widget's edges/centers against siblings; draw a snap line and hard-snap within a threshold.

**Depends on:** 2.2 (shares the same snap-detection plumbing). Hardest item in the plan — do it last in Phase 2.

---

## Phase 3 — Lua work unlocked by Phase 2 (Limer repo)

### Task 3.1: Align/distribute actions

Left/right/top/bottom align, center horizontal/vertical, distribute — pure math over the selected nodes' `grid`/`stretch`/position, applied through `Canvas.apply`.

**Files:**
- Modify: `scripts/app/core/design_model.lua` — new `DesignModel.align(design, nodes, mode)`
- Modify: `scripts/gui/views/designer/view.lua` — toolbar + menu, enabled only when more than one widget is selected

**Depends on:** 2.3 (multi-select) — nothing to align against with a single widget.
