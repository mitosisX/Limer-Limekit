local f = {}
local function LYrf(qEi)
    if type(qEi) ~= 'table' then return type(qEi) end; local Sb = 1
    for IKyjk in
    pairs(qEi) do if qEi[Sb] ~= nil then Sb = Sb + 1 else return 'table' end end; if Sb == 1 then
        return 'table'
    else
        return
        'array'
    end
end
local function j(zMu)
    local Sf8IJ = { '\\', '"', '/', '\b', '\f', '\n', '\r', '\t' }
    local i18gNxu = { '\\', '"', '/', 'b', 'f', 'n', 'r', 't' }
    for ILt, T8L in ipairs(Sf8IJ) do
        zMu = zMu:gsub(T8L, '\\' .. i18gNxu[ILt])
    end; return zMu
end
local function vl1hvu5(kOq, dfSBRm, ZpNXL, nWp)
    dfSBRm = dfSBRm + #kOq:match('^%s*', dfSBRm)
    if kOq:sub(dfSBRm, dfSBRm) ~= ZpNXL then
        if nWp then
            error('Expected ' ..
                ZpNXL .. ' near position ' .. dfSBRm)
        end; return dfSBRm, false
    end; return dfSBRm + 1, true
end
local function l(BgC, xHALG, Der)
    Der = Der or ''
    local H = 'End of input found while parsing string.'
    if xHALG > #BgC then
        error(H)
    end; local xlET = BgC:sub(xHALG, xHALG)
    if xlET == '"' then
        return Der, xHALG + 1
    end
    if xlET ~= '\\' then return l(BgC, xHALG + 1, Der .. xlET) end; local cxy = {
        b = '\b',
        f = '\f',
        n = '\n',
        r = '\r',
        t =
        '\t'
    }
    local NDBo = BgC:sub(xHALG + 1, xHALG + 1)
    if not NDBo then error(H) end; return
        l(BgC, xHALG + 2, Der .. (cxy[NDBo] or NDBo))
end
local function Ddq8qf(OYNgcc9, Ct0zZW)
    local MYLol = OYNgcc9:match('^-?%d+%.?%d*[eE]?[+-]?%d*', Ct0zZW)
    local ihZiWUA = tonumber(MYLol)
    if not ihZiWUA then
        error('Error parsing number at position ' .. Ct0zZW .. '.')
    end; return ihZiWUA, Ct0zZW + #MYLol
end
function f.stringify(gGRN, Cr)
    local gJU = {}
    local M = LYrf(gGRN)
    if M == 'array' then
        if Cr then
            error('Can\'t encode array as key.')
        end; gJU[#gJU + 1] = '['
        for Kfp5G, VS in ipairs(gGRN) do
            if Kfp5G > 1 then
                gJU[#gJU + 1] = ', '
            end; gJU[#gJU + 1] = f.stringify(VS)
        end; gJU[#gJU + 1] = ']'
    elseif M == 'table' then
        if Cr then
            error('Can\'t encode table as key.')
        end; gJU[#gJU + 1] = '{'
        for jWe6D, Qd in pairs(gGRN) do
            if #gJU > 1 then
                gJU[#gJU + 1] = ', '
            end; gJU[#gJU + 1] = f.stringify(jWe6D, true)
            gJU[#gJU +
            1] = ':'
            gJU[#gJU + 1] = f.stringify(Qd)
        end; gJU[#gJU + 1] = '}'
    elseif M == 'string' then
        return '"' .. j(gGRN) .. '"'
    elseif
        M == 'number' then
        if Cr then return '"' .. tostring(gGRN) .. '"' end; return tostring(gGRN)
    elseif M == 'boolean' then
        return tostring(gGRN)
    elseif M == 'nil' then
        return 'null'
    else
        error(
            'Unjsonifiable type: ' .. M .. '.')
    end; return table.concat(gJU)
end; f.null = {}
function f.parse(o00, gZt, h9)
    gZt = gZt or 1; if gZt > #o00 then
        error('Reached unexpected end of input.')
    end
    local gZt = gZt + #o00:match('^%s*', gZt)
    local nIyq = o00:sub(gZt, gZt)
    if nIyq == '{' then
        local HFDOR, k7Djxyo, ievC = {}, true, true; gZt = gZt + 1
        while true do
            k7Djxyo, gZt = f.parse(o00, gZt, '}')
            if k7Djxyo == nil then return HFDOR, gZt end; if not ievC then
                error('Comma missing between object items.')
            end; gZt = vl1hvu5(o00, gZt, ':', true)
            HFDOR[k7Djxyo], gZt = f.parse(o00, gZt)
            gZt, ievC = vl1hvu5(o00, gZt, ',')
        end
    elseif nIyq == '[' then
        local oD3ZX, Fl7Pg, yNNCLe = {}, true, true; gZt = gZt + 1
        while true do
            Fl7Pg, gZt = f.parse(o00, gZt, ']')
            if Fl7Pg == nil then return oD3ZX, gZt end; if not yNNCLe then
                error('Comma missing between array items.')
            end; oD3ZX[#oD3ZX + 1] = Fl7Pg
            gZt, yNNCLe = vl1hvu5(o00, gZt, ',')
        end
    elseif nIyq == '"' then
        return l(o00, gZt + 1)
    elseif nIyq == '-' or nIyq:match('%d') then
        return
            Ddq8qf(o00, gZt)
    elseif nIyq == h9 then
        return nil, gZt + 1
    else
        local pwZE = { ['true'] = true, ['false'] = false, ['null'] = f.null }
        for sz0Xh, P74IIZ in pairs(pwZE) do
            local smYRpd = gZt + #sz0Xh - 1; if
                o00:sub(gZt, smYRpd) == sz0Xh then
                return P74IIZ, smYRpd + 1
            end
        end
        local N4EK = 'position ' .. gZt .. ': ' .. o00:sub(gZt, gZt + 10)
        error('Invalid json syntax starting at ' .. N4EK)
    end
end; return f
