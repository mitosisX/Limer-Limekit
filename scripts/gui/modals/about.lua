-- AboutPage Module
-- About Limer: a frameless modal that fades in, and fades out on a click,
-- Esc, Enter or Space.
--
-- The modal itself is the surface -- no card inside it, no rounded corners or
-- shadow of its own -- so it reads as one piece; on Windows 11 the system
-- rounds the window's corners. The surface is Naveto Tech's navy, the exact
-- colour behind the company's dark logo, so the logo sits on it with no box
-- around it, and it looks the same in Limer's light and dark themes alike.

local ui  = require("limekit.ui")
local fs  = require("limekit.fs")
local res = require("limekit.res")

local App = require "app.core.app"

local AboutPage = {}

-- Naveto Tech's palette, read off the logo.
local NAVY        = "#1B1B3A"   -- the surface; the dark logo's background
local NAVY_RULE   = "#2E2E5C"
local LIME        = "#DDFF55"   -- the logo's lime on navy
local TEXT_BRIGHT = "#FFFFFF"
local TEXT        = "#C9C9E3"
local TEXT_MUTED  = "#8E8EB8"

local WIDTH, HEIGHT = 480, 362

-- Limer's own app.json, for the version: never written down twice.
local function limerProject()
    local root = fs.FileSystem.getDirName(fs.FileSystem.getDirName(res.Resources.images("lime.png")))
    local ok, json = pcall(fs.FileSystem.readJSON, fs.FileSystem.joinPaths(root, "app.json"))
    if ok and type(json) == "table" then
        return json.project or {}, json.api
    end
    return {}, nil
end

local function line(text, size, color, extra)
    local label = ui.Label(text)
    label:setTextAlignment("center")
    label:setStyleSheet(("color: %s; font-size: %dpx; background: transparent; %s")
        :format(color, size, extra or ""))
    return label
end

local function image(name, width, height)
    local img = ui.Image(res.Resources.images(name))
    img:setImageSize(width, height)
    img:setImageAlignment("center")
    img:setStyleSheet("background: transparent;")
    return img
end

local function divider()
    local rule = ui.Label("")
    rule:setFixedSize(WIDTH * 0.6, 1)
    rule:setStyleSheet("background: " .. NAVY_RULE .. ";")
    local row = ui.HLayout()
    row:addStretch(1)
    row:addChild(rule)
    row:addStretch(1)
    return row
end

function AboutPage.show()
    local project, api = limerProject()
    local version = "Version " .. (project.version or "?")
    if api then
        version = version .. "  ·  Limekit " .. api
    end

    local modal = ui.Modal("About Limer", App.window)
    modal:setFrameless(true)
    modal:setFixedSize(WIDTH, HEIGHT)
    -- Scoped to the dialog: a bare declaration would cascade into every child.
    modal:setStyleSheet("QDialog { background: " .. NAVY .. "; }")

    local function dismiss() modal:fadeOut() end

    -- A frameless window has no title-bar X, so it brings its own.
    local close = ui.Button("✕")
    close:setFixedSize(28, 28)
    close:setToolTip("Close (Esc)")
    close:setStyleSheet(([[
        QPushButton {
            color: %s; background: transparent; border: none; outline: none;
            border-radius: 14px; font-size: 14px; padding: 0;
        }
        QPushButton:hover { color: %s; background: rgba(255, 255, 255, 0.10); }
        QPushButton:pressed { background: rgba(255, 255, 255, 0.16); }
    ]]):format(TEXT, TEXT_BRIGHT))
    close:setOnClick(dismiss)

    local outer = ui.VLayout()
    outer:setMargins(10, 10, 10, 26)
    outer:setSpacing(0)

    -- The X shares the icon's row rather than taking one of its own. A blank
    -- of the same width on the left keeps the icon centred; the X sits at
    -- the top of its column.
    local balance = ui.Label("")
    balance:setFixedSize(28, 28)
    balance:setStyleSheet("background: transparent;")
    -- A fixed gap, not a stretch: a stretch would make the whole row grow
    -- and take half the card's spare height.
    local closeColumn = ui.VLayout()
    closeColumn:addChild(close)
    closeColumn:addSpacing(52 - 28)
    local top = ui.HLayout()
    top:addChild(balance)
    top:addStretch(1)
    top:addChild(image("lime.png", 52, 52))
    top:addStretch(1)
    top:addLayout(closeColumn)
    outer:addLayout(top)

    local body = ui.VLayout()
    body:setMargins(22, 0, 22, 0)
    body:setSpacing(0)
    outer:addLayout(body)

    -- Limer
    body:addSpacing(10)
    body:addChild(line("Limer", 28, TEXT_BRIGHT, "font-weight: 700; letter-spacing: 0.5px;"))
    body:addSpacing(4)
    body:addChild(line(project.description or "", 14, TEXT))
    body:addSpacing(14)

    -- Qt draws square corners when the radius exceeds half the height, so
    -- the padding keeps the pill taller than twice its radius.
    local pill = line(version:upper(), 11, LIME, ([[
        font-weight: 600; letter-spacing: 1px;
        background: rgba(221, 255, 85, 0.10);
        border: 1px solid rgba(221, 255, 85, 0.28);
        border-radius: 10px; padding: 4px 14px;
    ]]))
    local pillRow = ui.HLayout()
    pillRow:addStretch(1)
    pillRow:addChild(pill)
    pillRow:addStretch(1)
    body:addLayout(pillRow)

    body:addStretch(1)
    body:addLayout(divider())
    body:addSpacing(18)

    -- Naveto Tech
    body:addChild(line("A PRODUCT OF", 10, TEXT_MUTED, "font-weight: 600; letter-spacing: 2px;"))
    body:addSpacing(10)
    body:addChild(image("about/naveto-tech.png", 178, 40))
    body:addSpacing(14)
    body:addChild(line("Created by Omega Msiska  ·  github.com/mitosisx", 12, TEXT))
    body:addSpacing(4)
    body:addChild(line("© " .. os.date("%Y") .. " Naveto Tech", 11, TEXT_MUTED))

    modal:setLayout(outer)

    -- So do a click anywhere, Esc, Enter and Space, all with the fade.
    modal:setOnMousePress(dismiss)
    for _, key in ipairs({ "Escape", "Return", "Enter", "Space" }) do
        ui.KeyboardShortcut(modal, key):setOnPress(dismiss)
    end

    modal:fadeIn()
end

return AboutPage
