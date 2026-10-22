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
local Theme = require "app.core.theme"

local Console = {}

-- One set of colours per theme: the light set was picked against white and
-- reads poorly on the dark background, and the other way round. A plain
-- line has no colour of its own at all -- it takes the console's text
-- colour, which the theme sets. (It used to say `color:inherit`, which Qt's
-- rich text does not know, so it stored an explicit black: plain lines
-- were black on black in the dark theme.)
local PALETTES = {
    light = {
        idle    = "#6b7280",
        running = "#2d7d46",
        error   = "#c0392b",
        warn    = "#9a6c00",
        stream  = "#1f6feb",
        quiet   = "#7a7a7a",
    },
    dark = {
        idle    = "#9ca3af",
        running = "#4ade80",
        error   = "#f87171",
        warn    = "#fbbf24",
        stream  = "#60a5fa",
        quiet   = "#8b949e",
    },
}

local function colour(kind)
    local palette = PALETTES[Theme.active] or PALETTES.light
    return palette[kind] or palette.idle
end

local MAX_REPEATS_HIDDEN = 200

-- Lines kept to be drawn again in the other theme's colours. The log
-- itself holds more; past this, a theme switch keeps only the most recent.
local MAX_KEPT_LINES = 3000

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
    -- Every line as what it is -- { kind, prefix, text } -- rather than as
    -- the HTML it became, so it can be drawn again in other colours.
    local kept = {}
    local statusKind = "idle"

    local function initUI()
        self.logConsole:setReadOnly(true)
        self.statusLine:setBold(true)

        local consoleLayout = ui.VLayout()
        consoleLayout:setSpacing(4)
        consoleLayout:addChild(self.statusLine)
        consoleLayout:addChild(self.logConsole, 1)

        self.view:setLayout(consoleLayout)
    end

    -- A line as HTML. "plain" carries no colour, so the console's own
    -- text colour applies -- but it is still wrapped in a span: the console
    -- only reads appended text as HTML when it sees a tag, and without one
    -- the escaped ">>" showed as the literal "&gt;&gt;".
    local function html(line)
        local style = line.kind == "plain" and "" or (" style='color:" .. colour(line.kind) .. ";'")
        return escape(line.prefix) .. "<span" .. style .. ">" .. escape(line.text) .. "</span>"
    end

    local function write(kind, prefix, text)
        local line = { kind = kind, prefix = prefix, text = text }
        kept[#kept + 1] = line
        if #kept > MAX_KEPT_LINES then table.remove(kept, 1) end
        self.logConsole:appendText(html(line))
        self.logConsole:scrollToEnd()
    end

    -- A theme switch: every kept line again, in the new theme's colours.
    local function redraw()
        self.logConsole:setText("")
        for _, line in ipairs(kept) do self.logConsole:appendText(html(line)) end
        self.logConsole:scrollToEnd()
        self.statusLine:setTextColor(colour(statusKind))
    end

    -- A handler that fails on every click produced one identical block per
    -- click, and the console became a wall of the same four lines. Counting
    -- them says the same thing in one.
    local function flushRepeats()
        if repeats > 0 then
            write("quiet", "   ", "(repeated " .. (repeats + 1) .. " times)")
        end
        lastKey, repeats = nil, 0
    end

    local function emit(kind, prefix, chunk)
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
                    write("quiet", "   ", (line:gsub("^%s+", "")))
                else
                    write(kind, first and prefix or "   ", line)
                    first = false
                end
            end
        end
    end

    initUI()
    Theme.observe(redraw)

    local api = {
        view = self.view,

        log = function(message)
            emit("plain", ">> ", message)
        end,

        -- Output from the project itself, shown as it arrives rather than
        -- collected up and dumped when the process ends.
        logstream = function(message)
            emit("stream", "", message)
        end,

        error = function(message)
            emit("error", ">> ", message)
        end,

        warn = function(message)
            emit("warn", ">> ", message)
        end,

        rule = function(title)
            flushRepeats()
            write("quiet", "", "-- " .. tostring(title) .. " " ..
                string.rep("-", math.max(0, 54 - #tostring(title))))
        end,

        -- The live line. `kind` is one of idle, running, error, warn.
        status = function(kind, text, detail)
            statusKind = PALETTES.light[kind] and kind or "idle"
            self.statusLine:setTextColor(colour(statusKind))
            self.statusLine:setText(
                (kind == "running" and "* " or "  ") ..
                tostring(text or "") ..
                (detail and detail ~= "" and ("    " .. detail) or ""))
        end,

        clear = function()
            lastKey, repeats = nil, 0
            kept = {}
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
