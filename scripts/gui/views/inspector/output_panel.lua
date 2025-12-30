-- OutputPanel Module
-- Displays execution results, errors, and print output

local OutputPanel = {}

-- Output types for styling
OutputPanel.TYPE = {
    INFO = "info",
    SUCCESS = "success",
    ERROR = "error",
    WARNING = "warning",
    PRINT = "print",
    RETURN = "return"
}

function OutputPanel.create(options)
    options = options or {}

    local self = {
        view = Container(),
        mainLayout = VLayout(),
        headerLayout = HLayout(),
        outputField = TextField(),
        clearButton = Button(),
        copyButton = Button(),
        outputHistory = {},
        maxHistorySize = options.maxHistorySize or 100
    }

    local function getTimestamp()
        return os.date("%H:%M:%S")
    end

    local function formatOutput(text, outputType)
        local prefix = ""
        local color = ""

        if outputType == OutputPanel.TYPE.ERROR then
            prefix = "[ERROR]"
            color = "#FF6B6B"
        elseif outputType == OutputPanel.TYPE.SUCCESS then
            prefix = "[OK]"
            color = "#69DB7C"
        elseif outputType == OutputPanel.TYPE.WARNING then
            prefix = "[WARN]"
            color = "#FFD43B"
        elseif outputType == OutputPanel.TYPE.PRINT then
            prefix = ">"
            color = "#A9A9A9"
        elseif outputType == OutputPanel.TYPE.RETURN then
            prefix = "=>"
            color = "#74C0FC"
        else
            prefix = "[INFO]"
            color = "#868E96"
        end

        return string.format('<span style="color:%s">%s %s</span> %s',
            color, getTimestamp(), prefix, text)
    end

    local function createHeader()
        self.headerLayout:setContentAlignment('left', 'vcenter')
        self.headerLayout:setMargins(0, 0, 0, 3)

        local titleLabel = Label('<strong>Output</strong>')
        titleLabel:setResizeRule('expanding', 'fixed')

        -- Copy button
        self.copyButton:setText('')
        self.copyButton:setIcon(images('editor/copy.png'))
        self.copyButton:setToolTip('Copy output to clipboard')
        self.copyButton:setResizeRule('fixed', 'fixed')
        self.copyButton:setOnClick(function()
            local text = self.outputField:getText()
            if text and text ~= "" then
                app.setClipboardText(text)
            end
        end)

        -- Clear button
        self.clearButton:setText('')
        self.clearButton:setIcon(images('app/cross.png'))
        self.clearButton:setToolTip('Clear output')
        self.clearButton:setResizeRule('fixed', 'fixed')
        self.clearButton:setOnClick(function()
            self.outputField:clear()
            self.outputHistory = {}
        end)

        self.headerLayout:addChild(titleLabel)
        self.headerLayout:addChild(self.copyButton)
        self.headerLayout:addChild(self.clearButton)

        self.mainLayout:addLayout(self.headerLayout)
    end

    local function createOutputField()
        self.outputField:setReadOnly(true)
        self.outputField:setHint('Execution output will appear here...')
        self.outputField:setMinHeight(80)
        self.outputField:setVerticalScrollBarBehavior('overflow')
        self.outputField:setHorizontalScrollBarBehavior('hidden')
        self.outputField:setWrapMode('widget')

        self.mainLayout:addChild(self.outputField)
    end

    local function initComponents()
        self.view:setLayout(self.mainLayout)
        createHeader()
        createOutputField()
    end

    local function appendLine(formattedText)
        -- Add to history
        table.insert(self.outputHistory, formattedText)

        -- Trim history if too large
        while #self.outputHistory > self.maxHistorySize do
            table.remove(self.outputHistory, 1)
        end

        -- Update display
        self.outputField:setText(table.concat(self.outputHistory, "<br>"))
        self.outputField:scrollToEnd()
    end

    initComponents()

    return {
        view = self.view,

        log = function(text, outputType)
            outputType = outputType or OutputPanel.TYPE.INFO
            local formatted = formatOutput(tostring(text), outputType)
            appendLine(formatted)
        end,

        logInfo = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.INFO)
            appendLine(formatted)
        end,

        logSuccess = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.SUCCESS)
            appendLine(formatted)
        end,

        logError = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.ERROR)
            appendLine(formatted)
        end,

        logWarning = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.WARNING)
            appendLine(formatted)
        end,

        logPrint = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.PRINT)
            appendLine(formatted)
        end,

        logReturn = function(text)
            local formatted = formatOutput(tostring(text), OutputPanel.TYPE.RETURN)
            appendLine(formatted)
        end,

        clear = function()
            self.outputField:clear()
            self.outputHistory = {}
        end,

        getHistory = function()
            return self.outputHistory
        end,

        getText = function()
            return self.outputField:getText()
        end
    }
end

return OutputPanel
