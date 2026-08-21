-- WelcomeView Module
-- What Limer shows when no project is open.
--
-- This used to be a splash screen reached by a toolbar button: a GIF, a
-- title, six cards saying things like "Free for everyone" and "Please report
-- bugs", and one Create button. Nobody navigates back to a brochure while
-- working, so it is no longer somewhere you go -- it is the state Limer is
-- in before there is anything to show. That changes what belongs on it: the
-- fastest route back into work, which is the list of your projects.
--
-- The cards are gone. What was useful in them -- reporting a bug, supporting
-- the project -- is now two links that actually open, which they never did.

local ui  = require("limekit.ui")
local res = require("limekit.res")
local sys = require("limekit.sys")

local WelcomeView = {}

local BUG_URL     = "https://github.com/mitosisx/Limekit/issues"
local SUPPORT_URL = "https://github.com/sponsors/mitosisx"

local projectsList = nil

local function openLink(url)
    return function()
        pcall(sys.System.openPath, url)
    end
end

local function linkRow()
    local row = ui.HLayout()
    row:setContentAlignment('hcenter')

    local bug = ui.CommandButton('Report a bug')
    bug:setResizeRule('fixed', 'fixed')
    bug:setOnClick(openLink(BUG_URL))

    local support = ui.CommandButton('Support this project')
    support:setResizeRule('fixed', 'fixed')
    support:setOnClick(openLink(SUPPORT_URL))

    row:addChild(bug)
    row:addChild(support)
    return row
end

local function heading()
    local layout = ui.VLayout()
    layout:setContentAlignment('hcenter')

    local gifPaths = { 'homepage/sheep.gif', 'homepage/cat.gif' }
    local welcomeGif = ui.GifPlayer(res.Resources.images(gifPaths[math.random(#gifPaths)]))
    welcomeGif:setSize(96, 96)

    local title = ui.Label('<strong>Limer</strong>')
    title:setTextSize(28)
    title:setTextAlignment('center')

    local subtitle = ui.Label('The magic wand for Limekit apps')
    subtitle:setTextSize(10)
    subtitle:setTextAlignment('center')

    layout:addChild(welcomeGif)
    layout:addChild(title)
    layout:addChild(subtitle)
    return layout
end

local function actionRow()
    local ProjectCreator = require "gui.modals.project_creator"
    local ProjectManager = require "app.core.project_manager"

    local row = ui.HLayout()
    row:setContentAlignment('hcenter')

    local create = ui.Button('Create a project')
    create:setIcon(res.Resources.images('toolbar/new_project.png'))
    create:setResizeRule('fixed', 'fixed')
    create:setOnClick(ProjectCreator.show)

    local open = ui.Button('Open a project')
    open:setIcon(res.Resources.images('toolbar/open_project.png'))
    open:setResizeRule('fixed', 'fixed')
    open:setOnClick(ProjectManager.openProject)

    row:addChild(create)
    row:addChild(open)
    return row
end

local function projectsSection()
    local fs = require("limekit.fs")
    local Paths = require "app.core.config.paths"

    local section = ui.VLayout()
    section:setContentAlignment('hcenter')

    local header = ui.Label('<strong>Your projects</strong>')
    header:setTextAlignment('center')

    projectsList = ui.ListBox()
    projectsList:setMinWidth(420)
    projectsList:setMaxWidth(560)
    projectsList:setMaxHeight(220)
    projectsList:setOnItemDoubleClick(function(_, folder)
        local ProjectManager = require "app.core.project_manager"
        local appJSON = fs.FileSystem.joinPaths(
            fs.FileSystem.joinPaths(Paths.limekitProjectsFolder, folder), 'app.json')
        ProjectManager.loadProject(appJSON)
    end)

    local hint = ui.Label('double-click to open')
    hint:setTextSize(9)
    hint:setTextAlignment('center')

    section:addChild(header)
    section:addChild(projectsList)
    section:addChild(hint)
    return section
end

local function footer()
    local label = ui.Label('Built with LOVE from Malawi (warm heart of Africa)')
    label:setBold(true)
    label:setTextColor('#2979FF')
    label:setTextSize(10)
    label:setTextAlignment({ 'hcenter', 'bottom' })
    return label
end

function WelcomeView.create()
    local layout = ui.VLayout()
    layout:setContentAlignment('hcenter')
    layout:setMargins(24, 24, 24, 24)

    layout:addStretch()
    layout:addLayout(heading())
    layout:addLayout(actionRow())
    layout:addLayout(projectsSection())
    layout:addStretch()
    layout:addLayout(linkRow())
    layout:addChild(footer())

    return layout
end

--- The project list on the empty state. ProjectManager fills this and the
--- dock from one place, so the two can never disagree.
function WelcomeView.getProjectsList()
    return projectsList
end

return WelcomeView
