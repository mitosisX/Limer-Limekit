## ⚠️ IMPORTANT INSTRUCTIONS

Limekit is a framework developed in Python 3.10 that wraps around the PySide6 (Qt) framework. Please download and install python 3.10+ first.
⚠️ Visit https://www.python.org/downloads/ before proceeding

⚠️ But, you don't need to learn python AT ALL!! Only lua

⚠️⚠️ At the moment, I do not have a Mac, so, I can not guide you on how to install or run on it ⚠️⚠️

## Where to Download

Navigate to the Release section (to your right) and download the all the files in there (Limer-Limekit.rar, Tools.rar) to get started

## How to install
There are 3 compressed files to download and use.

1. Tools.rar
   - You shall use install.bat or install.sh to install the limekit-xx-py3-none-anyany.whl file
   - INSTALL THIS FIRST
     
2. For Limer, simply extract contents from Limer-Limekit.rar
   - The "run" files only help in debugging (showing errors on the console), feel free to use the run.py too. 

## Running Apps

You'll use the app called Limer mentioned above to create and run all Limekit programs and all Limekit examples provided.

## DONE?

You shall be greeted with this beautiful screen

<img src="images/showcase/1.png" width="500" alt="Limer">

## How Limer is laid out

Limer creates, configures, runs and builds Limekit projects. You write the
Lua in whatever editor you already use — Limekit ships Lua Language Server
stubs, so that editor knows the whole API: completion, signatures and doc
strings included.

- **Left — Project.** The open project's files. Double-click one and it
  opens in whatever your desktop has registered for it.
- **Centre — the home page, and your project's Application, Properties and
  Designer tabs.** One toolbar button switches between the home page and
  your project, and it is named after wherever you are not.
- **Right — Your Projects.** Everything under your Limekit projects folder.
  Double-click to open.
- **Bottom — Console and Inspector.** While a project is running, the
  Inspector shows its live widget tree: pick a widget, read and edit its
  properties, or run Lua inside it.
- **Ctrl+K — the Limekit API.** Search all 2273 classes, methods,
  properties and events; Enter copies the call.

### The Designer

Drag widgets from the palette on the left onto the canvas. The canvas holds
real Limekit widgets running inside Limer -- not pictures of them and not a
preview -- made inert by `ui.DesignSurface`, so a click selects a button
instead of pressing it.

**Layouts, not coordinates.** A widget lands *in a row, column, grid or
form*, at the slot the orange indicator shows, rather than at an x and a y.
That is what makes a designed window survive being resized. A Tab, Splitter
or Scroller is a drop target too: a widget dropped on a Tab gets a page made
around it. Drag a placed widget to move it; drag a selection handle to set
its minimum size; double-click to edit its text. Right-click (or the
More... button) for wrap, unwrap, change layout, add page, stretch,
spacing, and cut, copy, paste and duplicate -- a copied widget travels as
Lua on the clipboard and pastes into any design. The Outline tab shows the
tree, the Properties tab edits the selection -- its name, where it sits,
and every property its widget declares -- and the Code tab shows the Lua
that would be generated, kept current. Ctrl+Z undoes; Delete deletes.

**Run** (Ctrl+R) shows the design as a real window: a throwaway project is
written under `design/.preview/` and started through the ordinary project
runner, so the console and the Inspector work on it.

**Designs are saved** to `design/<name>.design.lua` in the project, one per
window, and reopened from the picker above the canvas. **Generate** writes
`scripts/designed/<name>.lua`: a module that returns its window and every
widget by name, so `main.lua` requires it and wires handlers on:

    local login = require("designed.login")
    login.ok:setOnClick(function() print("hello, " .. login.name:getText()) end)
    login.window:show()

**Generation is one way.** The design file is the source of truth; the
designer never reads the generated module back and never touches
`main.lua`. Regenerate rather than edit. This is the same bargain Qt
Designer strikes with `.ui`, and for the same reason: reconciling generated
code with hand-edited code is what kills these tools.

The framework side -- `ui.DesignSurface`, `ui.WidgetPalette` and
`sys.Introspect` -- lives in Limekit; Limer owns the model, the files and
the generator (`scripts/app/core/design_model.lua`), whose checks run as a
Limekit project: `python -m limekit tests`.

## Regenerating the API index

`scripts/data/api_index.lua` is generated from Limekit's registry — the same
source its LSP stubs and manifest come from. The generator lives in the
Limekit repository, not this one: Limer ships no Python, and nothing inside
it should suggest otherwise. Re-run it from there whenever Limekit gains or
loses API:

```
python tools/generate_api_index.py [path-to-Limer]      # write it
python tools/generate_api_index.py --check              # fail if stale
```

It finds Limer from the argument, then `$LIMER_REPO`, then a sibling
checkout.
