-- The remote code execution tab
--
-- 		HOW CODE INJECTION WORKS (IN A NUTSHELL)
--
-- 	** The code injection feature is plain simple; just another glorified hot-reload.
--
-- Content from codeInjectionField TextField is written to ".limekit/_code.lua"
-- and with the engine watching the .limekit dir. Once the engine notices a file change,
-- it instantly reads from the file and deletes it, to keep the watch running.
-- The engine executes the lua script

local Paths = require "app.core.config.paths"
local AppState = require "app.core.app_state"

local CodeInjector = {}

function CodeInjector.create()
    local self = {
        view = Container()
    }

    function self:_initUI()
        self.codeInjectionLay = VLayout()

        self.codeInjHLay = HLayout()
        self.codeInjHLay:setContentAlignment('left')
        -- codeInjHLay:addStretch()

        self.runInjectionCodeButton = Button('Run')
        -- self.runInjectionCodeButton:setEnabled(false)
        self.runInjectionCodeButton:setOnClick(function()
            local injectionCodeContent = self.codeInjectionField:getText()

            if injectionCodeContent ~= "" then
                -- local result = app.executeCode(injectionCodeContent) -- execute the code in the field
                -- logConsole:appendText(result) -- append the result to the console log
                app.writeFile(Paths.codeInjectionFile, injectionCodeContent)
                self.codeInjectionField:clear()
            else
                app.criticalAlertDialog(limekitWindow, 'Error!',
                    "You'll need to write some code first...")
            end
        end)

        self.runInjectionCodeButton:setResizeRule('fixed', 'fixed')

        self.resetCodeInjectionFieldButton = Button('Clear')
        self.resetCodeInjectionFieldButton:setOnClick(function(sender)
            self.codeInjectionField:clear()
            -- print(projectIsRunning and 'Yes' or 'No')
        end)
        self.resetCodeInjectionFieldButton:setResizeRule('fixed', 'fixed')

        self.codeInjHLay:addChild(self.runInjectionCodeButton)
        self.codeInjHLay:addChild(self.resetCodeInjectionFieldButton)

        -- codeInjHLay:addStretch()

        self.codeInjectionLay:addLayout(self.codeInjHLay)

        self.codeInjectionField = TextField() -- Where injection code will be retrieved
        -- codeInjectionField:setOnKeyPress(function(sender, event)
        -- 	-- print(event)
        -- 	if KeyBoard.pressed(event, 'Ctrl+Shift+A') then
        -- 		print('Key binding')
        -- 	elseif KeyBoard.pressed(event, 'Key_F1') then
        -- 		print('F1 key presses')
        -- 	end
        -- end)
        self.codeInjectionField:setHint('Enter injection code here...')
        self.codeInjectionField:setToolTip(
            "Code entered here will be used to alter your running program")
        self.codeInjectionField:setOnTextChange(function(sender, text)
            if string.len(text) > 1 and AppState.projectIsRunning then
                self.runInjectionCodeButton:setEnabled(true)
            else
                self.runInjectionCodeButton:setEnabled(false)
            end
        end)
        self.codeInjectionLay:addChild(self.codeInjectionField)
        self.view:setLayout(self.codeInjectionLay)

        -- self.consoCodeTab:addTab(self.view, 'Code Injection')
    end

    self:_initUI()

    return {
        view = self.view
    }
end

return CodeInjector
-- remoteCodeExecutionItem = Container()
-- codeInjectionLay = VLayout()

-- codeInjHLay = HLayout()
-- codeInjHLay:setContentAlignment('left')
-- -- codeInjHLay:addStretch()

-- runInjectionCodeButton = Button('Run')
-- runInjectionCodeButton:setEnabled(false)
-- runInjectionCodeButton:setOnClick(function()
--     if not projectIsRunning then end

--     local injectionCodeContent = codeInjectionField:getText()

--     if injectionCodeContent ~= "" then
--         -- local result = app.executeCode(injectionCodeContent) -- execute the code in the field
--         -- logConsole:appendText(result) -- append the result to the console log
--         app.writeFile(codeInjectionFile, injectionCodeContent)
--         codeInjectionField:clear()
--     else
--         app.criticalAlertDialog(limekitWindow, 'Error!',
--             "You'll need to write some code first...")
--     end
-- end)
-- runInjectionCodeButton:setResizeRule('fixed', 'fixed')

-- resetCodeInjectionFieldButton = Button('Clear')
-- resetCodeInjectionFieldButton:setOnClick(function(sender)
--     codeInjectionField:clear()
--     print(projectIsRunning and 'Yes' or 'No')
-- end)
-- resetCodeInjectionFieldButton:setResizeRule('fixed', 'fixed')

-- codeInjHLay:addChild(runInjectionCodeButton)
-- codeInjHLay:addChild(resetCodeInjectionFieldButton)

-- -- codeInjHLay:addStretch()

-- codeInjectionLay:addLayout(codeInjHLay)

-- codeInjectionField = TextField() -- Where injection code will be retrieved
-- -- codeInjectionField:setOnKeyPress(function(sender, event)
-- -- 	-- print(event)
-- -- 	if KeyBoard.pressed(event, 'Ctrl+Shift+A') then
-- -- 		print('Key binding')
-- -- 	elseif KeyBoard.pressed(event, 'Key_F1') then
-- -- 		print('F1 key presses')
-- -- 	end
-- -- end)
-- codeInjectionField:setHint('Enter injection code here...')
-- codeInjectionField:setToolTip(
--     "Code entered here will be used to alter your running program")
-- codeInjectionField:setOnTextChange(function(sender, text)
--     if string.len(text) > 1 and projectIsRunning then
--         runInjectionCodeButton:setEnabled(true)
--     else
--         runInjectionCodeButton:setEnabled(false)
--     end
-- end)
-- codeInjectionLay:addChild(codeInjectionField)
-- remoteCodeExecutionItem:setLayout(codeInjectionLay)

-- consoCodeTab:addTab(remoteCodeExecutionItem, 'Code Injection')
