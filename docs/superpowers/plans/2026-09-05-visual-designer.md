# Visual Designer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A drag-and-drop designer in Limer that places real Limekit widgets into layouts, saves a design file, and generates a Lua module.

**Architecture:** Limekit (Python) gains drop resolution and drag handling in `ui.DesignSurface` plus a `ui.WidgetPalette` drag source; both only *report*. Limer (Lua) owns a pure model with insert/move/wrap/undo/serialize/generate, and a view that rebuilds the canvas from the model after every change.

**Tech Stack:** PySide6 6.11, lupa 2.8, pytest (offscreen Qt), Lua 5.4 via the Limekit 2.0 engine.

**Spec:** `Limer-Limekit/docs/superpowers/specs/2026-09-05-visual-designer-design.md`

## Global Constraints

- Two repos: `D:\Personal Dev\Limekit Project\Limekit` (Python, branch as-is) and `D:\Personal Dev\Limekit Project\Limer-Limekit` (Lua, branch `limekit-2.0-port`). Commit in the repo the task touches.
- Limer ships no Python. Nothing Python goes into `Limer-Limekit`.
- Every index crossing into Lua is 1-based. Qt's 0-based counts are translated at the boundary.
- Limekit classes are registered by `__lime__ = "ui.Name"`; after adding one, run `python tools/generate_manifest.py`, `python tools/generate_stubs.py`, `python tools/generate_lua.py` and `python tools/generate_api_index.py` from the Limekit repo, and the staleness tests in `tests/kernel/` must pass.
- Run Limekit tests with `python -m pytest -q` from the Limekit repo. Run Limer model tests with `python -m limekit tests` from the Limer repo.
- Design files: `design/<name>.design.lua`. Generated modules: `scripts/designed/<name>.lua`. `main.lua` is never written.
- The surface never mutates the widget tree on drop; Lua does.

---

## File map

Limekit:
- Modify `limekit/widgets/designsurface.py` — drop resolution, drag start, indicator, `onDrop`.
- Create `limekit/widgets/widgetpalette.py` — `ui.WidgetPalette`.
- Create `tests/widgets/test_designsurface_drop.py`, `tests/widgets/test_widgetpalette.py`.
- Regenerate `limekit/kernel/manifest.py`, `limekit/runtime/lua/stubs/ui.lua`, `limekit/runtime/lua/limekit.lua`, Limer's `scripts/data/api_index.lua`.

Limer:
- Rewrite `scripts/app/core/design_model.lua` — tree ops, placement, serialize, undo, generate.
- Create `tests/app.json`, `tests/scripts/main.lua` — Lua checks.
- Create `scripts/gui/views/designer/canvas.lua`, `outline.lua`, `properties.lua`, `preview.lua`, `files.lua`; rewrite `view.lua`.
- Modify `scripts/gui/components/project_tab_container.lua`, `README.md`.

---

### Task 1: Drop resolution for box layouts

**Files:**
- Modify: `limekit/widgets/designsurface.py`
- Test: `tests/widgets/test_designsurface_drop.py`

**Interfaces:**
- Produces: `resolve_drop(surface, position: QPoint, dragging: QWidget|None) -> dict|None` with keys `target` (QWidget), `layout` (`"vbox"|"hbox"|"grid"|"form"`), and `index` (1-based) for box/form or `row`,`column` (1-based) for grid.
- Produces: `_layout_kind(qlayout) -> str|None`, `_container_for(surface, hit) -> (QWidget, QLayout)|(None, None)`.

- [ ] **Step 1: Write the failing tests**

```python
"""Where a drop lands: the container under the cursor, and the slot in it."""

import pytest
from PySide6.QtCore import QPoint
from PySide6.QtWidgets import QApplication

from limekit.kernel import manifest


@pytest.fixture(scope="module", autouse=True)
def qapp():
    manifest.import_all()
    return QApplication.instance() or QApplication([])


def show(surface):
    surface.resize(300, 300)
    surface.show()
    QApplication.processEvents()


def centre_of(widget, surface):
    return widget.mapTo(surface, widget.rect().center())


@pytest.fixture
def vbox(qapp):
    from limekit.layouts.vlayout import VLayout
    from limekit.widgets.button import Button
    from limekit.widgets.container import Container
    from limekit.widgets.designsurface import DesignSurface

    surface, box, layout = DesignSurface(), Container(), VLayout()
    buttons = [Button(f"b{i}") for i in range(3)]
    for b in buttons:
        layout.addChild(b)
    box.setLayout(layout)
    surface.setDesignChild(box)
    show(surface)
    return surface, box, buttons


def test_vbox_before_the_midpoint_of_the_second_child_is_slot_two(vbox):
    from limekit.widgets.designsurface import resolve_drop
    surface, box, buttons = vbox
    top = buttons[1].mapTo(surface, buttons[1].rect().topLeft())
    slot = resolve_drop(surface, QPoint(top.x() + 5, top.y() + 2))
    assert slot["target"] is box
    assert slot["layout"] == "vbox"
    assert slot["index"] == 2


def test_vbox_after_the_midpoint_of_the_last_child_is_the_end(vbox):
    from limekit.widgets.designsurface import resolve_drop
    surface, box, buttons = vbox
    bottom = buttons[2].mapTo(surface, buttons[2].rect().bottomLeft())
    slot = resolve_drop(surface, QPoint(bottom.x() + 5, bottom.y() - 2))
    assert slot["index"] == 4


def test_hbox_cuts_along_x(qapp):
    from limekit.layouts.hlayout import HLayout
    from limekit.widgets.button import Button
    from limekit.widgets.container import Container
    from limekit.widgets.designsurface import DesignSurface, resolve_drop

    surface, box, layout = DesignSurface(), Container(), HLayout()
    a, b = Button("a"), Button("b")
    layout.addChild(a); layout.addChild(b)
    box.setLayout(layout)
    surface.setDesignChild(box)
    show(surface)

    left = b.mapTo(surface, b.rect().topLeft())
    assert resolve_drop(surface, QPoint(left.x() + 2, left.y() + 5))["index"] == 2
    right = b.mapTo(surface, b.rect().topRight())
    assert resolve_drop(surface, QPoint(right.x() - 2, right.y() + 5))["index"] == 3
    assert resolve_drop(surface, QPoint(left.x() + 2, left.y() + 5))["layout"] == "hbox"


def test_a_widget_with_no_layout_is_not_a_target(qapp):
    from limekit.widgets.designsurface import DesignSurface, resolve_drop
    from limekit.widgets.label import Label

    surface = DesignSurface()
    surface.setDesignChild(Label("alone"))
    show(surface)
    assert resolve_drop(surface, QPoint(10, 10)) is None
```

- [ ] **Step 2: Run to verify failure**

Run: `cd Limekit && python -m pytest tests/widgets/test_designsurface_drop.py -q`
Expected: ImportError on `resolve_drop`.

- [ ] **Step 3: Implement**

Add to `designsurface.py` after `_make_inert`:

```python
from PySide6.QtWidgets import (QBoxLayout, QFormLayout, QGridLayout,
                               QVBoxLayout, QWidget)

def _layout_kind(layout):
    """"vbox", "hbox", "grid", "form", or None for anything else."""
    if isinstance(layout, QGridLayout):
        return "grid"
    if isinstance(layout, QFormLayout):
        return "form"
    if isinstance(layout, QBoxLayout):
        direction = layout.direction()
        if direction in (QBoxLayout.Direction.TopToBottom,
                         QBoxLayout.Direction.BottomToTop):
            return "vbox"
        return "hbox"
    return None


def _container_for(surface, hit):
    """The nearest widget at or above `hit` that lays children out.

    Stops at the design child: the surface's own QVBoxLayout must never be
    a target, or a drop beside the design would land outside it.
    """
    widget = hit
    while widget is not None and widget is not surface:
        if _layout_kind(widget.layout()) is not None:
            return widget, widget.layout()
        if widget is surface.getDesignChild():
            break
        widget = widget.parentWidget()
    return None, None


def _is_or_descends_from(widget, ancestor):
    while widget is not None:
        if widget is ancestor:
            return True
        widget = widget.parentWidget()
    return False


def _box_slot(layout, kind, local):
    """1-based insertion index, cutting at each item's midpoint."""
    coordinate = local.y() if kind == "vbox" else local.x()
    for i in range(layout.count()):
        rect = layout.itemAt(i).geometry()
        middle = rect.center().y() if kind == "vbox" else rect.center().x()
        if coordinate < middle:
            return i + 1
    return layout.count() + 1


def resolve_drop(surface, position, dragging=None):
    """The container and slot a drop at `position` (surface coords) means.

    Pure with respect to the widget tree: nothing is added, moved or
    selected. Returns None when there is nothing to drop into, or when the
    thing being moved would end up inside itself.
    """
    hit = _deepest_at(surface, position) or surface.getDesignChild()
    if hit is None:
        return None
    container, layout = _container_for(surface, hit)
    if container is None:
        return None
    if dragging is not None and _is_or_descends_from(container, dragging):
        return None

    kind = _layout_kind(layout)
    local = container.mapFrom(surface, position)
    slot = {"target": container, "layout": kind}
    if kind in ("vbox", "hbox"):
        slot["index"] = _box_slot(layout, kind, local)
    return slot
```

- [ ] **Step 4: Run tests**

Run: `python -m pytest tests/widgets/test_designsurface_drop.py -q`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add limekit/widgets/designsurface.py tests/widgets/test_designsurface_drop.py
git commit -m "DesignSurface: resolve where a drop lands in a row or column"
```

---

### Task 2: Drop resolution for grid, form, nesting and self-drops

**Files:**
- Modify: `limekit/widgets/designsurface.py`
- Test: `tests/widgets/test_designsurface_drop.py`

**Interfaces:**
- Produces: `resolve_drop` returns `row`,`column` for grids (may be `rowCount()+1` / `columnCount()+1`) and `index` for forms (`1..rowCount()+1`).

- [ ] **Step 1: Write the failing tests**

```python
def test_grid_reports_the_cell_under_the_cursor_and_one_past_the_edge(qapp):
    from limekit.layouts.grid import GridLayout
    from limekit.widgets.button import Button
    from limekit.widgets.container import Container
    from limekit.widgets.designsurface import DesignSurface, resolve_drop

    surface, box, grid = DesignSurface(), Container(), GridLayout()
    cells = {}
    for r in (1, 2):
        for c in (1, 2):
            cells[r, c] = Button(f"{r},{c}")
            grid.addChild(cells[r, c], r, c)
    box.setLayout(grid)
    surface.setDesignChild(box)
    show(surface)

    slot = resolve_drop(surface, centre_of(cells[2, 1], surface))
    assert (slot["layout"], slot["row"], slot["column"]) == ("grid", 2, 1)

    edge = cells[1, 2].mapTo(surface, cells[1, 2].rect().topRight())
    past = resolve_drop(surface, QPoint(edge.x() + 3, edge.y() + 5))
    assert (past["row"], past["column"]) == (1, 3)


