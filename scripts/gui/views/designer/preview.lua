-- Preview
-- The Lua the design would generate, kept current after every change, so
-- what Generate writes is never a surprise.

local DesignModel = require "app.core.design_model"

local Preview = {}
Preview.__index = Preview

function Preview.new(field)
    field:setReadOnly(true)
    field:setWrapMode("none")
    -- TextField has no font setter; a stylesheet carrying only the font
    -- leaves the theme's colours alone. Each OS finds one of these.
    field:setStyleSheet("font-family: 'Cascadia Mono', Consolas, Menlo, 'DejaVu Sans Mono', monospace;")
    return setmetatable({ field = field }, Preview)
end

function Preview:refresh(design, moduleName)
    self.field:setPlainText(DesignModel.generate(design, moduleName))
end

return Preview
