-- InspectorTab Module
-- Main container for the code injection and debugging features
-- Combines: Code Editor, Output Panel, Variable Explorer, Watch Expressions

local App = require "app.core.app"
local AppState = require "app.core.app_state"
local Paths = require "app.core.config.paths"

local CodeEditorPanel = require "gui.views.inspector.code_editor_panel"
local OutputPanel = require "gui.views.inspector.output_panel"
local VariableExplorer = require "gui.views.inspector.variable_explorer"
local WatchPanel = require "gui.views.inspector.watch_panel"

local InspectorTab = {}

function InspectorTab.create()
    local self = {
        view = Container(),
        mainLayout = HLayout(),
        leftLayout = VLayout(),
        rightLayout = VLayout(),

        -- Component instances
        codeEditor = nil,
        outputPanel = nil,
        variableExplorer = nil,
        watchPanel = nil,

        -- State
        executionStartTime = nil,
        isExecuting = false
    }

    -- Ensure inspector folder exists in .limekit
    local function ensureInspectorFolder()
        local inspectorFolder = app.joinPaths(Paths.codeInjectionFolder, 'inspector')
        if not app.exists(inspectorFolder) then
            app.createFolder(inspectorFolder)
        end
        return inspectorFolder
    end

    -- Execute code in the running application
    local function executeCode(code, scope, target)
        if not AppState.projectIsRunning then
            self.outputPanel.logError('No project is running')
            return
        end

        if not code or code == "" then
            self.outputPanel.logWarning('No code to execute')
            return
        end

        self.isExecuting = true
        self.executionStartTime = os.clock()
        self.codeEditor.setExecuting(true)
        self.outputPanel.logInfo('Executing...')

        -- Wrap code to capture return value and print output
        local wrappedCode = string.format([[
local __inspector_result = nil
local __inspector_error = nil
local __inspector_prints = {}

-- Override print temporarily
local __original_print = print
print = function(...)
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        str = str .. tostring(v)
        if i < #args then str = str .. "\t" end
    end
    table.insert(__inspector_prints, str)
    __original_print(...)
end

-- Execute the code
local __ok, __err = pcall(function()
    __inspector_result = (function()
        %s
    end)()
end)

-- Restore print
print = __original_print

if not __ok then
    __inspector_error = __err
end

-- Write results to inspector response file
local __response = {
    success = __ok,
    result = __inspector_result,
    error = __inspector_error,
    prints = __inspector_prints
}

local __json = require "json"
app.writeFile('%s', __json.stringify(__response))
]], code, app.joinPaths(ensureInspectorFolder(), '_response.json'):gsub("\\", "\\\\"))

        -- Write the wrapped code to the injection file
        app.writeFile(Paths.codeInjectionFile, wrappedCode)

        -- Poll for response (simple approach - could be improved with file watcher)
        local responseFile = app.joinPaths(ensureInspectorFolder(), '_response.json')
        local pollCount = 0
        local maxPolls = 50  -- 5 seconds max

        local function pollResponse()
            pollCount = pollCount + 1

            if app.exists(responseFile) then
                local responseContent = app.readFile(responseFile)
                app.deleteFile(responseFile)

                local json = require "json"
                local ok, response = pcall(function()
                    return json.parse(responseContent)
                end)

                local executionTime = (os.clock() - self.executionStartTime) * 1000
                self.codeEditor.setExecutionTime(executionTime)
                self.codeEditor.setExecuting(false)
                self.isExecuting = false

                if ok and response then
                    -- Log print statements
                    if response.prints then
                        for _, printLine in ipairs(response.prints) do
                            self.outputPanel.logPrint(printLine)
                        end
                    end

                    -- Log result or error
                    if response.success then
                        if response.result ~= nil then
                            self.outputPanel.logReturn(tostring(response.result))
                        end
                        self.outputPanel.logSuccess(string.format('Executed in %.2fms', executionTime))
                    else
                        self.outputPanel.logError(response.error or 'Unknown error')
                    end

                    -- Refresh variable explorer and watches
                    self.watchPanel.refreshAll()
                else
                    self.outputPanel.logError('Failed to parse response')
                end
            elseif pollCount < maxPolls then
                -- Continue polling
                Timer.singleShot(100, pollResponse)
            else
                -- Timeout
                self.codeEditor.setExecuting(false)
                self.isExecuting = false
                self.outputPanel.logError('Execution timeout - no response received')
            end
        end

        -- Start polling after a short delay
        Timer.singleShot(100, pollResponse)
    end

    -- Evaluate an expression (for watch expressions)
    local function evaluateExpression(expression, callback)
        if not AppState.projectIsRunning then
            callback(nil, 'No project running')
            return
        end

        local evalCode = string.format([[
local __json = require "json"
local __ok, __result = pcall(function()
    return %s
end)

local __response = {
    success = __ok,
    result = __ok and __result or nil,
    error = not __ok and __result or nil
}

app.writeFile('%s', __json.stringify(__response))
]], expression, app.joinPaths(ensureInspectorFolder(), '_eval_response.json'):gsub("\\", "\\\\"))

        app.writeFile(Paths.codeInjectionFile, evalCode)

        -- Poll for response
        local responseFile = app.joinPaths(ensureInspectorFolder(), '_eval_response.json')
        local pollCount = 0

        local function pollEvalResponse()
            pollCount = pollCount + 1

            if app.exists(responseFile) then
                local responseContent = app.readFile(responseFile)
                app.deleteFile(responseFile)

                local json = require "json"
                local ok, response = pcall(function()
                    return json.parse(responseContent)
                end)

                if ok and response then
                    if response.success then
                        callback(response.result, nil)
                    else
                        callback(nil, response.error)
                    end
                else
                    callback(nil, 'Failed to parse response')
                end
            elseif pollCount < 30 then
                Timer.singleShot(100, pollEvalResponse)
            else
                callback(nil, 'Evaluation timeout')
            end
        end

        Timer.singleShot(100, pollEvalResponse)
    end

    -- Refresh variable explorer
    local function refreshVariables()
        if not AppState.projectIsRunning then
            return
        end

        local refreshCode = [[
local __json = require "json"
local __variables = {}

-- Get global variables (excluding built-in ones)
local __builtins = {
    _G = true, _VERSION = true, assert = true, collectgarbage = true,
    dofile = true, error = true, getmetatable = true, ipairs = true,
    load = true, loadfile = true, next = true, pairs = true, pcall = true,
    print = true, rawequal = true, rawget = true, rawlen = true, rawset = true,
    require = true, select = true, setmetatable = true, tonumber = true,
    tostring = true, type = true, xpcall = true, coroutine = true,
    debug = true, io = true, math = true, os = true, package = true,
    string = true, table = true, utf8 = true
}

for k, v in pairs(_G) do
    if not __builtins[k] and not string.match(k, "^__") then
        local varType = type(v)
        local isWidget = varType == "userdata" or (varType == "table" and v.setEnabled ~= nil)

        __variables[k] = {
            type = varType,
            value = varType == "string" and v or tostring(v),
            isWidget = isWidget,
            isModule = varType == "table" and not isWidget
        }
    end
end

app.writeFile('%s', __json.stringify(__variables))
]]

        local responseFile = app.joinPaths(ensureInspectorFolder(), '_variables.json')
        local formattedCode = string.format(refreshCode, responseFile:gsub("\\", "\\\\"))

        app.writeFile(Paths.codeInjectionFile, formattedCode)

        -- Poll for response
        local pollCount = 0

        local function pollVariables()
            pollCount = pollCount + 1

            if app.exists(responseFile) then
                local content = app.readFile(responseFile)
                app.deleteFile(responseFile)

                local json = require "json"
                local ok, variables = pcall(function()
                    return json.parse(content)
                end)

                if ok and variables then
                    self.variableExplorer.setVariables(variables)
                end
            elseif pollCount < 30 then
                Timer.singleShot(100, pollVariables)
            end
        end

        Timer.singleShot(100, pollVariables)
    end

    -- Handle variable selection (insert into code editor)
    local function onVariableSelected(varPath)
        self.codeEditor.insertAtCursor(varPath)
    end

    -- Create left panel (code editor + output)
    local function createLeftPanel()
        local leftContainer = GroupBox()
        leftContainer:setTitle('Code Injection')
        DropShadow(leftContainer)

        local leftInnerLayout = VLayout()

        -- Code editor
        self.codeEditor = CodeEditorPanel.create({
            onExecute = executeCode,
            onClear = function()
                self.outputPanel.clear()
            end
        })

        -- Splitter for code editor and output
        local leftSplitter = Splitter('vertical')
        leftSplitter:addChild(self.codeEditor.view)

        -- Output panel
        self.outputPanel = OutputPanel.create()
        leftSplitter:addChild(self.outputPanel.view)

        leftSplitter:setSizes(lua_table({300, 150}))

        leftInnerLayout:addChild(leftSplitter)
        leftContainer:setLayout(leftInnerLayout)

        self.leftLayout:addChild(leftContainer)
    end

    -- Create right panel (variable explorer + watches)
    local function createRightPanel()
        local rightContainer = GroupBox()
        rightContainer:setTitle('Inspection')
        DropShadow(rightContainer)

        local rightInnerLayout = VLayout()

        -- Splitter for variable explorer and watches
        local rightSplitter = Splitter('vertical')

        -- Variable explorer
        self.variableExplorer = VariableExplorer.create({
            onVariableSelected = onVariableSelected,
            onRefresh = refreshVariables
        })
        rightSplitter:addChild(self.variableExplorer.view)

        -- Watch panel
        self.watchPanel = WatchPanel.create({
            onEvaluate = evaluateExpression
        })
        rightSplitter:addChild(self.watchPanel.view)

        rightSplitter:setSizes(lua_table({250, 200}))

        rightInnerLayout:addChild(rightSplitter)
        rightContainer:setLayout(rightInnerLayout)

        self.rightLayout:addChild(rightContainer)
    end

    -- Update UI based on project running state
    local function updateProjectState(running)
        self.codeEditor.setProjectRunning(running)
        self.variableExplorer.setProjectRunning(running)
        self.watchPanel.setProjectRunning(running)

        if running then
            self.outputPanel.logInfo('Project started - Inspector ready')
            -- Auto-refresh variables when project starts
            Timer.singleShot(500, refreshVariables)
        else
            self.outputPanel.logInfo('Project stopped')
        end
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        self.mainLayout:setMargins(10, 10, 10, 10)

        -- Main splitter for left/right panels
        local mainSplitter = Splitter('horizontal')

        -- Left side container
        local leftWidget = Container()
        leftWidget:setLayout(self.leftLayout)
        mainSplitter:addChild(leftWidget)

        -- Right side container
        local rightWidget = Container()
        rightWidget:setLayout(self.rightLayout)
        mainSplitter:addChild(rightWidget)

        mainSplitter:setSizes(lua_table({500, 350}))

        createLeftPanel()
        createRightPanel()

        self.mainLayout:addChild(mainSplitter)
    end

    initComponents()

    return {
        view = self.view,

        -- Called when project state changes
        onProjectStateChange = function(running)
            updateProjectState(running)
        end,

        -- Manual refresh
        refreshVariables = function()
            refreshVariables()
        end,

        -- Get output panel for external logging
        getOutputPanel = function()
            return self.outputPanel
        end,

        -- Execute code programmatically
        execute = function(code)
            executeCode(code, 'Global', nil)
        end,

        -- Add a watch expression
        addWatch = function(expression)
            self.watchPanel.addWatch(expression)
        end
    }
end

return InspectorTab