def test_form_cuts_at_row_midpoints(qapp):
    from limekit.layouts.formlayout import FormLayout
    from limekit.widgets.container import Container
    from limekit.widgets.designsurface import DesignSurface, resolve_drop
    from limekit.widgets.lineedit import LineEdit

    surface, box, form = DesignSurface(), Container(), FormLayout()
    first, second = LineEdit(), LineEdit()
    form.addChild("A", first); form.addChild("B", second)
    box.setLayout(form)
    surface.setDesignChild(box)
    show(surface)

    top = second.mapTo(surface, second.rect().topLeft())
    assert resolve_drop(surface, QPoint(top.x() + 5, top.y() + 1))["index"] == 2
    bottom = second.mapTo(surface, second.rect().bottomLeft())
    assert resolve_drop(surface, QPoint(bottom.x() + 5, bottom.y() - 1))["index"] == 3
    assert resolve_drop(surface, QPoint(top.x() + 5, top.y() + 1))["layout"] == "form"


@pytest.fixture
def nested(qapp):
    from limekit.layouts.vlayout import VLayout
    from limekit.widgets.button import Button
    from limekit.widgets.container import Container
    from limekit.widgets.designsurface import DesignSurface

    surface = DesignSurface()
    outer, outer_layout = Container(), VLayout()
    outer_layout.setMargins(20, 20, 20, 20)
    inner, inner_layout = Container(), VLayout()
    button = Button("in")
    inner_layout.addChild(button)
    inner.setLayout(inner_layout)
    outer_layout.addChild(inner)
    outer.setLayout(outer_layout)
    surface.setDesignChild(outer)
    show(surface)
    return surface, outer, inner, button


def test_the_innermost_container_under_the_cursor_is_the_target(nested):
    from limekit.widgets.designsurface import resolve_drop
    surface, outer, inner, button = nested
    assert resolve_drop(surface, centre_of(button, surface))["target"] is inner
    assert resolve_drop(surface, QPoint(3, 3))["target"] is outer


def test_a_moved_widget_cannot_land_inside_itself(nested):
    from limekit.widgets.designsurface import resolve_drop
    surface, outer, inner, button = nested
    assert resolve_drop(surface, centre_of(button, surface), dragging=inner) is None
    assert resolve_drop(surface, QPoint(3, 3), dragging=inner)["target"] is outer
```

- [ ] **Step 2: Run to verify failure**

Expected: grid and form tests fail with KeyError on `row`/`index`.

- [ ] **Step 3: Implement** — extend `resolve_drop`:

```python
def _grid_slot(layout, local):
    rows, columns = layout.rowCount(), layout.columnCount()
    row, column = rows + 1, columns + 1
    for r in range(rows):
        rect = layout.cellRect(r, 0)
        if rect.isValid() and local.y() <= rect.bottom():
            row = r + 1
            break
    for c in range(columns):
        rect = layout.cellRect(0, c)
        if rect.isValid() and local.x() <= rect.right():
            column = c + 1
            break
    return row, column


def _form_slot(layout, local):
    for r in range(layout.rowCount()):
        item = (layout.itemAt(r, QFormLayout.ItemRole.FieldRole)
                or layout.itemAt(r, QFormLayout.ItemRole.SpanningRole)
                or layout.itemAt(r, QFormLayout.ItemRole.LabelRole))
        if item is not None and local.y() < item.geometry().center().y():
            return r + 1
    return layout.rowCount() + 1
```

and in `resolve_drop`:

```python
    if kind in ("vbox", "hbox"):
        slot["index"] = _box_slot(layout, kind, local)
    elif kind == "grid":
        slot["row"], slot["column"] = _grid_slot(layout, local)
    else:
        slot["index"] = _form_slot(layout, local)
```

- [ ] **Step 4: Run tests** — Expected: 9 passed.

- [ ] **Step 5: Commit**

```bash
git commit -am "DesignSurface: resolve grid cells, form rows and nested containers"
```

---

### Task 3: Drag events, indicator and `onDrop`

**Files:**
- Modify: `limekit/widgets/designsurface.py`
- Test: `tests/widgets/test_designsurface_drop.py`

**Interfaces:**
- Produces Lua-visible: `DesignSurface:setOnDrop(handler)`, `DesignSurface:setDropEnabled(bool)`. Handler receives one Lua table `{kind, class|widget, target, layout, index|row,column}`.
- Produces module constants `CLASS_MIME = "application/x-limekit-class"`, `MOVE_MIME = "application/x-limekit-move"`.

- [ ] **Step 1: Write the failing tests**

```python
def class_drop_event(surface, point, class_name):
    from PySide6.QtCore import QMimeData, QPointF, Qt
    from PySide6.QtGui import QDropEvent
    from limekit.widgets.designsurface import CLASS_MIME
    mime = QMimeData()
    mime.setData(CLASS_MIME, class_name.encode())
    return QDropEvent(QPointF(point), Qt.DropAction.CopyAction, mime,
                      Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier)


def test_dropping_a_class_reports_it_and_adds_nothing(vbox):
    surface, box, buttons = vbox
    seen = []
    surface.setOnDrop(lambda drop: seen.append(drop))
    before = box.layout().count()

    surface.dropEvent(class_drop_event(surface, centre_of(buttons[0], surface), "ui.Label"))

    assert box.layout().count() == before
    assert len(seen) == 1
    drop = seen[0]
    assert drop["kind"] == "class"
    assert drop["class"] == "ui.Label"
    assert drop["target"] is box
    assert drop["layout"] == "vbox"
    assert drop["index"] in (1, 2)


def test_a_drop_with_no_target_reaches_no_handler(qapp):
    from limekit.widgets.designsurface import DesignSurface
    from limekit.widgets.label import Label
    surface = DesignSurface()
    surface.setDesignChild(Label("alone"))
    show(surface)
    seen = []
    surface.setOnDrop(lambda drop: seen.append(drop))
    surface.dropEvent(class_drop_event(surface, QPoint(5, 5), "ui.Button"))
    assert seen == []


def test_drop_can_be_switched_off(vbox):
    surface, box, buttons = vbox
    seen = []
    surface.setOnDrop(lambda drop: seen.append(drop))
    surface.setDropEnabled(False)
    surface.dropEvent(class_drop_event(surface, centre_of(buttons[0], surface), "ui.Label"))
    assert seen == []


def test_the_indicator_is_a_bar_at_the_slot_boundary(vbox):
    from limekit.widgets.designsurface import indicator_rect
    surface, box, buttons = vbox
    slot = {"target": box, "layout": "vbox", "index": 2}
    rect = indicator_rect(surface, slot)
    boundary = buttons[1].mapTo(surface, buttons[1].rect().topLeft()).y()
    assert abs(rect.center().y() - boundary) <= 4
    assert rect.width() >= buttons[1].width()
```

Note: the handler in tests is a plain Python callable; the surface converts the dict with `to_lua` only when a Lua runtime is bound, otherwise passes the dict. Implement `_emit_drop` to try `to_lua` and fall back to the dict on `BridgeError`.

- [ ] **Step 2: Run to verify failure** — AttributeError `setOnDrop`.

- [ ] **Step 3: Implement**

```python
from PySide6.QtCore import QMimeData, QPoint, QRect, Qt
from PySide6.QtGui import QColor, QDrag, QPainter, QPen
from PySide6.QtWidgets import QApplication

from limekit.kernel.bridge.convert import to_lua
from limekit.kernel.errors import BridgeError

CLASS_MIME = "application/x-limekit-class"
MOVE_MIME = "application/x-limekit-move"
_INDICATOR_COLOUR = "#FF6D00"


def indicator_rect(surface, slot):
    """Where the drop indicator is drawn, in surface coordinates."""
    target, layout = slot["target"], slot["target"].layout()
    origin = target.mapTo(surface, QPoint(0, 0))
    kind = slot["layout"]
    contents = target.contentsRect()

    if kind in ("vbox", "hbox"):
        index, count = slot["index"], layout.count()
        if count == 0:
            edge = contents.topLeft()
            along = contents.height() if kind == "hbox" else contents.width()
            if kind == "vbox":
                return QRect(origin.x() + edge.x(), origin.y() + edge.y(), along, 3)
            return QRect(origin.x() + edge.x(), origin.y() + edge.y(), 3, along)
        if index <= count:
            rect, before = layout.itemAt(index - 1).geometry(), True
        else:
            rect, before = layout.itemAt(count - 1).geometry(), False
        if kind == "vbox":
            y = rect.top() if before else rect.bottom()
            return QRect(origin.x() + rect.left(), origin.y() + y - 1, rect.width(), 3)
        x = rect.left() if before else rect.right()
        return QRect(origin.x() + x - 1, origin.y() + rect.top(), 3, rect.height())

    if kind == "grid":
        r, c = slot["row"] - 1, slot["column"] - 1
        if r < layout.rowCount() and c < layout.columnCount():
            cell = layout.cellRect(r, c)
        else:
            cell = QRect(contents.left(), contents.top(), 40, 24)
            if r < layout.rowCount():
                cell.moveTop(layout.cellRect(r, 0).top())
                cell.moveLeft(contents.right() - 40)
            elif c < layout.columnCount():
                cell.moveLeft(layout.cellRect(0, c).left())
                cell.moveTop(contents.bottom() - 24)
            else:
                cell.moveTo(contents.right() - 40, contents.bottom() - 24)
        return cell.translated(origin)

    # form
    index, rows = slot["index"], layout.rowCount()
    if rows == 0:
        return QRect(origin.x() + contents.left(), origin.y() + contents.top(), contents.width(), 3)
    row = min(index, rows) - 1
    item = (layout.itemAt(row, QFormLayout.ItemRole.FieldRole)
            or layout.itemAt(row, QFormLayout.ItemRole.SpanningRole)
            or layout.itemAt(row, QFormLayout.ItemRole.LabelRole))
    rect = item.geometry()
    y = rect.top() if index <= rows else rect.bottom()
    return QRect(origin.x() + contents.left(), origin.y() + y - 1, contents.width(), 3)
