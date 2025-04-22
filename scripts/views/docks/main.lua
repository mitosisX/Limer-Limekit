-- require 'common/utils/main'

docksLay = VLayout()

toolboxDock = Dock("Toolbox")

toolboxDock:setMagneticAreas(nil)
toolboxDock:setProperties(nil)

scroller = Scroller()

scrollerLayout = VLayout()
scroller:setLayout(scrollerLayout)
scrollerLayout:setMargins(0, 0, 0, 0)

widgetsAccordion = Accordion() -- The Accordion for all widgets available
appAccordion = Accordion()     -- The Accordion for all app functions
pyAccordion = Accordion()      -- The Accordion for all python utility methods

-- scrollerLayout:addChild(widgetsAccordion)
-- scrollerLayout:addChild(appAccordion)
-- scrollerLayout:addChild(pyAccordion)

-- ######### Widgets listing
widgetsList = ListBox() -- Holds the the list for available widgets

allWidgetUtils = {
    Button = images('widgets/Button.png'),
    ButtonGroup = images('widgets/ButtonGroup.png'),
    CheckBox = images('widgets/CheckBox.png'),
    Accordion = images('widgets/Accordion.png'),
    ComboBox = images('widgets/ComboBox.png'),
    DoubleSpinner = images('widgets/Spinner.png'),
    GroupBox = images('widgets/GroupBox.png'),
    Chart = images('widgets/chart.png'),
    VerticalLine = images('widgets/line.png'),
    HorizontalLine = images('widgets/line.png'),
    Knob = images('widgets/Button.png'),
    Label = images('widgets/label.png'),
    LCDNumber = images('widgets/LCD.png'),
    LineEdit = images('widgets/Button.png'),
    ListBox = images('widgets/ListBox.png'),
    ProgressBar = images('widgets/ProgressBar.png'),
    RadioButton = images('widgets/RadioButton.png'),
    Scroller = images('widgets/Scroller.png'),
    Splitter = images('widgets/splitter.png'),
    Slider = images('widgets/Slider.png'),
    Spinner = images('widgets/Spinner.png'),
    Tab = images('widgets/Tab.png'),
    Table = images('widgets/Table.png'),
    TextField = images('widgets/TextField.png'),
    Window = images('widgets/window.png'),
    SlidingStackedWidget = images('widgets/StackedLayout.png'),
    StackedLayout = images('widgets/StackedLayout.png'),
    FormLayout = images('widgets/FormLayout.png'),
    GridLayout = images('widgets/gridlayout.png'),
    HLayout = images('widgets/HLayout.png'),
    VLayout = images('widgets/VLayout.png'),
    Modal = images('widgets/modal.png'),
    Calendar = images('widgets/Calendar.png'),
    DatePicker = images('widgets/DateTimePicker.png'),
    TimePicker = images('widgets/TimePicker.png'),
    Docker = images('widgets/menu.png'),
    Menu = images('widgets/Menu.png'),
    MenuBar = images('widgets/menubar.png')
}

widgetsList:addImageItems(allWidgetUtils)

-- ######### App utils listing
appUtilsList = ListBox() -- List for all app utils

allAppUtils = {
    'copyFile', 'isIDE', 'renameFolder', 'getFileExt', 'sortArray',
    'getStandardPath', 'sortTable', 'randomChoice', 'splitString', 'range',
    'joinTables', 'sleep', 'weightedGraph', 'getStyles', 'setStyle',
    'quickSort', 'makeHash', 'hexToRGB', 'readFileLines', 'toBase64',
    'fromBase64', 'emoji', 'extractZip', 'checkIfFolder', 'exists',
    'checkFileEmpty', 'checkDirEmpty', 'getFileSize', 'readFile', 'writeFile',
    'createFile', 'appendFile', 'readJSON', 'writeJSON', 'getFont', 'openFile',
    'colorPicker', 'textInput', 'multilineInput', 'comboBoxInput',
    'integerInput', 'doubleInput', 'alert', 'errorDialog', 'aboutAlert',
    'criticalAlert', 'infoAlert', 'warningAlert', 'getClipboardText',
    'setClipboarText', 'listFolder', 'createFolder', 'playSound',
    'getProcesses', 'killProcess', 'getCPUCount', 'getUsers', 'getBatteryInfo',
    'getDiskPartitions', 'getDiskInfo', 'getBootTime', 'getMachineType',
    'getNetworkNodeName', 'getProcessorName', 'getPlatformName',
    'getSystemRelease', 'getOSName', 'getOSRelease', 'getOSVersion' -- 'checkUniqueChars'
}

-- ######### App utils listing
pyUtilsList = ListBox() -- For all python utils

for x in ipairs(allAppUtils) do
    appUtilsList:addImageItem(allAppUtils[x], images('widgets/method.png'))
end

-- ######### Python utils listing

allPythonUtils = {
    'str_index', 'import_module', 'method_kwargs', 'getattr', 'getitem',
    'table_to_list', 'table_to_dict', 'str_format'
}

for x in ipairs(allPythonUtils) do
    pyUtilsList:addImageItem(allPythonUtils[x], images('py.png'))
end

widgetsDock = Dock("widgets")
widgetsDock:setMinWidth(300)
widgetsDock:setChild(widgetsList)

appUtilsDock = Dock("app utils")
appUtilsDock:setChild(appUtilsList)

pyUtilsDock = Dock("Python utils")
pyUtilsDock:setChild(pyUtilsList)

pyUtilsDock = Dock("Python utils")
pyUtilsDock:setChild(pyUtilsList)

userProjectsListDock = Dock('Your Projects')

items = {
    "Inbox (24 new)", "Today's meetings", "Pending approvals",
    "Project milestones", "Team updates", "Personal tasks", "Completed items"
}

userProjectsList = ListBox() -- Holds the list for available projects
userProjectsList:setOnItemDoubleClick(function(sender, folder, index)
    local appFolder = app.joinPaths(limekitProjectsFolder, folder)
    local appJSON = app.joinPaths(appFolder, 'app.json')
    finalizeProjectOpening(appJSON) -- Open the project
end)
-- userProjectsList:setItems(items)
userProjectsList:setStyle(currentTheme == 'light' and userProjectsLightStyle or
    userProjectsDarkStyle)
userProjectsList:setResizeRule('expanding', 'expanding')

-- userProjectsListDock:setChild(userProjectsList)
userProjectsListDock:setChild(userProjectsList)

appFolderDock = Dock("App directory")
appFolderDock:setMinWidth(300)

appProjectDirTree = TreeView()
appProjectDirTree:setHeaderHidden(true)
appProjectDirTree:setColumnWidth(0, 100)

appFolderDock:setChild(appProjectDirTree)
