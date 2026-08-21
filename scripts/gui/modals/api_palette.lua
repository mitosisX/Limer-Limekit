-- ApiPalette Module
-- Ctrl+K: search everything Limekit exposes to Lua, copy the call.
--
-- This replaces the three left-hand docks (widgets, app utils, python utils).
-- Those were hand-maintained lists of a moving API and had rotted badly --
-- six advertised widgets no longer existed, twenty-nine real ones were
-- missing, thirty-four "app utils" had been gone since 1.x, and the python
-- panel documented a surface 2.0 deliberately closes. The data behind this
-- palette is generated from the registry by tools/generate_api_index.py, so
-- it cannot drift.
--
-- It is a search box rather than a dock on purpose. A vertical list of
-- widget names pinned to the window edge reads as a toolbox in every other
-- IDE, and users kept trying to drag from it onto a canvas Limer does not
-- have. A palette makes no such promise.

local ui  = require("limekit.ui")
local sys = require("limekit.sys")

local INDEX = require "data.api_index"

-- Enough rows to scroll through without making every keystroke rebuild a
-- 2000-item list. The footer says when results were cut, so a capped search
-- never looks like an exhaustive one.
local MAX_RESULTS = 300

local ApiPalette = {}

-- The single live palette. Built on first use and reused, so the 2000-row
-- list is only ever assembled once.
local self = nil

local function shortName(qualified)
    return qualified:match("[.:]([^.:]+)$") or qualified
end

-- Lower is better. Prefix matches on the short name come first ("but" should
-- find Button before it finds ui.Table:setCellButtonWidget), then anything
-- else that matches the short name, then matches anywhere in the path.
local function score(entry, needle)
    local qualified = entry[1]:lower()
    local short = shortName(qualified)

    if short:sub(1, #needle) == needle then
        return entry[2] == "class" and 0 or 1
    end
    if short:find(needle, 1, true) then
        return entry[2] == "class" and 2 or 3
    end
    if qualified:find(needle, 1, true) then
        return 4
    end
    return nil
end

--- Ranked matches for `needle`, best first. Public so the ranking can be
--- exercised without standing a modal up.
function ApiPalette.find(needle)
    needle = needle:lower():gsub("^%s+", ""):gsub("%s+$", "")

    local matches = {}
    if needle == "" then
        for i = 1, #INDEX do
            if INDEX[i][2] == "class" then
                matches[#matches + 1] = { entry = INDEX[i], rank = 0, order = i }
            end
        end
    else
        for i = 1, #INDEX do
            local rank = score(INDEX[i], needle)
            if rank then
                matches[#matches + 1] = { entry = INDEX[i], rank = rank, order = i }
            end
        end
    end

    table.sort(matches, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)

    return matches
end


local function describe(entry)
    return string.format(
        "<strong>%s</strong> &mdash; <em>%s</em><br/>%s",
        entry[4], entry[2], entry[5]
    )
end

local function showResults(matches)
    local labels, shown = {}, math.min(#matches, MAX_RESULTS)

    for i = 1, shown do
        local entry = matches[i].entry
        labels[i] = entry[1]
    end

    self.visible = matches
    self.results:setItems(labels)

    if #matches == 0 then
        self.footer:setText("no match")
        self.detail:setText("")
    elseif shown < #matches then
        self.footer:setText(string.format(
            "showing %d of %d matches -- keep typing to narrow", shown, #matches))
    else
        self.footer:setText(string.format("%d of %d", #matches, #INDEX))
    end

    if shown > 0 then
        self.results:setCurrentRow(1)
        self.detail:setText(describe(matches[1].entry))
    end
end

local function selected()
    local row = self.results:getCurrentRow()
    if row == 0 or not self.visible[row] then return nil end
    return self.visible[row].entry
end

local function copySelected()
    local entry = selected()
    if not entry then return end

    sys.System.setClipboardText(entry[3])
    self.footer:setText(string.format("copied  %s", entry[3]))
end

local function build(parent)
    local instance = {
        modal   = ui.Modal("Limekit API", parent),
        layout  = ui.VLayout(),
        query   = ui.LineEdit(),
        results = ui.ListBox(),
        detail  = ui.Label(""),
        footer  = ui.Label(""),
        visible = {}
    }
    self = instance

    instance.modal:setMinWidth(720)
    instance.modal:setMinHeight(520)

    instance.query:setHint(string.format(
        "Search %d classes, methods, properties and events...", #INDEX))
    instance.query:setOnTextChange(function(_, text)
        showResults(ApiPalette.find(text))
    end)
    instance.query:setOnReturnPress(copySelected)

    instance.results:setOnItemSelect(function(_, _, row)
        local match = instance.visible[row]
        if match then instance.detail:setText(describe(match.entry)) end
    end)
    instance.results:setOnItemDoubleClick(copySelected)

    instance.detail:setWordWrap(true)
    instance.detail:setMinHeight(60)

    local buttons = ui.HLayout()
    buttons:addChild(instance.footer)
    buttons:addStretch()

    local copyButton = ui.Button("Copy")
    copyButton:setOnClick(copySelected)

    local closeButton = ui.Button("Close")
    closeButton:setOnClick(function() instance.modal:dismiss() end)

    buttons:addChild(copyButton)
    buttons:addChild(closeButton)

    instance.layout:addChild(instance.query)
    instance.layout:addChild(instance.results)
    instance.layout:addChild(instance.detail)
    instance.layout:addLayout(buttons)
    instance.modal:setLayout(instance.layout)

    return instance
end

--- The palette's widgets, built on first ask. Kept separate from `show` so
--- the panel can be prepared -- or inspected -- without entering the modal
--- loop, which does not return until the user closes it.
function ApiPalette.panel(parent)
    if not self then build(parent) end
    return self
end

--- Opens the palette. Blocks until it is dismissed, as every ui.Modal does.
function ApiPalette.show(parent)
    local panel = ApiPalette.panel(parent)

    panel.query:setText("")
    showResults(ApiPalette.find(""))
    panel.modal:open()
end

--- Closes the palette if it is open.
function ApiPalette.dismiss()
    if self then self.modal:dismiss() end
end

--- Whether the palette is on screen.
function ApiPalette.isOpen()
    return self ~= nil and self.modal:isVisible()
end

--- Wires Ctrl+K on `window`.
function ApiPalette.attach(window)
    local shortcut = ui.KeyboardShortcut(window, "Ctrl+K")
    shortcut:setOnKeyPress(function()
        ApiPalette.show(window)
    end)
    return shortcut
end

return ApiPalette