```

In the class:

```python
    def __init__(self):
        ...
        self._onDrop = None
        self._dropEnabled = True
        self._pending = None        # slot under the cursor during a drag
        self._dragging = None       # widget being moved
        self._press = None          # (widget, QPoint) of the last press
        self.setAcceptDrops(True)

    @method({"handler": "fun(drop: table)"}, returns="self",
            doc="Called when a class from the palette, or a placed widget, "
                "is dropped. drop = {kind, class|widget, target, layout, "
                "index|row,column}. The surface changes nothing itself.")
    def setOnDrop(self, handler):
        self._onDrop = guard(handler, widget="DesignSurface", event="onDrop")
        return self

    @method({"enabled": "boolean"}, returns="self",
            doc="Whether drops are accepted. On by default.")
    def setDropEnabled(self, enabled):
        self._dropEnabled = bool(enabled)
        return self

    # -- drag source --------------------------------------------------------

    def mousePressEvent(self, event):
        position = event.position().toPoint()
        hit = _deepest_at(self, position)
        self._selected = hit
        self._press = (hit, position) if hit is not None and hit is not self._child else None
        self.update()
        if self._onSelect is not None:
            self._onSelect(hit)
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._press is None or not (event.buttons() & Qt.MouseButton.LeftButton):
            return
        widget, origin = self._press
        if (event.position().toPoint() - origin).manhattanLength() < QApplication.startDragDistance():
            return
        self._press = None
        self._dragging = widget
        mime = QMimeData()
        mime.setData(MOVE_MIME, str(id(widget)).encode())
        drag = QDrag(self)
        drag.setMimeData(mime)
        drag.setPixmap(widget.grab())
        drag.exec(Qt.DropAction.MoveAction)
        self._dragging = None
        self._pending = None
        self.update()

    def mouseReleaseEvent(self, event):
        self._press = None
        super().mouseReleaseEvent(event)

    # -- drop target --------------------------------------------------------

    def _accepts(self, mime):
        return self._dropEnabled and (mime.hasFormat(CLASS_MIME) or mime.hasFormat(MOVE_MIME))

    def dragEnterEvent(self, event):
        if self._accepts(event.mimeData()):
            event.acceptProposedAction()
            self.dragMoveEvent(event)

    def dragMoveEvent(self, event):
        if not self._accepts(event.mimeData()):
            event.ignore()
            return
        slot = resolve_drop(self, event.position().toPoint(), self._dragging)
        self._pending = slot
        self.update()
        if slot is None:
            event.ignore()
        else:
            event.acceptProposedAction()

    def dragLeaveEvent(self, event):
        self._pending = None
        self.update()

    def dropEvent(self, event):
        mime = event.mimeData()
        self._pending = None
        self.update()
        if not self._accepts(mime):
            event.ignore()
            return
        slot = resolve_drop(self, event.position().toPoint(), self._dragging)
        if slot is None:
            event.ignore()
            return
        if mime.hasFormat(CLASS_MIME):
            drop = {"kind": "class", "class": bytes(mime.data(CLASS_MIME)).decode()}
        else:
            if self._dragging is None:
                event.ignore()
                return
            drop = {"kind": "move", "widget": self._dragging}
        drop.update(slot)
        event.acceptProposedAction()
        self._emit_drop(drop)

    def _emit_drop(self, drop):
        if self._onDrop is None:
            return
        try:
            payload = to_lua(drop)
        except BridgeError:
            payload = drop                  # no Lua runtime bound: tests
        self._onDrop(payload)
```

Paint the indicator in `paintEvent` after the selection rectangle:

```python
        if self._pending is not None:
            painter = QPainter(self)
            target = self._pending["target"]
            frame = QRect(target.mapTo(self, QPoint(0, 0)), target.size())
            pen = QPen(QColor(_INDICATOR_COLOUR)); pen.setWidth(1)
            painter.setPen(pen)
            painter.drawRect(frame.adjusted(0, 0, -1, -1))
            rect = indicator_rect(self, self._pending)
            colour = QColor(_INDICATOR_COLOUR)
            if self._pending["layout"] == "grid":
                fill = QColor(colour); fill.setAlpha(40)
                painter.fillRect(rect, fill)
                pen.setWidth(2); painter.setPen(pen)
                painter.drawRect(rect.adjusted(0, 0, -1, -1))
            else:
                painter.fillRect(rect, colour)
            painter.end()
```

`to_lua` of a dict containing QWidgets: `_pack_pairs` passes Python objects through, which lupa wraps; verify in Step 4 with a quick `LimeRuntime` smoke if `test_convert.py` does not already cover objects.

- [ ] **Step 4: Run all surface tests** — `python -m pytest tests/widgets/ -q` — Expected: all pass, existing `test_designsurface.py` unchanged.

- [ ] **Step 5: Commit**

```bash
git commit -am "DesignSurface: accept drops, start moves, draw the indicator, report onDrop"
```

---

### Task 4: `ui.WidgetPalette` and regenerated registries

**Files:**
- Create: `limekit/widgets/widgetpalette.py`
- Test: `tests/widgets/test_widgetpalette.py`
- Regenerate: `limekit/kernel/manifest.py`, `limekit/runtime/lua/stubs/ui.lua`, `limekit/runtime/lua/limekit.lua`, `../Limer-Limekit/scripts/data/api_index.lua`

**Interfaces:**
- Produces Lua-visible `ui.WidgetPalette()`: `setOnPick(fun(class: string))`, `getSelectedClass() -> string|nil`, `setFilter(text)`, `getClasses() -> string[]`.
- Produces `GROUPS` (ordered list of `(title, [class names])`) and `palette_classes() -> list[str]` (module-level, tests use them).

- [ ] **Step 1: Write the failing tests**

```python
"""The palette offers only what builds, and hands it over as a drag."""

import pytest
from PySide6.QtWidgets import QApplication

from limekit.kernel import manifest


@pytest.fixture(scope="module", autouse=True)
def qapp():
    manifest.import_all()
    return QApplication.instance() or QApplication([])


def test_every_class_offered_is_buildable(qapp):
    from limekit.services.inspect import Introspect
    from limekit.widgets.widgetpalette import palette_classes
    buildable = set(Introspect.buildableClasses())
    offered = palette_classes()
    assert offered
    assert set(offered) <= buildable
    assert "ui.Button" in offered
    assert "ui.VLayout" not in offered          # layouts are not widgets


def test_filter_narrows_the_visible_items(qapp):
    from limekit.widgets.widgetpalette import WidgetPalette
    palette = WidgetPalette()
    palette.setFilter("butt")
    visible = [palette.list.item(i).text() for i in range(palette.list.count())
               if not palette.list.item(i).isHidden()]
    assert visible and all("butt" in v.lower() for v in visible)


def test_double_click_picks_the_class(qapp):
    from limekit.widgets.widgetpalette import WidgetPalette
    palette = WidgetPalette()
    picked = []
    palette.setOnPick(lambda cls: picked.append(cls))
    row = next(i for i in range(palette.list.count())
               if palette.list.item(i).text() == "Button")
    palette.list.itemDoubleClicked.emit(palette.list.item(row))
    assert picked == ["ui.Button"]


def test_mime_data_carries_the_class(qapp):
    from limekit.widgets.designsurface import CLASS_MIME
    from limekit.widgets.widgetpalette import WidgetPalette
    palette = WidgetPalette()
    row = next(i for i in range(palette.list.count())
               if palette.list.item(i).text() == "Label")
    mime = palette.list.mimeData([palette.list.item(row)])
    assert bytes(mime.data(CLASS_MIME)).decode() == "ui.Label"


def test_headers_cannot_be_picked_or_dragged(qapp):
    from limekit.widgets.widgetpalette import WidgetPalette
    from PySide6.QtCore import Qt
    palette = WidgetPalette()
    header = palette.list.item(0)
    assert not (header.flags() & Qt.ItemFlag.ItemIsSelectable)
    assert not (header.flags() & Qt.ItemFlag.ItemIsDragEnabled)
```

- [ ] **Step 2: Run to verify failure** — ModuleNotFoundError.

- [ ] **Step 3: Implement**

```python
"""A list of every widget the designer can build, that can be dragged from.

Only classes `Introspect.buildableClasses()` reports are shown, so nothing
offered fails the moment it is dropped. Grouping is a static table; a class
added to Limekit without being added here still appears, under "Other".
"""

from PySide6.QtCore import QMimeData, Qt
from PySide6.QtWidgets import (QLineEdit, QListWidget, QListWidgetItem,
                               QVBoxLayout, QWidget)

from limekit.kernel.bridge.convert import to_lua
from limekit.kernel.bridge.guard import guard
from limekit.kernel.errors import BridgeError
from limekit.kernel.spec import method
from limekit.widgets.base import LimeWidget

CLASS_MIME = "application/x-limekit-class"
_CLASS_ROLE = Qt.ItemDataRole.UserRole

GROUPS = (
    ("Containers", ("Container", "GroupBox", "Scroller", "Splitter", "Tab", "Accordion")),
    ("Inputs", ("Button", "CheckBox", "RadioButton", "LineEdit", "TextField",
                "ComboBox", "FontComboBox", "Spinner", "DoubleSpinner", "Slider",
                "AdvancedSlider", "Knob", "DatePicker", "TimePicker", "Calendar")),
    ("Display", ("Label", "Image", "ProgressBar", "LCDNumber", "GifPlayer",
                 "HLine", "VLine", "Separator")),
    ("Data", ("ListBox", "Table", "TreeView", "TreeWidget")),
)

