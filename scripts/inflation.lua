-- UncivCNMacroWarMod :: Controlador de Inflación/Deflación Mundial (1x por turno global)
-- Invocado vía `Trigger the function [MacroEco_OnTurnStart] with []`.
-- Sin prefijo `modName:` para tolerar cualquier nombre de carpeta dentro de `mods/`.

local floor = math.floor
local max = math.max
local abs = math.abs
local tonumber = tonumber
local tostring = tostring

function MacroEco_OnTurnStart(ctx)
    if ctx == nil or ctx.game == nil or ctx.store == nil then
        return false
    end

    local store = ctx.store
    local game = ctx.game
    local currentTurn = game.turn
    local lastTurn = tonumber(store.get("last_turn", "-1")) or -1

    -- Salida temprana O(1) en turnos 2..N de la misma ronda (1 única lectura store.get)
    if currentTurn <= lastTurn then
        return true
    end
    store.set("last_turn", tostring(currentTurn))

    local majorCivs = game.getAliveMajorCivs()
    local civCount = #majorCivs
    if civCount == 0 then
        return true
    end

    local gpts = {}
    local totalGold = 0.0
    for i = 1, civCount do
        local gpt = majorCivs[i].getGoldPerTurn()
        gpts[i] = gpt
        if gpt > 0 then
            totalGold = totalGold + gpt
        end
    end

    -- Evitar contaminar la ventana en el turno 0 antes de fundar ciudades
    if totalGold <= 0 and not MacroEco_HasSamples(store) then
        game.setGlobalVariable("WorldAvgGold", 0)
        return true
    end

    local cfg = MACRO_ECO_CONFIG
    local currentWorldAvg = totalGold / civCount
    local rollingAvg = MacroEco_UpdateRollingAvg(store, currentWorldAvg, cfg.WINDOW_SIZE)
    local roundedAvg = floor(rollingAvg + 0.5)
    game.setGlobalVariable("WorldAvgGold", roundedAvg)

    local benchmark = max(cfg.MIN_AVG_FLOOR, rollingAvg)
    local notifyEnabled = cfg.NOTIFY_ENABLED
    local notifyThreshold = cfg.NOTIFY_DELTA_THRESHOLD
    local sensitivity = cfg.SENSITIVITY
    local defFloor = cfg.DEFLATION_FLOOR
    local infCeil = cfg.INFLATION_CEIL

    for i = 1, civCount do
        local targetCiv = majorCivs[i]
        local deviation = (gpts[i] - benchmark) / benchmark
        local nextIndex = MacroEco_ClampInt(deviation * sensitivity, defFloor, infCeil)

        if notifyEnabled and targetCiv.isHuman then
            local prevIndex = targetCiv.getVariable("InflationIndex")
            if nextIndex ~= prevIndex then
                targetCiv.setVariable("InflationIndex", nextIndex)
                if abs(nextIndex - prevIndex) >= notifyThreshold then
                    local label = nextIndex >= 0
                        and ("+" .. tostring(nextIndex) .. "% inflación")
                        or (tostring(nextIndex) .. "% deflación")
                    targetCiv.addNotification(
                        "Índice de Mercado: " .. label .. " (Media mundial: " .. tostring(roundedAvg) .. " GPT)"
                    )
                end
            end
        else
            targetCiv.setVariable("InflationIndex", nextIndex)
        end
    end

    return true
end
