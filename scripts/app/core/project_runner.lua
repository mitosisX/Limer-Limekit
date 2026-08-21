-- ProjectRunner Module
-- Handles project execution and process management.
--
-- The console used to say "Starting project..." and then nothing at all
-- until "Project stopped", so a running project was indistinguishable from
-- one that had died on the first line. It now reports three things it
-- always knew but never said: what it is about to run and on which engine,
-- that the project is still running and for how long, and how it ended --
-- finished on its own, stopped from here, or crashed.

local sys = require("limekit.sys")
local fs = require("limekit.fs")

local AppState = require "app.core.app_state"
local App = require "app.core.app"

local ProjectRunner = {
    process = nil,
    ui = nil,
    ticker = nil,
    startedAt = nil,
    projectName = nil,
}

function ProjectRunner.init(dependencies)
    ProjectRunner.ui = dependencies.ui
end

local function basename(path)
    -- Limekit already knows how to take a path apart, on either platform.
    -- normalPath first, so a trailing separator does not leave getFileName
    -- with nothing after it.
    local ok, name = pcall(function()
        return fs.FileSystem.getFileName(fs.FileSystem.normalPath(path))
    end)
    if ok and name and name ~= "" then return name end
    return tostring(path)
end

local function elapsed()
    if not ProjectRunner.startedAt then return "0s" end

    local seconds = os.time() - ProjectRunner.startedAt
    if seconds < 60 then return seconds .. "s" end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The heartbeat. Without it the status line would freeze at "running" and
-- tell you no more than the log already did.
local function startTicking(detail)
    ProjectRunner.startedAt = os.time()

    if not ProjectRunner.ticker then
        ProjectRunner.ticker = sys.Timer()
        ProjectRunner.ticker:setInterval(1000)
        ProjectRunner.ticker:setOnTimeout(function()
            App.console.status("running",
                "Running  " .. tostring(ProjectRunner.projectName),
                detail .. "   *   " .. elapsed())
        end)
    end

    ProjectRunner.ticker:start()
end

local function stopTicking()
    if ProjectRunner.ticker then ProjectRunner.ticker:stop() end
end

function ProjectRunner.run(projectPath)
    if AppState.projectIsRunning then
        App.console.error("Project is already running")
        return
    end

    if not projectPath or projectPath == "" then
        App.console.error("No project is open")
        return
    end

    -- A Limer that has been built into an executable has no interpreter left
    -- to start a project with, and asking anyway would silently open a
    -- second copy of Limer. Say so instead.
    if not sys.ProjectRunner.canSpawnProjects() then
        App.console.error("This build of Limer cannot run projects.")
        App.console.status("error", "Cannot run", "built launchers have no interpreter to start one with")
        return
    end

    App.console.clear()
    ProjectRunner.projectName = basename(projectPath)
    ProjectRunner.process = sys.ProjectRunner(projectPath)

    ProjectRunner.process:setOnProcessReadyRead(function(data)
        ProjectRunner._handleOutput(data)
    end)

    ProjectRunner.process:setOnProcessStarted(function()
        ProjectRunner._handleStart(projectPath)
        AppState.projectIsRunning = true

        if ProjectRunner.ui then
            ProjectRunner.ui.updateRunState()
        end
    end)

    ProjectRunner.process:setOnProcessFinished(function(exitCode, crashed)
        ProjectRunner._handleStop(exitCode, crashed)
        AppState.projectIsRunning = false
        ProjectRunner.process = nil

        if ProjectRunner.ui then
            ProjectRunner.ui.updateRunState()
        end
    end)

    -- Said before the process starts, so a project that fails to launch at
    -- all still leaves a record of what was attempted.
    App.console.rule("run")
    App.console.log("Launching " .. ProjectRunner.projectName)
    App.console.status("running", "Launching  " .. ProjectRunner.projectName, projectPath)

    ProjectRunner.process:run()
end

function ProjectRunner.stop()
    if AppState.projectIsRunning and ProjectRunner.process then
        App.console.log("Stopping " .. tostring(ProjectRunner.projectName) .. "...")
        App.console.status("warn", "Stopping  " .. tostring(ProjectRunner.projectName), "")
        ProjectRunner.process:stop()
    end
end

function ProjectRunner.toggle()
    if AppState.projectIsRunning then
        ProjectRunner.stop()
    else
        ProjectRunner.run(AppState.activeProjectPath)
    end
end

function ProjectRunner._handleStart(projectPath)
    local runner = ProjectRunner.process

    -- The engine is worth saying: both ship, and which one a project uses is
    -- decided from its own app.json, so it explains behaviour that would
    -- otherwise look arbitrary. The process id is worth saying because it is
    -- how you find a stuck app and end it.
    --
    -- The command is not. That a project runs by way of a Python interpreter
    -- is Limekit's business, not its author's -- and once Limer is built into
    -- an executable it will not be true in that form anyway. It stays
    -- available on sys.ProjectRunner:getCommand() for anything that wants a
    -- diagnostics view.
    local engine = runner:getApiVersion()
    local pid = runner:getProcessId()

    App.console.log("Running on the " .. engine .. " engine   (process " .. pid .. ")")
    App.console.rule("output")

    startTicking("engine " .. engine .. "   *   process " .. pid)

    -- Shown at once rather than a whole second later, which would look like
    -- nothing had happened.
    App.console.status("running", "Running  " .. ProjectRunner.projectName,
                       "engine " .. engine .. "   *   process " .. pid .. "   *   0s")
end

function ProjectRunner._handleOutput(data)
    local text = tostring(data)

    -- Plain find, not a pattern: a traceback full of brackets and dots is
    -- exactly the kind of text a pattern matches by accident.
    local looksWrong =
        text:find("Traceback", 1, true)
        or text:find("Error", 1, true)
        or text:find("error", 1, true)
        or text:find("Exception", 1, true)
        -- A Limekit error reads "scripts/main.lua:12: message", which
        -- contains none of the words above. This is the shape most worth
        -- catching, because it is the author's own mistake.
        or text:match("%.lua:%d+:") ~= nil

    if looksWrong then
        App.console.error(text)
    else
        App.console.logstream(text)
    end
end

function ProjectRunner._handleStop(exitCode, crashed)
    stopTicking()

    local took = elapsed()
    local name = tostring(ProjectRunner.projectName)

    -- Read this before dropping the process: pressing Stop kills the child,
    -- which leaves a non-zero exit code that means nothing to the user.
    local stopped = ProjectRunner.process and ProjectRunner.process:wasStopped()
    ProjectRunner.process = nil

    App.console.rule("end")

    if crashed then
        App.console.error(name .. " crashed after " .. took)
        App.console.status("error", "Crashed  " .. name, "ran for " .. took)
    elseif stopped then
        App.console.log(name .. " stopped after " .. took)
        App.console.status("idle", "Stopped  " .. name, "ran for " .. took)
    elseif exitCode == nil or exitCode == 0 then
        App.console.log(name .. " finished after " .. took)
        App.console.status("idle", "Finished  " .. name, "ran for " .. took)
    else
        App.console.warn(name .. " exited with code " .. exitCode .. " after " .. took)
        App.console.status("warn", "Exited  " .. name,
                           "code " .. exitCode .. "   *   ran for " .. took)
    end

    ProjectRunner.startedAt = nil
end

return ProjectRunner