# Buildable, but not something that goes on a canvas.
_NOT_WIDGETS = {
    "ui.VLayout", "ui.HLayout", "ui.GridLayout", "ui.FormLayout", "ui.StackedLayout",
    "ui.Window", "ui.Modal", "ui.Dock", "ui.Dockable", "ui.Menu", "ui.MenuItem",
    "ui.Menubar", "ui.Toolbar", "ui.ToolbarButton", "ui.StatusBar", "ui.Spacer",
    "ui.KeyboardShortcut", "ui.DesignSurface", "ui.WidgetPalette", "ui.TableItem",
    "ui.TreeViewItem", "ui.TabItem", "ui.SlidingStackedWidget", "ui.DropMenu",
    "ui.DropShadow", "ui.ButtonGroup", "ui.AutoComplete", "ui.SysTray",
    "ui.SysNotification", "ui.Theme", "ui.Dialogs",
}


def palette_classes():
    """Widget classes worth offering, as "ui.Name" strings."""
    from limekit.services.inspect import Introspect
    buildable = set(Introspect.buildableClasses())
    return sorted(c for c in buildable if c.startswith("ui.") and c not in _NOT_WIDGETS)


def grouped():
    """((title, [class, ...]), ...) in palette order, "Other" last."""
    remaining = set(palette_classes())
    out = []
    for title, names in GROUPS:
        members = [f"ui.{n}" for n in names if f"ui.{n}" in remaining]
        remaining -= set(members)
        if members:
            out.append((title, members))
    if remaining:
        out.append(("Other", sorted(remaining)))
    return tuple(out)


class _PaletteList(QListWidget):
    def mimeTypes(self):
        return [CLASS_MIME]

    def mimeData(self, items):
        mime = QMimeData()
        for item in items:
            cls = item.data(_CLASS_ROLE)
            if cls:
                mime.setData(CLASS_MIME, str(cls).encode())
                break
        return mime


class WidgetPalette(LimeWidget, QWidget):
    __lime__ = "ui.WidgetPalette"

    def __init__(self):
        super().__init__()
        self._onPick = None
        self.filter = QLineEdit()
        self.filter.setPlaceholderText("Search widgets")
        self.filter.setClearButtonEnabled(True)
        self.list = _PaletteList()
        self.list.setDragEnabled(True)
        self.list.setDragDropMode(QListWidget.DragDropMode.DragOnly)
        self.list.setDefaultDropAction(Qt.DropAction.CopyAction)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.filter)
        layout.addWidget(self.list)

        self._fill()
        self.filter.textChanged.connect(self.setFilter)
        self.list.itemDoubleClicked.connect(self._pick)

    def _fill(self):
        for title, classes in grouped():
            header = QListWidgetItem(title)
            header.setFlags(Qt.ItemFlag.NoItemFlags)
            font = header.font(); font.setBold(True); header.setFont(font)
            self.list.addItem(header)
            for cls in classes:
                item = QListWidgetItem("   " + cls[3:])
                item.setText(cls[3:])
                item.setData(_CLASS_ROLE, cls)
                item.setFlags(Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled
                              | Qt.ItemFlag.ItemIsDragEnabled)
                self.list.addItem(item)

    def _pick(self, item):
        cls = item.data(_CLASS_ROLE)
        if cls and self._onPick is not None:
            self._onPick(cls)

    @method({"handler": "fun(class: string)"}, returns="self",
            doc="Called with the class name when an item is double-clicked.")
    def setOnPick(self, handler):
        self._onPick = guard(handler, widget="WidgetPalette", event="onPick")
        return self

    @method(returns="string", doc="The class of the selected item, or nil.")
    def getSelectedClass(self):
        item = self.list.currentItem()
        return item.data(_CLASS_ROLE) if item is not None else None

    @method({"text": "string"}, returns="self",
            doc="Hides items whose name does not contain the text. Headers "
                "hide when their whole group does.")
    def setFilter(self, text):
        needle = str(text or "").strip().lower()
        if self.filter.text() != (text or ""):
            self.filter.setText(text or "")
        visible_in_group = 0
        header = None
        for i in range(self.list.count()):
            item = self.list.item(i)
            if item.data(_CLASS_ROLE) is None:
                if header is not None:
                    header.setHidden(visible_in_group == 0)
                header, visible_in_group = item, 0
                continue
            shown = needle in item.text().lower()
            item.setHidden(not shown)
            visible_in_group += int(shown)
        if header is not None:
            header.setHidden(visible_in_group == 0)
        return self

    @method(returns="table", doc="Every class the palette offers.")
    def getClasses(self):
        classes = palette_classes()
        try:
            return to_lua(classes)
        except BridgeError:
            return classes
```

Move `CLASS_MIME` to a tiny shared spot: define it in `designsurface.py` and import it in the palette (`from limekit.widgets.designsurface import CLASS_MIME`) instead of duplicating.

- [ ] **Step 4: Regenerate and run everything**

```bash
python tools/generate_manifest.py && python tools/generate_stubs.py && python tools/generate_lua.py && python tools/generate_api_index.py "../Limer-Limekit"
python -m pytest -q
```
Expected: all pass, including the manifest/stubs no-op tests.

- [ ] **Step 5: Commit** (Limekit and Limer separately)

```bash
git add -A && git commit -m "ui.WidgetPalette: a draggable, searchable list of every buildable widget"
cd ../Limer-Limekit && git add scripts/data/api_index.lua && git commit -m "Regenerate the API index for WidgetPalette and DesignSurface drops"
```

---

### Task 5: Model tree operations and the Lua test project

**Files:**
- Rewrite: `Limer-Limekit/scripts/app/core/design_model.lua`
- Create: `Limer-Limekit/tests/app.json`, `Limer-Limekit/tests/scripts/main.lua`

**Interfaces (all in `DesignModel`):**
- `blank() -> design` where `design = { version = 1, window = {title, width, height}, root = node }`
- `node(class) -> node`, `container(layout) -> node`, `stretch(n) -> pseudo`, `spacing(size) -> pseudo`
- `isContainer(node)`, `isPseudo(node)`, `parentOf(design, node) -> node|nil`, `indexOf(parent, child) -> int|nil`, `walk(node, fn(node, depth))`
- `insert(design, parent, node, slot) -> ok, reason` with slot `{index=}` or `{row=, column=}`
- `move(design, node, parent, slot) -> ok, reason`
- `remove(design, node) -> ok, reason`
- `wrap(design, node, layout) -> container|nil, reason`, `unwrap(design, container) -> ok, reason`
- `setLayout(design, container, layout) -> ok, reason`
- `rename(design, node, name) -> ok, reason`, `nameFor(design, class) -> string`
- `LAYOUTS = { "ui.VLayout", "ui.HLayout", "ui.GridLayout", "ui.FormLayout" }`, `layoutKind(layoutClass) -> "vbox"|"hbox"|"grid"|"form"`

- [ ] **Step 1: Create the test project**

`tests/app.json`:
```json
{ "api": "2.0", "project": { "name": "Limer tests", "version": "1.0" }, "files": { "aliases": {} } }
```

`tests/scripts/main.lua` (runner plus the first checks):
```lua
-- Limer's model tests, as a Limekit project: `python -m limekit tests`.
-- Limer ships no Python, so its tests are Lua too.
local here = debug.getinfo(1, "S").source:sub(2):match("(.*)[/\\]") or "."
package.path = here .. "/../../scripts/?.lua;" .. package.path

local sys = require("limekit.sys")
local DesignModel = require("app.core.design_model")

local failures, count = 0, 0
local function check(name, fn)
    count = count + 1
    local ok, err = pcall(fn)
    if ok then print("ok    " .. name)
    else failures = failures + 1; print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end
local function eq(a, b, what)
    if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

