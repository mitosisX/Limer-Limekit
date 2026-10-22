-- Inspector Module
-- The live link to the running project: its widget tree, its properties,
-- and Lua run inside it.
--
-- Code injection used to write to a file the engine never read, so nothing
-- ever happened. Even when 1.x did read it, an injected chunk could not see
-- anything the project had declared `local` -- which is everything, in a
-- normal main.lua -- so there was nothing to reach for either.
--
-- Limekit answers both now. sys.Inspector opens a socket the project
-- connects back on, and widgets are addressed by their position in the tree
-- rather than by a Lua name, which is what makes them reachable at all.

local sys = require("limekit.sys")

local App = require "app.core.app"
local AppState = require "app.core.app_state"

local Inspector = {
    channel = nil,
    view = nil,
    connected = false,
}

--- The channel, opened on first use. Returns the socket name to hand the
--- project, or nil if a socket could not be opened at all.
function Inspector.prepare()
    if not Inspector.channel then
        Inspector.channel = sys.Inspector()

        Inspector.channel:setOnConnect(function()
            Inspector.connected = true
            if Inspector.view then Inspector.view.onConnected() end
        end)

        Inspector.channel:setOnDisconnect(function()
            Inspector.connected = false
            if Inspector.view then Inspector.view.onDisconnected() end
        end)
    end

    local ok, name = pcall(function() return Inspector.channel:listen() end)
    if not ok then
        App.console.warn("Inspector unavailable: " .. tostring(name))
        return nil
    end
    return name
end

function Inspector.isConnected()
    return Inspector.connected and AppState.projectIsRunning
end

--- Asks the running project something. `handler` receives (ok, result).
function Inspector.ask(op, args, handler)
    if not Inspector.channel or not Inspector.isConnected() then
        if handler then handler(false, "nothing is running") end
        return false
    end
    return Inspector.channel:request(op, args, handler)
end

function Inspector.setView(view)
    Inspector.view = view
end

return Inspector
