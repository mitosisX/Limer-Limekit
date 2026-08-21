-- Console Module
-- Provides logging functionality for the application.
--
-- The console has two parts: a scrolling log, and one status line above it
-- saying what is happening right now. The log alone could only report what
-- had already happened -- a project that started and then ran looked exactly
-- like one that had died on its first line, because nothing appeared between
-- "Starting project..." and "Project stopped".
--
-- Deliberately one status label, not several. Limer sits close to a Lua
-- bridge fault where arguments are lost across the boundary, and an earlier
-- version of this file with three labels took its boot success rate from
-- reliable to three times in ten. Keep the widget count here low.

local ui = require("limekit.ui")

local Console = {}

local COLOURS = {
    idle    = "#7a7a7a",
    running = "#2d7d46",
    error   = "#c0392b",
    warn    = "#b8860b",
    stream  = "#1f6feb",
    quiet   = "#8a8a8a",
}

local MAX_REPEATS_HIDDEN = 200

local function escape(text)
    -- The log renders HTML, so output from a child process is neutralised
    -- before it goes in: it is untrusted input like any other.
    return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Lua's own traceback, and the indented frames under it, are context rather
-- than the message. They are worth keeping and not worth reading first.
local function isDetail(line)
    return line:match("^%s") ~= nil
        or line:find("stack traceback:", 1, true) ~= nil
end

function Console.create()
    local self = {
        view = ui.Container(),
        logConsole = ui.TextField(),
        statusLine = ui.Label(),
    }

    local lastKey, repeats = nil, 0

    local function initUI()
        self.logConsole:setReadOnly(true)
        self.statusLine:setBold(true)

        local consoleLayout = ui.VLayout()
        consoleLayout:setSpacing(4)
        consoleLayout:addChild(self.statusLine)
        consoleLayout:addChild(self.logConsole, 1)

        self.view:setLayout(consoleLayout)
    end

    local function raw(html)
        self.logConsole:appendText(html)
        self.logConsole:scrollToEnd()
    end

    -- A handler that fails on every click produced one identical block per
    -- click, and the console became a wall of the same four lines. Counting
    -- them says the same thing in one.
    local function flushRepeats()
        if repeats > 0 then
            raw("<span style='color:" .. COLOURS.quiet .. ";'>   (repeated " ..
                (repeats + 1) .. " times)</span>")
        end
        lastKey, repeats = nil, 0
    end

    local function emit(colour, prefix, chunk)
        local text = tostring(chunk):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return end          -- never a bare prompt on its own

        if text == lastKey then
            -- Bounded, so a handler failing in a tight loop cannot spin here
            -- forever without the count ever being shown.
            repeats = repeats + 1
            if repeats < MAX_REPEATS_HIDDEN then return end
            flushRepeats()
            return
        end

        flushRepeats()
        lastKey = text

        local first = true
        for line in (text .. "\n"):gmatch("(.-)\n") do
            if line ~= "" then
                if isDetail(line) then
                    raw("<span style='color:" .. COLOURS.quiet .. ";'>   " ..
                        escape(line:gsub("^%s+", "")) .. "</span>")
                else
                    raw((first and prefix or "   ") ..
                        "<span style='color:" .. colour .. ";'>" .. escape(line) .. "</span>")
                    first = false
                end
            end
        end
    end

    initUI()

    local api = {
        view = self.view,

        log = function(message)
            emit("inherit", ">> ", message)
        end,

        -- Output from the project itself, shown as it arrives rather than
        -- collected up and dumped when the process ends.
        logstream = function(message)
            emit(COLOURS.stream, "", message)
        end,

        error = function(message)
            emit(COLOURS.error, ">> ", message)
        end,

        warn = function(message)
            emit(COLOURS.warn, ">> ", message)
        end,

        rule = function(title)
            flushRepeats()
            raw("<span style='color:" .. COLOURS.quiet .. ";'>-- " .. escape(title) .. " " ..
                string.rep("-", math.max(0, 54 - #tostring(title))) .. "</span>")
        end,

        -- The live line. `kind` is one of idle, running, error, warn.
        status = function(kind, text, detail)
            self.statusLine:setTextColor(COLOURS[kind] or COLOURS.idle)
            self.statusLine:setText(
                (kind == "running" and "* " or "  ") ..
                tostring(text or "") ..
                (detail and detail ~= "" and ("    " .. detail) or ""))
        end,

        clear = function()
            lastKey, repeats = nil, 0
            self.logConsole:setText("")
        end,

        getView = function()
            return self.view
        end
    }

    api.status("idle", "Idle", "no project running")
    return api
end

return Console
