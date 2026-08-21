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
- **Centre — the home page, and your project's Application and Properties
  tabs.** The toolbar's *Home Page* and *My Project* buttons switch between
  them.
- **Right — Your Projects.** Everything under your Limekit projects folder.
  Double-click to open.
- **Bottom — Console and Code Injection.**
- **Ctrl+K — the Limekit API.** Search all 2273 classes, methods,
  properties and events; Enter copies the call.

There is no widget palette. Limer had one for a long time and it caused more
confusion than it solved: a list of widget names down the left edge reads as
a drag-and-drop toolbox in every other IDE, and there is no canvas here to
drag onto. Ctrl+K makes no such promise.

## Regenerating the API index

`scripts/data/api_index.lua` is generated from Limekit's registry — the same
source its LSP stubs and manifest come from. Re-run the generator whenever
Limekit gains or loses API:

```
python tools/generate_api_index.py            # write it
python tools/generate_api_index.py --check    # fail if it is stale
```

It looks for Limekit in `$LIMEKIT_REPO`, falling back to a sibling checkout.
