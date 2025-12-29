--[[
                             _     _                               _               ___ ____  _____
                            | |   (_)_ __ ___   ___ _ __          | |_   _  __ _  |_ _|  _ \| ____|
                            | |   | | '_ ` _ \ / _ \ '__|  _____  | | | | |/ _` |  | || | | |  _|
                            | |___| | | | | | |  __/ |    |_____| | | |_| | (_| |  | || |_| | |___
                            |_____|_|_| |_| |_|\___|_|            |_|\__,_|\__,_| |___|____/|_____|


            Copyright: Rézolu
            Chief Developer: Omega Msiska (github.com/mitosisx)

        This source code is provided unobfuscated and written in simple Lua syntax
        in the hope that it is useful for educational purposes.

        Architecture:
        - All global state is managed through the App singleton (app/core/app.lua)
        - Modules follow a consistent factory pattern with Module.create() returning instances
        - Dependencies are passed explicitly rather than through globals
        - UI components use colon notation for widget API calls
        - Module functions use dot notation for static methods
]] --

local MainWindow = require "gui.views.main_window"

local window = MainWindow.create()
window:show()
