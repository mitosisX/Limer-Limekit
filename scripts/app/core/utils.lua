local Utils = {}

function Utils.printTable(t, indent)
    indent = indent or 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(string.rep(" ", indent) .. k .. ":")
            printTable(v, indent + 2)
        else
            print(string.rep(" ", indent) .. k .. ": " .. tostring(v))
        end
    end
end

return Utils
