-- Preview
-- The Lua the design would generate, kept current after every change, so
-- what Generate writes is never a surprise.

local DesignModel = require "app.core.design_model"

local Preview = {}
Preview.__index = Preview

function Preview.new(field)
    field:setReadOnly(true)
    field:setWrapMode("none")
    pcall(field.setFont, field, "Consolas")
    return setmetatable({ field = field }, Preview)
end

function Preview:refresh(design, moduleName)
    self.field:setPlainText(DesignModel.generate(design, moduleName))
end

return Preview
