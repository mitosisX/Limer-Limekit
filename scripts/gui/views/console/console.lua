-- Console Module
-- Provides logging functionality for the application.
--
-- The console has two parts: a scrolling log, and one status line above it
-- saying what is happening right now. The log alone could only report what
-- had already happened -- a project that started and then ran looked exactly
-- like one that had died on its first line, because nothing appeared between
-- "Starting project..." and "Project stopped".

local ui = require("limekit.ui")

local Console = {}

local COLOURS = {
    idle    = "#7a7a7a",
    running = "#2d7d46",
    error   = "#c0392b",
    warn    = "#b8860b",
}

local function escape(text)
    -- The log renders HTML, so output from a child process is neutralised
    -- before it goes in: it is untrusted input like any other. Line breaks
    -- have to be translated too, or a multi-line traceback arrives as one
    -- unreadable paragraph.
    local safe = tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub("\r\n", "\n")
        :gsub("\n", "<br>")
    return safe
end

function Console.create()
    local self = {
        view = ui.Container(),
        logConsole = ui.TextField(),
        statusLine = ui.Label(),
    }

    local function initUI()
        self.logConsole:setReadOnly(true)
        self.statusLine:setBold(true)

        local consoleLayout = ui.VLayout()
        consoleLayout:setSpacing(4)
        consoleLayout:addChild(self.statusLine)
        consoleLayout:addChild(self.logConsole, 1)

        self.view:setLayout(consoleLayout)
    end

    local function write(html)
        self.logConsole:appendText(html)
        self.logConsole:scrollToEnd()
    end

    initUI()

    local api = {
        view = self.view,

        log = function(message)
            write(">> " .. escape(message))
        end,

        -- Output from the project itself, shown as it arrives rather than
        -- collected up and dumped when the process ends.
        logstream = function(message)
            write("<span style='color:#1f6feb;'>" .. escape(message) .. "</span>")
        end,

        error = function(message)
            write(">> <span style='color:" .. COLOURS.error .. ";'>" .. escape(message) .. "</span>")
        end,

        warn = function(message)
            write(">> <span style='color:" .. COLOURS.warn .. ";'>" .. escape(message) .. "</span>")
        end,

        rule = function(title)
            write("<span style='color:" .. COLOURS.idle .. ";'>-- " .. escape(title) .. " " ..
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
