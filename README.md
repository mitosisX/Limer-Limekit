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

Pick widgets from a palette, arrange them in rows and columns, edit their
properties, and write the result out as Lua.

The widgets on the canvas are real Limekit widgets running inside Limer —
not pictures of them and not a preview. What stops a designed button being
pressed when you mean to select it is `ui.DesignSurface`, which takes the
whole design out of the mouse's reach without changing how any of it draws.

**Generation is one way.** The design is the source of truth and it writes
`scripts/designed.lua`; it never touches your `main.lua` and never reads its
own output back. Edit the design, or edit the file — not both expecting them
to meet. This is the same bargain Qt Designer strikes with `.ui`, and for the
same reason: reconciling generated code with hand-edited code is what kills
these tools.

Layouts, not coordinates: a widget goes *into a row or a column*, at a
position, rather than at an x and a y. That is what makes a designed window
survive being resized.

### No widget palette in the dock

There is no widget palette down the side of the window. Limer had one for a long time and it caused more
confusion than it solved: a list of widget names down the left edge reads as
a drag-and-drop toolbox in every other IDE, and there is no canvas here to
drag onto. Ctrl+K makes no such promise.

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
