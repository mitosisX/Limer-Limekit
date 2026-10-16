-- ImagesTab Module
-- The open project's images: folders to keep them in, files dropped in from
-- the desktop, and how each is referred to in code.
--
-- The same ui.ImageBrowser as the designer's Images panel, laid out side by
-- side for a full tab. Whatever changes here -- an image added, moved to
-- another folder, renamed -- rewrites scripts/designed/images.lua through
-- Images.refresh, so `images.logo` in the project's code keeps working
-- without anyone tracking where logo.png now lives.

local ui = require("limekit.ui")

local Images = require "app.core.images"

local ImagesTab = {}

function ImagesTab.create()
    local browser = ui.ImageBrowser()
    browser:setOrientation("horizontal")

    browser:setOnChange(function()
        local project = Images.project()
        if project then Images.refresh(project) end
    end)

    browser:setOnSelect(function(relPath)
        local key = relPath and Images.keyFor(relPath)
        if key then
            browser:setInfo("In code:   local images = require(\"designed.images\")   ...   "
                .. Images.reference(key))
        else
            browser:setInfo("Drop image files here or onto a folder. Make folders to keep them tidy; "
                .. "moving an image never breaks code that names it.")
        end
    end)

    -- Follows the open project: the first refresh for a new project points
    -- the browser at its images folder.
    local shown = nil
    Images.observe(function()
        local project = Images.project()
        if project and project ~= shown then
            shown = project
            browser:setRoot(Images.folder(project))
        end
    end)

    return { view = browser, browser = browser }
end

return ImagesTab
