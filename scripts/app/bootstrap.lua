local paths = require("config.paths")
local styles = require("styles.loader")
local file = require("core.file")
local log = require("core.log")

local APP_FONT_SIZE = 9.9

-- Ensure Limekit project folders exist
if not app.exists(paths.projects_root) then
    app.createFolder(paths.projects_root)
end

app.setFontSize(APP_FONT_SIZE)
styles.load()

return true