check("blank design has a column root", function()
    local d = DesignModel.blank()
    eq(d.root.class, "ui.Container"); eq(d.root.layout, "ui.VLayout"); eq(#d.root.children, 0)
    eq(d.window.title, "My App")
end)

check("insert by index into a column", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.Label"), DesignModel.node("ui.LineEdit")
    assert(DesignModel.insert(d, d.root, a, { index = 1 }))
    assert(DesignModel.insert(d, d.root, b, { index = 2 }))
    assert(DesignModel.insert(d, d.root, c, { index = 1 }))
    eq(d.root.children[1], c); eq(d.root.children[2], a); eq(d.root.children[3], b)
    eq(a.name, "button1"); eq(b.name, "label1")
end)

check("insert into a grid refuses an occupied cell", function()
    local d = DesignModel.blank()
    DesignModel.setLayout(d, d.root, "ui.GridLayout")
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    assert(DesignModel.insert(d, d.root, a, { row = 1, column = 1 }))
    local ok, why = DesignModel.insert(d, d.root, b, { row = 1, column = 1 })
    eq(ok, false); assert(why:find("occupied"))
    eq(a.grid.row, 1); eq(a.grid.column, 1); eq(a.grid.rowSpan, 1)
end)

check("insert into a form gives the row a label", function()
    local d = DesignModel.blank()
    DesignModel.setLayout(d, d.root, "ui.FormLayout")
    local a = DesignModel.node("ui.LineEdit")
    assert(DesignModel.insert(d, d.root, a, { index = 1 }))
    eq(a.form.label, "lineEdit1")
end)

check("move later within the same parent lands where the user pointed", function()
    local d = DesignModel.blank()
    local a, b, c = DesignModel.node("ui.Button"), DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    for i, n in ipairs({ a, b, c }) do DesignModel.insert(d, d.root, n, { index = i }) end
    assert(DesignModel.move(d, a, d.root, { index = 3 }))   -- "before c"
    eq(d.root.children[1], b); eq(d.root.children[2], a); eq(d.root.children[3], c)
    assert(DesignModel.move(d, c, d.root, { index = 1 }))
    eq(d.root.children[1], c)
end)

check("move refuses a descendant target", function()
    local d = DesignModel.blank()
    local outer = DesignModel.container("ui.VLayout")
    local inner = DesignModel.container("ui.HLayout")
    DesignModel.insert(d, d.root, outer, { index = 1 })
    DesignModel.insert(d, outer, inner, { index = 1 })
    local ok, why = DesignModel.move(d, outer, inner, { index = 1 })
    eq(ok, false); assert(why:find("inside itself"))
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
    assert(DesignModel.unwrap(d, box)); eq(d.root.children[1], a)
    DesignModel.insert(d, box, b, { index = 1 })  -- not in tree, harmless
    eq((DesignModel.unwrap(d, d.root)), false)
end)

check("setLayout converts placement", function()
    local d = DesignModel.blank()
    local a, b = DesignModel.node("ui.Button"), DesignModel.node("ui.Button")
    DesignModel.insert(d, d.root, a, { index = 1 }); DesignModel.insert(d, d.root, b, { index = 2 })
    DesignModel.insert(d, d.root, DesignModel.stretch(), { index = 3 })
    assert(DesignModel.setLayout(d, d.root, "ui.GridLayout"))
    eq(#d.root.children, 2)                                      -- stretch dropped
    eq(a.grid.row, 1); eq(b.grid.row, 2); eq(b.grid.column, 1)
    assert(DesignModel.setLayout(d, d.root, "ui.HLayout"))
    eq(a.grid, nil); eq(a.stretch, 0)
    assert(DesignModel.setLayout(d, d.root, "ui.FormLayout"))
    eq(a.form.label, "button1")
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
end)

check("names stay unique after a load", function()
    local d = DesignModel.blank()
    DesignModel.insert(d, d.root, DesignModel.node("ui.Button"), { index = 1 })
    eq(DesignModel.nameFor(d, "ui.Button"), "button2")
end)

print(string.format("\n%d checks, %d failed", count, failures))
sys.System.exit(failures == 0 and 0 or 1)
```

- [ ] **Step 2: Run to verify failure** — `cd Limer-Limekit && python -m limekit tests` — expected FAIL lines (old API).

- [ ] **Step 3: Rewrite `design_model.lua`** (tree half)

```lua
local DesignModel = {}

DesignModel.LAYOUTS = { "ui.VLayout", "ui.HLayout", "ui.GridLayout", "ui.FormLayout" }
local KINDS = { ["ui.VLayout"] = "vbox", ["ui.HLayout"] = "hbox",
                ["ui.GridLayout"] = "grid", ["ui.FormLayout"] = "form" }
function DesignModel.layoutKind(layout) return KINDS[layout] end

local RESERVED = {}
for word in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while window root M ui"):gmatch("%S+") do
    RESERVED[word] = true
end

-- NAMES ---------------------------------------------------------------------

local function usedNames(design)
    local used = {}
    DesignModel.walk(design.root, function(node) if node.name then used[node.name] = true end end)
    return used
end

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
    if name ~= node.name and usedNames(design)[name] then return false, name .. " is already used" end
    node.name = name
    return true
end

-- NODES ---------------------------------------------------------------------

function DesignModel.node(class) return { class = class, props = {} } end
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

function DesignModel.blank()
    local design = { version = 1, window = { title = "My App", width = 640, height = 480 } }
    design.root = DesignModel.container("ui.VLayout")
    design.root.name = "root"
    return design
end

function DesignModel.walk(node, fn, depth)
    depth = depth or 0
    fn(node, depth)
    for _, child in ipairs(node.children or {}) do DesignModel.walk(child, fn, depth + 1) end
end

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
    for i, c in ipairs(parent.children or {}) do if c == child then return i end end
    return nil
end

local function descends(node, ancestor)
    if node == ancestor then return true end
    for _, child in ipairs(ancestor.children or {}) do
        if descends(node, child) then return true end
    end
    return false
end

-- PLACEMENT -----------------------------------------------------------------

local function clearPlacement(node)
    node.grid, node.form, node.stretch = nil, nil, nil
end

local function cellTaken(parent, row, column, except)
    for _, c in ipairs(parent.children) do
        if c ~= except and c.grid and c.grid.row == row and c.grid.column == column then return true end
    end
    return false
end

-- Gives `node` the placement fields the parent's layout reads, and returns
-- the list index it should sit at.
local function place(design, parent, node, slot, except)
    local kind = KINDS[parent.layout]
    if DesignModel.isPseudo(node) and kind ~= "vbox" and kind ~= "hbox" then
        return nil, "stretch and spacing only belong in a row or column"
    end
    clearPlacement(node)
    if kind == "grid" then
        local row, column = slot.row or 1, slot.column or 1
        if cellTaken(parent, row, column, except) then
            return nil, ("cell %d,%d is occupied"):format(row, column)
        end
        node.grid = { row = row, column = column, rowSpan = 1, columnSpan = 1 }
        return #parent.children + 1
    end
    if kind == "form" then
        node.form = { label = node.name or "" }
    elseif not DesignModel.isPseudo(node) then
        node.stretch = 0
    end
    local index = slot.index or (#parent.children + 1)
    return math.max(1, math.min(index, #parent.children + 1))
end

function DesignModel.insert(design, parent, node, slot)
    if not DesignModel.isContainer(parent) then return false, "not a container" end
    if not DesignModel.isPseudo(node) and not node.name then
        node.name = DesignModel.nameFor(design, node.class)
    end
    local index, why = place(design, parent, node, slot or {})
    if not index then return false, why end
    table.insert(parent.children, index, node)
    return true
end

function DesignModel.move(design, node, parent, slot)
    if node == design.root then return false, "the root stays put" end
    if descends(parent, node) then return false, "a widget cannot be moved inside itself" end
    local oldParent = DesignModel.parentOf(design, node)
    if not oldParent then return false, "not in the design" end
    local oldIndex = DesignModel.indexOf(oldParent, node)
    local index, why = place(design, parent, node, slot or {}, node)
    if not index then return false, why end
    table.remove(oldParent.children, oldIndex)
    if parent == oldParent and index > oldIndex then index = index - 1 end
    index = math.min(index, #parent.children + 1)
    table.insert(parent.children, index, node)
    return true
end

function DesignModel.remove(design, node)
    if node == design.root then return false, "the root cannot be removed" end
    local parent = DesignModel.parentOf(design, node)
    if not parent then return false, "not in the design" end
    table.remove(parent.children, DesignModel.indexOf(parent, node))
    return true
end

function DesignModel.wrap(design, node, layout)
    if node == design.root then return nil, "the root cannot be wrapped" end
    local parent = DesignModel.parentOf(design, node)
    if not parent then return nil, "not in the design" end
    local box = DesignModel.container(layout)
    box.name = DesignModel.nameFor(design, "ui.Container")
    local index = DesignModel.indexOf(parent, node)
    -- The box takes the node's place and placement; the node starts fresh
    -- inside the box.
    box.grid, box.form, box.stretch = node.grid, node.form, node.stretch
    parent.children[index] = box
    clearPlacement(node)
    node.stretch = 0
    box.children[1] = node
    return box
end

function DesignModel.unwrap(design, box)
    if box == design.root then return false, "the root cannot be unwrapped" end
    if not DesignModel.isContainer(box) or #box.children ~= 1 then
        return false, "only a container holding exactly one widget can be unwrapped"
    end
    local parent = DesignModel.parentOf(design, box)
    if not parent then return false, "not in the design" end
    local child = box.children[1]
    if DesignModel.isPseudo(child) then return false, "nothing to keep" end
    child.grid, child.form, child.stretch = box.grid, box.form, box.stretch
    parent.children[DesignModel.indexOf(parent, box)] = child
    return true
end

function DesignModel.setLayout(design, box, layout)
    if not DesignModel.isContainer(box) then return false, "not a container" end
    if not KINDS[layout] then return false, "unknown layout " .. tostring(layout) end
    local old, new = KINDS[box.layout], KINDS[layout]
    local kept = {}
    if old == "grid" then
        table.sort(box.children, function(a, b)
            if a.grid.row ~= b.grid.row then return a.grid.row < b.grid.row end
            return a.grid.column < b.grid.column
        end)
    end
    for _, child in ipairs(box.children) do
        if not DesignModel.isPseudo(child) or new == "vbox" or new == "hbox" then
            kept[#kept + 1] = child
        end
    end
    box.children = kept
    box.layout = layout
    for i, child in ipairs(box.children) do
        clearPlacement(child)
        if new == "grid" then child.grid = { row = i, column = 1, rowSpan = 1, columnSpan = 1 }
        elseif new == "form" then child.form = { label = child.name or "" }
        elseif not DesignModel.isPseudo(child) then child.stretch = 0 end
    end
    return true
end

return DesignModel
```

- [ ] **Step 4: Run** — `python -m limekit tests` — Expected: `11 checks, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/app/core/design_model.lua tests
git commit -m "Design model: placement in four layouts, move, wrap, rename, and a Lua test project"
```

---

### Task 6: Serialize, deserialize, snapshot, undo

**Files:**
- Modify: `scripts/app/core/design_model.lua`, `tests/scripts/main.lua`

**Interfaces:**
- `serialize(design) -> string` (Lua source starting `return {`)
- `deserialize(source) -> design|nil, reason`
- `snapshot(design) -> design` (deep copy)
- `Undo.new(limit?) -> undo` with `undo:push(design)`, `undo:undo() -> design|nil`, `undo:redo() -> design|nil`, `undo:canUndo()`, `undo:canRedo()`, `undo:reset(design)`

- [ ] **Step 1: Add checks**

```lua
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
    eq(back.root.children[1].form.label, "lineEdit1")
end)

check("deserialize rejects junk and the wrong shape", function()
    local d, why = DesignModel.deserialize("return 42")
    eq(d, nil); assert(why)
    d, why = DesignModel.deserialize("this is not lua")
    eq(d, nil); assert(why)
    d, why = DesignModel.deserialize("return { version = 1 }")
    eq(d, nil); assert(why:find("root"))
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
    eq(undo:canUndo(), false)
    for i = 1, 4 do
        d = DesignModel.snapshot(d)
        DesignModel.insert(d, d.root, DesignModel.node("ui.Button"), { index = 1 })
        undo:push(d)
    end
    eq(#undo:undo().root.children, 3)
    eq(#undo:undo().root.children, 2)
    eq(#undo:undo().root.children, 1)
    eq(undo:undo(), nil)                        -- limited to 3 back
    eq(#undo:redo().root.children, 2)
    d = DesignModel.snapshot(undo:current())
    DesignModel.remove(d, d.root.children[1])
    undo:push(d)
    eq(undo:canRedo(), false)
end)
```

- [ ] **Step 2: Run** — FAIL on `serialize`.

- [ ] **Step 3: Implement**

```lua
-- FILES ---------------------------------------------------------------------

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function literal(value)
    local t = type(value)
    if t == "string" then return string.format("%q", value) end
    if t == "number" or t == "boolean" then return tostring(value) end
    return "nil"
end

local function emitTable(t, indent, out)
    local pad = string.rep("    ", indent)
    out[#out + 1] = "{\n"
    if #t > 0 then
        for _, v in ipairs(t) do
            out[#out + 1] = pad .. "    "
            if type(v) == "table" then emitTable(v, indent + 1, out) else out[#out + 1] = literal(v) end
            out[#out + 1] = ",\n"
        end
    else
        for _, k in ipairs(sortedKeys(t)) do
            local v = t[k]
            local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. literal(k) .. "]")
            out[#out + 1] = pad .. "    " .. key .. " = "
            if type(v) == "table" then emitTable(v, indent + 1, out) else out[#out + 1] = literal(v) end
            out[#out + 1] = ",\n"
        end
    end
    out[#out + 1] = pad .. "}"
end

function DesignModel.serialize(design)
    local out = { "return " }
    emitTable(design, 0, out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

local function checkNode(node, path)
    if type(node) ~= "table" then return false, path .. " is not a table" end
    if node.kind then return true end
    if type(node.class) ~= "string" then return false, path .. " has no class" end
    if type(node.name) ~= "string" then return false, path .. " has no name" end
    node.props = node.props or {}
    if node.children then
        if not KINDS[node.layout] then return false, path .. " has an unknown layout" end
        for i, child in ipairs(node.children) do
            local ok, why = checkNode(child, path .. ".children[" .. i .. "]")
            if not ok then return false, why end
        end
    end
    return true
end

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
    return design
end

function DesignModel.snapshot(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DesignModel.snapshot(v) end
    return copy
end

-- UNDO ----------------------------------------------------------------------

local Undo = {}
Undo.__index = Undo
DesignModel.Undo = Undo

function Undo.new(limit)
    return setmetatable({ limit = limit or 200, stack = {}, at = 0 }, Undo)
end
function Undo:reset(design) self.stack, self.at = { design }, 1 end
function Undo:current() return self.stack[self.at] end
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
```

Note: with limit 3 and 5 entries pushed (reset + 4), the stack holds the last 4 states so three undos are possible. The check expects exactly that.

- [ ] **Step 4: Run** — `15 checks, 0 failed`.

- [ ] **Step 5: Commit** — `git commit -am "Design model: save, load, snapshot and undo"`

---

### Task 7: Generation

**Files:**
- Modify: `scripts/app/core/design_model.lua`, `tests/scripts/main.lua`

**Interfaces:**
- `generate(design, moduleName) -> string`. Output returns `M` with `M.window`, `M.root` and `M.<name>` for every named node.

- [ ] **Step 1: Add checks**

```lua
local function stubUi()
    -- A fake `ui` recording calls, so generated code can be run without Qt.
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
    local ok = DesignModel.node("ui.Button"); ok.props.text = "OK"
    DesignModel.insert(d, row, ok, { index = 2 })
    DesignModel.rename(d, ok, "ok")

    local a, b = DesignModel.generate(d, "login"), DesignModel.generate(d, "login")
    eq(a, b, "determinism")
    assert(a:find('M.name:setHint("Your name")', 1, true), a)
    assert(a:find('rootLayout:addChild("Name", M.name)', 1, true), a)
    assert(a:find('container1Layout:addStretch(1)', 1, true), a)
    assert(a:find('M.window = ui.Window { title = "Login" }', 1, true), a)
    assert(a:find('M.window:setSize(400, 200)', 1, true), a)

    local M = runGenerated(a)
    assert(M.window and M.root and M.name and M.ok and M.container1)
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
```

- [ ] **Step 2: Run** — FAIL on `generate`.

- [ ] **Step 3: Implement**

```lua
-- CODE GENERATION -----------------------------------------------------------

local function setterName(prop) return "set" .. prop:sub(1, 1):upper() .. prop:sub(2) end

local function emitWidget(node, lines)
    if DesignModel.isPseudo(node) then return end
    lines[#lines + 1] = ("M.%s = %s()"):format(node.name, node.class)
    for _, key in ipairs(sortedKeys(node.props)) do
        lines[#lines + 1] = ("M.%s:%s(%s)"):format(node.name, setterName(key), literal(node.props[key]))
    end
    for _, child in ipairs(node.children or {}) do emitWidget(child, lines) end
end

local function emitLayout(node, lines)
    if not DesignModel.isContainer(node) then return end
    for _, child in ipairs(node.children) do emitLayout(child, lines) end
    local L = node.name .. "Layout"
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("local %s = %s()"):format(L, node.layout)
    local kind = KINDS[node.layout]
    for _, child in ipairs(node.children) do
        if child.kind == "stretch" then
            lines[#lines + 1] = ("%s:addStretch(%d)"):format(L, child.stretch or 1)
        elseif child.kind == "spacing" then
            lines[#lines + 1] = ("%s:addSpacing(%d)"):format(L, child.size or 0)
        elseif kind == "grid" then
            local g = child.grid or { row = 1, column = 1, rowSpan = 1, columnSpan = 1 }
            lines[#lines + 1] = ("%s:addChild(M.%s, %d, %d, %d, %d)"):format(
                L, child.name, g.row, g.column, g.rowSpan or 1, g.columnSpan or 1)
        elseif kind == "form" then
            lines[#lines + 1] = ("%s:addChild(%s, M.%s)"):format(
                L, literal((child.form or {}).label or ""), child.name)
        elseif (child.stretch or 0) > 0 then
            lines[#lines + 1] = ("%s:addChild(M.%s, %d)"):format(L, child.name, child.stretch)
        else
            lines[#lines + 1] = ("%s:addChild(M.%s)"):format(L, child.name)
        end
    end
    lines[#lines + 1] = ("M.%s:setLayout(%s)"):format(node.name, L)
end

function DesignModel.generate(design, moduleName)
    local lines = {
        ("-- GENERATED by Limer's designer from design/%s.design.lua."):format(moduleName or "main"),
        "-- Regenerate from the designer; edits here are overwritten.",
        'local ui = require("limekit.ui")',
        "",
        "local M = {}",
        "",
    }
    emitWidget(design.root, lines)
    emitLayout(design.root, lines)
    local w = design.window
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("M.window = ui.Window { title = %s }"):format(literal(w.title or "My App"))
    lines[#lines + 1] = ("M.window:setSize(%d, %d)"):format(w.width or 640, w.height or 480)
    lines[#lines + 1] = ("M.window:setMainChild(M.%s)"):format(design.root.name)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "return M"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end
```

- [ ] **Step 4: Run** — `17 checks, 0 failed`.

- [ ] **Step 5: Commit** — `git commit -am "Design model: generate a module that returns its widgets by name"`

---

### Task 8: The designer view

**Files:**
- Create: `scripts/gui/views/designer/canvas.lua`, `outline.lua`, `properties.lua`, `preview.lua`, `files.lua`
- Rewrite: `scripts/gui/views/designer/view.lua`

No automated test at this layer (it is all Qt widgets driven by a person); Task 9 has the manual walkthrough. Keep every module free of Limer globals except `App` and `AppState`.

**Interfaces:**
- `Canvas.new(surface, onDrop(drop), onSelect(node))` → `canvas:rebuild(design)`, `canvas:widgetFor(node)`, `canvas:nodeFor(widget)`, `canvas:select(node)`.
- `Outline.new(tree, onSelect(node))` → `outline:refresh(design, selected)`.
- `Properties.new(table, callbacks{onProp(node, name, value), onRename(node, name), onPlacement(node, field, value), onLayout(node, layout)})` → `props:show(node, widget)`.
- `Preview.new(textField)` → `preview:refresh(design, moduleName)`.
- `Files.new()` → `files:list(projectPath) -> names`, `files:load(projectPath, name) -> design|nil, why`, `files:save(projectPath, name, design) -> ok, why`, `files:generatedPath(projectPath, name)`, `files:writeGenerated(projectPath, name, source) -> path|nil, why`.

- [ ] **Step 1: `canvas.lua`**

```lua
-- The canvas: the model, built as real widgets on a DesignSurface.
-- Rebuilt whole after every change; never patched.
local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"

local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(surface, onDrop, onSelect)
    local self = setmetatable({ surface = surface, widgetOf = {}, nodeOf = {} }, Canvas)
    surface:setOnSelect(function(widget) onSelect(widget and self.nodeOf[widget] or nil) end)
    surface:setOnDrop(function(drop)
        local target = self.nodeOf[drop.target]
        if not target then return end
        local slot = { index = drop.index, row = drop.row, column = drop.column }
        if drop.kind == "class" then
            onDrop({ kind = "class", class = drop.class, target = target, slot = slot })
        else
            local node = self.nodeOf[drop.widget]
            if node then onDrop({ kind = "move", node = node, target = target, slot = slot }) end
        end
    end)
    return self
end

local function className(class) return class:match("%.(.+)$") end

local function failed(node, err)
    local label = ui.Label(("%s failed: %s"):format(node.class, tostring(err)))
    label:setStyleSheet("color: #d32f2f; border: 1px dashed #d32f2f; padding: 4px;")
    return label
end

function Canvas:build(node)
    local ctor = ui[className(node.class)]
    local ok, widget = pcall(function() return ctor() end)
    if not ok or widget == nil then widget = failed(node, widget) ; node.buildError = tostring(widget) else node.buildError = nil end
    for name, value in pairs(node.props or {}) do
        pcall(sys.Introspect.setProperty, widget, name, value)
    end
    self.widgetOf[node], self.nodeOf[widget] = widget, node

    if DesignModel.isContainer(node) and ok then
        local layout = ui[className(node.layout)]()
        local kind = DesignModel.layoutKind(node.layout)
        for _, child in ipairs(node.children) do
            if child.kind == "stretch" then layout:addStretch(child.stretch or 1)
            elseif child.kind == "spacing" then layout:addSpacing(child.size or 0)
            elseif kind == "grid" then
                local g = child.grid
                layout:addChild(self:build(child), g.row, g.column, g.rowSpan or 1, g.columnSpan or 1)
            elseif kind == "form" then layout:addChild(child.form.label or "", self:build(child))
            else layout:addChild(self:build(child), child.stretch or 0) end
        end
        -- An empty container has no height of its own; give it some so
        -- there is something to drop onto.
        if #node.children == 0 then widget:setMinHeight(40); widget:setMinWidth(40) end
        widget:setLayout(layout)
    end
    return widget
end

function Canvas:rebuild(design)
    self.widgetOf, self.nodeOf = {}, {}
    local root = self:build(design.root)
    root:setFixedSize(design.window.width, design.window.height)
    self.surface:setDesignChild(root)
    self.surface:refresh()
end

function Canvas:widgetFor(node) return self.widgetOf[node] end
function Canvas:nodeFor(widget) return self.nodeOf[widget] end
function Canvas:select(node) self.surface:setSelected(node and self.widgetOf[node] or nil) end

return Canvas
```

- [ ] **Step 2: `outline.lua`**

```lua
-- The tree beside the canvas, mirroring the model.
local ui = require("limekit.ui")
local DesignModel = require "app.core.design_model"

local Outline = {}
Outline.__index = Outline

function Outline.new(tree, onSelect)
    local self = setmetatable({ tree = tree, nodeOf = {} }, Outline)
    tree:setHeaderHidden(true)
    tree:setOnItemClick(function(_, item) local node = self.nodeOf[item]; if node then onSelect(node) end end)
    return self
end

local function labelFor(node)
    if node.kind == "stretch" then return ("~ stretch %d"):format(node.stretch or 1) end
    if node.kind == "spacing" then return ("~ spacing %d"):format(node.size or 0) end
    local text = node.name .. "  " .. node.class:match("%.(.+)$")
    if DesignModel.isContainer(node) then text = text .. "  [" .. node.layout:match("%.(.+)$") .. "]" end
    if node.buildError then text = text .. "  !" end
    return text
end

function Outline:refresh(design, selected)
    self.tree:clear()
    self.nodeOf = {}
    local function add(node, parentItem)
        local item = ui.TreeViewItem(labelFor(node))
        self.nodeOf[item] = node
        if parentItem then parentItem:addChild(item) else self.tree:addTopItem(item) end
        for _, child in ipairs(node.children or {}) do add(child, item) end
        item:setExpanded(true)
        return item
    end
    add(design.root, nil)
    self.tree:expandAll()
end

return Outline
```

Check `ui.TreeViewItem` constructor and `setOnItemClick` signature in `stubs/ui.lua` before writing; adapt argument order to what the stub says.

- [ ] **Step 3: `properties.lua`**

```lua
-- The property panel: what the selection is, where it sits, and what its
-- widget declares. The table has two columns and the value column takes
-- the room, which is what the old three-column panel never managed.
local ui  = require("limekit.ui")
local sys = require("limekit.sys")
local DesignModel = require "app.core.design_model"

local Properties = {}
Properties.__index = Properties

function Properties.new(table_, callbacks)
    local self = setmetatable({ table = table_, cb = callbacks, rows = {}, filling = false }, Properties)
    table_:setColumnCount(2)
    table_:setColumnHeaders({ "property", "value" })
    table_:setCellsEditable(true)
    table_:setColumnWidth(1, 150)
    table_:setOnCellChange(function(_, row, column) self:edited(row, column) end)
    return self
end

local LAYOUT_NAMES = { "VLayout", "HLayout", "GridLayout", "FormLayout" }

-- Each row: { label, value, kind, apply(value) }; kind drives the editor.
function Properties:rowsFor(node, widget)
    local rows, cb = {}, self.cb
    local function row(label, value, kind, apply, options)
        rows[#rows + 1] = { label = label, value = value, kind = kind, apply = apply, options = options }
    end
    if DesignModel.isPseudo(node) then
        if node.kind == "stretch" then
            row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
        else
            row("size", node.size, "int", function(v) cb.onPlacement(node, "size", v) end)
        end
        return rows
    end
    row("name", node.name, "string", function(v) cb.onRename(node, v) end)
    if DesignModel.isContainer(node) then
        row("layout", node.layout:match("%.(.+)$"), "enum",
            function(v) cb.onLayout(node, "ui." .. v) end, LAYOUT_NAMES)
    end
    if node.grid then
        for _, f in ipairs({ "row", "column", "rowSpan", "columnSpan" }) do
            row("grid." .. f, node.grid[f], "int", function(v) cb.onPlacement(node, "grid." .. f, v) end)
        end
    elseif node.form then
        row("form.label", node.form.label, "string", function(v) cb.onPlacement(node, "form.label", v) end)
    elseif node.stretch ~= nil then
        row("stretch", node.stretch, "int", function(v) cb.onPlacement(node, "stretch", v) end)
    end
    if widget then
        for _, prop in ipairs(sys.Introspect.properties(widget)) do
            if prop.settable then
                local kind = prop.options and "enum" or prop.type
                row(prop.name, prop.value, kind, function(v) cb.onProp(node, prop.name, v) end, prop.options)
            end
        end
    end
    return rows
end

function Properties:show(node, widget)
    self.filling = true
    self.table:clearContent()
    self.rows = node and self:rowsFor(node, widget) or {}
    self.table:setRowCount(#self.rows)
    for i, r in ipairs(self.rows) do
        self.table:setCellText(i, 1, r.label)
        if r.kind == "boolean" then
            local box = ui.CheckBox("")
            box:setChecked(r.value == true)
            box:setOnClick(function() r.apply(box:isChecked()) end)
            self.table:setCellChild(i, 2, box)
        elseif r.kind == "enum" then
            local combo = ui.ComboBox()
            combo:addItems(r.options)
            for k, opt in ipairs(r.options) do if opt == r.value then combo:setCurrentIndex(k) end end
            combo:setOnItemSelect(function() r.apply(combo:getText()) end)
            self.table:setCellChild(i, 2, combo)
        else
            self.table:setCellText(i, 2, tostring(r.value == nil and "" or r.value))
        end
    end
    self.filling = false
end

function Properties:edited(row, column)
    if self.filling or column ~= 2 then return end
    local r = self.rows[row]
    if not r or r.kind == "boolean" or r.kind == "enum" then return end
    local text = self.table:getCellItem(row, 2):getText()
    local value = text
    if r.kind == "int" then value = math.tointeger(tonumber(text)) or tonumber(text)
    elseif r.kind == "float" then value = tonumber(text) end
    if value == nil then value = text end
    r.apply(value)
end

return Properties
```

Check `ui.ComboBox:setCurrentIndex`, `ui.CheckBox:setChecked/isChecked/setOnClick` and `Table:clearContent` against the stubs; use the names the stubs declare.

- [ ] **Step 4: `preview.lua` and `files.lua`**

```lua
-- preview.lua: the Lua the design would generate, kept current.
local DesignModel = require "app.core.design_model"
local Preview = {}
Preview.__index = Preview
function Preview.new(field)
    field:setReadOnly(true)
    field:setWrapMode("none")
    return setmetatable({ field = field }, Preview)
end
function Preview:refresh(design, moduleName)
    self.field:setPlainText(DesignModel.generate(design, moduleName))
end
return Preview
```

```lua
-- files.lua: design files under design/, generated modules under scripts/designed/.
local fs = require("limekit.fs")
local DesignModel = require "app.core.design_model"

local Files = {}
local FS = fs.FileSystem

local function designDir(project) return FS.joinPaths(project, "design") end
function Files.designPath(project, name) return FS.joinPaths(designDir(project), name .. ".design.lua") end
function Files.generatedPath(project, name) return FS.joinPaths(FS.joinPaths(project, "scripts"), FS.joinPaths("designed", name .. ".lua")) end

function Files.list(project)
    local dir = designDir(project)
    if not FS.exists(dir) then return {} end
    local names = {}
    for _, entry in ipairs(FS.listFolder(dir)) do
        local name = tostring(entry):match("([^/\\]+)%.design%.lua$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function Files.load(project, name)
    local ok, text = pcall(FS.readFile, Files.designPath(project, name))
    if not ok then return nil, tostring(text) end
    return DesignModel.deserialize(text)
end

function Files.save(project, name, design)
    local dir = designDir(project)
    if not FS.exists(dir) then FS.createFolder(dir) end
    local ok, err = pcall(FS.writeFile, Files.designPath(project, name), DesignModel.serialize(design))
    if not ok then return false, tostring(err) end
    return true
end

function Files.writeGenerated(project, name, source)
    local dir = FS.joinPaths(FS.joinPaths(project, "scripts"), "designed")
    if not FS.exists(dir) then FS.createFolder(dir) end
    local path = Files.generatedPath(project, name)
    local ok, err = pcall(FS.writeFile, path, source)
    if not ok then return nil, tostring(err) end
    return path
end

return Files
```

Check what `FS.listFolder` returns (names or full paths) and adjust the match.

- [ ] **Step 5: `view.lua`**

Responsibilities: state `{ design, name, dirty, selected, undo }`; `mutate(fn, status)` helper that snapshots, applies, pushes undo, refreshes everything; toolbar; picker; shortcuts; context menu; generate dialog. Skeleton of the important parts:

```lua
local ui  = require("limekit.ui")
local App = require "app.core.app"
local AppState = require "app.core.app_state"
local DesignModel = require "app.core.design_model"
local Canvas = require "gui.views.designer.canvas"
local Outline = require "gui.views.designer.outline"
local Properties = require "gui.views.designer.properties"
local Preview = require "gui.views.designer.preview"
local Files = require "gui.views.designer.files"

local DesignerView = {}
local S -- state

local function setStatus(text) S.status:setText(text) end
local function project() return AppState.activeProjectPath end

local function refreshAll()
    S.canvas:rebuild(S.design)
    S.canvas:select(S.selected)
    S.outline:refresh(S.design, S.selected)
    S.props:show(S.selected, S.selected and S.canvas:widgetFor(S.selected))
    S.preview:refresh(S.design, S.name)
    S.titleField:setText(S.design.window.title)
    S.widthField:setText(tostring(S.design.window.width))
    S.heightField:setText(tostring(S.design.window.height))
    S.tabTitle(S.name .. (S.dirty and " *" or ""))
end

-- Selection is a node in the *current* design; after a snapshot it has to
-- be found again in the copy, by path.
local function pathOf(design, node)
    local path = {}
    local function find(n, trail)
        if n == node then path = trail; return true end
        for i, c in ipairs(n.children or {}) do
            local t = { table.unpack(trail) }; t[#t + 1] = i
            if find(c, t) then return true end
        end
        return false
    end
    if find(design.root, {}) then return path end
    return nil
end
local function nodeAt(design, path)
    local n = design.root
    for _, i in ipairs(path or {}) do n = n and n.children and n.children[i] end
    return n
end

--- Applies fn to a fresh snapshot; keeps it if fn returns true.
local function mutate(fn, status)
    local path = S.selected and pathOf(S.design, S.selected)
    local draft = DesignModel.snapshot(S.design)
    local ok, why, selectPath = fn(draft, path and nodeAt(draft, path))
    if not ok then setStatus(why or "no change"); return false end
    S.design = draft
    S.selected = nodeAt(draft, selectPath or path)
    S.undo:push(draft)
    S.dirty = true
    refreshAll()
    if status then setStatus(status) end
    return true
end

local function select(node)
    S.selected = node
    S.canvas:select(node)
    S.props:show(node, node and S.canvas:widgetFor(node))
    setStatus(node and ((node.name or node.kind) .. (node.class and ("  " .. node.class) or "")) or "nothing selected")
end

local function onDrop(drop)
    local targetPath = pathOf(S.design, drop.target)
    if drop.kind == "class" then
        mutate(function(d)
            local target = nodeAt(d, targetPath)
            local node = DesignModel.node(drop.class)
            local ok, why = DesignModel.insert(d, target, node, drop.slot)
            if not ok then return false, why end
            return true, nil, pathOf(d, node)
        end, "added " .. drop.class:match("%.(.+)$"))
    else
        local nodePath = pathOf(S.design, drop.node)
        mutate(function(d)
            local ok, why = DesignModel.move(d, nodeAt(d, nodePath), nodeAt(d, targetPath), drop.slot)
            if not ok then return false, why end
            return true, nil, nil
        end, "moved")
        -- moved node's path changed; reselect by search
    end
end
```

Plus: `addClass(class)` for palette double-click (insert into selection if container, else after it, else end of root), `deleteSelected`, `moveSelected(delta)` (box layouts only: `move` to index±1), `wrapSelected(layout)`, `unwrapSelected`, `addStretch`, `addSpacing`, `changeLayout(layout)`, `undo`/`redo` (set `S.design = S.undo:undo()`, reselect by path, refresh), `newDesign`, `openDesign(name)`, `save`, `saveAs` (prompt via `ui.Dialogs.prompt` if it exists, else a `ui.LineEdit` in the toolbar), `generate`, window title/width/height fields → `mutate`. Property callbacks:

```lua
local callbacks = {
    onProp = function(node, name, value)
        local path = pathOf(S.design, node)
        mutate(function(d)
            local n = nodeAt(d, path)
            local widget = S.canvas:widgetFor(node)
            local ok, result = pcall(sys.Introspect.setProperty, widget, name, value)
            if not ok then return false, "could not set " .. name .. ": " .. tostring(result) end
            n.props[name] = result
            return true
        end, node.name .. "." .. name .. " = " .. tostring(value))
    end,
    onRename = function(node, name)
        local path = pathOf(S.design, node)
        mutate(function(d) return DesignModel.rename(d, nodeAt(d, path), name) end, "renamed to " .. name)
    end,
    onPlacement = function(node, field, value)
        local path = pathOf(S.design, node)
        mutate(function(d)
            local n = nodeAt(d, path)
            local group, key = field:match("^(%w+)%.(%w+)$")
            if group then
                if group == "grid" and (key == "row" or key == "column") then
                    local parent = DesignModel.parentOf(d, n)
                    local slot = { row = n.grid.row, column = n.grid.column }
                    slot[key] = value
                    return DesignModel.move(d, n, parent, slot)
                end
                n[group][key] = value
            else
                n[field] = value
            end
            return true
        end, field .. " = " .. tostring(value))
    end,
    onLayout = function(node, layout)
        local path = pathOf(S.design, node)
        mutate(function(d) return DesignModel.setLayout(d, nodeAt(d, path), layout) end, "layout: " .. layout)
    end,
}
```

Keyboard shortcuts use `ui.KeyboardShortcut` with `setSequence` and `setOnPress`, parented to the view (check the constructor in the stubs). Context menu: `ui.Menu` with `ui.MenuItem`s, opened from the surface's right-click if `DesignSurface` exposes `setOnContextMenu`; if not, put the same actions in a "More" toolbar dropdown (`ui.DropMenu`) and skip the context menu — record that in the commit message.

Build the tab:

```lua
function DesignerView.create(setTabTitle)
    S = { undo = DesignModel.Undo.new(), dirty = false, name = "main", tabTitle = setTabTitle or function() end }
    S.status = ui.Label("")
    S.palette = ui.WidgetPalette()
    S.palette:setMinWidth(170); S.palette:setMaxWidth(240)
    S.palette:setOnPick(addClass)

    local surface = ui.DesignSurface()
    local scroller = ui.Scroller()
    scroller:setChild(surface); scroller:setResizable(true)
    S.canvas = Canvas.new(surface, onDrop, select)

    local tree = ui.TreeView(); S.outline = Outline.new(tree, select)
    local table_ = ui.Table(); S.props = Properties.new(table_, callbacks)
    local code = ui.TextField(); S.preview = Preview.new(code)
    local side = ui.Tab()
    side:addTab(tree, "Outline"); side:addTab(table_, "Properties"); side:addTab(code, "Code")
    side:setMinWidth(300)

    local split = ui.Splitter("horizontal")
    split:addChild(S.palette); split:addChild(scroller); split:addChild(side)

    local layout = ui.VLayout()
    layout:addLayout(buildToolbar())
    layout:addLayout(buildDesignRow())
    layout:addChild(split, 1)
    layout:addChild(S.status)
    S.view = ui.Container(); S.view:setLayout(layout)
    installShortcuts()
    newDesign()
    return { view = S.view, onProjectOpened = loadFirstDesign, isDirty = function() return S.dirty end }
end
```

`loadFirstDesign` is called from `project_tab_container`/`app.lua` where the project opens (find the call that fires the Properties tab refresh and add this beside it).

- [ ] **Step 6: Boot Limer and click through**

Run: `cd Limer-Limekit && python -m limekit .` (the Designer tab is unhidden in Task 9; for now temporarily toggle it or run with the tab shown locally). Drag a Button in, a LineEdit, wrap, change layout to form, edit text, undo, save, reopen Limer, load, generate. Fix what breaks. Watch the console for `WidgetCallbackError`.

- [ ] **Step 7: Commit** — `git add scripts/gui/views/designer && git commit -m "Designer: drag from a palette onto real widgets, in layouts, with undo, files and a code preview"`

---

### Task 9: Wire it in, document, walk through

**Files:**
- Modify: `scripts/gui/components/project_tab_container.lua` (show the tab), `scripts/gui/views/main_window.lua` (pass a tab-title setter; call `onProjectOpened`), `README.md`

- [ ] **Step 1: Show the tab** — replace the commented `addTab` and its paragraph with `self.tabs:addTab(designerTab.view, "Designer")`.

- [ ] **Step 2: Hook project open** — where `AppState.activeProjectPath` is set on open (grep `activeProjectPath =`), call `App.designerTab.onProjectOpened()` after it.

- [ ] **Step 3: README** — replace "The Designer" and "No widget palette in the dock" sections with:

```
### The Designer

Drag widgets from the palette onto the canvas. The canvas holds real
Limekit widgets running inside Limer, made inert by `ui.DesignSurface` so a
click selects a button instead of pressing it. Widgets land *in layouts* --
a column, a row, a grid or a form -- at the slot the indicator shows, which
is what makes a designed window survive being resized. Drag a placed widget
to move it. Right-click for wrap, unwrap, stretch, spacing and layout
changes. Ctrl+Z undoes.

A design is saved to `design/<name>.design.lua` and reopened from the
picker. Generate writes `scripts/designed/<name>.lua`, a module that returns
its widgets by name:

    local login = require("designed.login")
    login.ok:setOnClick(function() ... end)
    login.window:show()

Generation is one way: the designer never reads that file back, and never
touches `main.lua`.
```

- [ ] **Step 4: Manual walkthrough** — Build a login form: form layout root, LineEdit "Name", LineEdit "Password" (inputMode password if the enum offers it), a row with stretch + Cancel + OK. Save as `login`. Generate. Create a demo project `limekit-demos/designer login/` with `main.lua` requiring `designed.login`, run it from Limer, confirm the window shows and OK prints. Record anything that failed and was fixed in the commit message.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Show the designer, and say what it does"`

---

## Self-review

- Spec coverage: 1.1 (Tasks 1–3), 1.2 (Task 4), 1.3 (Tasks 1–4 tests), 2.1 (Tasks 5–7), 2.2 (Task 8), 2.3 (Task 9), 2.4 (Tasks 5–7), error handling (canvas placeholder in Task 8, load failure in `Files.load` + view status, property revert via `mutate` refusing).
- Names: `resolve_drop`, `indicator_rect`, `CLASS_MIME`, `MOVE_MIME`, `palette_classes`, `grouped`; Lua `insert/move/remove/wrap/unwrap/setLayout/rename/nameFor/serialize/deserialize/snapshot/Undo/generate/layoutKind/isPseudo` used consistently across Tasks 5–8.
- Unknown-class survival on load: `checkNode` accepts any class string; the canvas shows the placeholder. Covered.
