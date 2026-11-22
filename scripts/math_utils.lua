-- UncivCNMacroWarMod :: Utilidades Matemáticas y Buffer Circular Empaquetado (1 clave)
-- Localiza funciones nativas de Lua para minimizar búsquedas globales e instrucciones por llamada.

local floor = math.floor
local tonumber = tonumber
local match = string.match
local gmatch = string.gmatch
local format = string.format
local concat = table.concat

function MacroEco_ClampInt(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return floor(val + 0.5)
end

function MacroEco_HasSamples(store)
    local packed = store.get("eco_buf", "")
    return packed ~= nil and packed ~= ""
end

-- Empaqueta idx;count;s1,s2,... en una única clave de ctx.store:
-- reduce de 5 cruces puente Kotlin<->Lua a solo 1 store.get + 1 store.set por ronda mundial y elimina deriva de redondeo.
function MacroEco_UpdateRollingAvg(store, currentWorldAvg, windowSize)
    local packed = store.get("eco_buf", "")
    local idx, count = 0, 0
    local samples = {}

    if packed ~= nil and packed ~= "" then
        local idxStr, cntStr, listStr = match(packed, "^(%d+);(%d+);(.*)$")
        if idxStr ~= nil then
            idx = tonumber(idxStr) or 0
            count = tonumber(cntStr) or 0
            local n = 0
            for v in gmatch(listStr, "([^,]+)") do
                n = n + 1
                samples[n] = tonumber(v) or 0.0
            end
        end
    end

    local slot = (idx % windowSize) + 1
    if count < windowSize then
        count = count + 1
    end
    samples[slot] = currentWorldAvg

    local sum = 0.0
    local parts = {}
    for i = 1, count do
        local val = samples[i] or 0.0
        sum = sum + val
        parts[i] = format("%.2f", val)
    end

    local nextIdx = (idx + 1) % windowSize
    store.set("eco_buf", format("%d;%d;%s", nextIdx, count, concat(parts, ",")))

    return sum / count
end
