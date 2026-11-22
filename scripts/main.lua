-- UncivCNMacroWarMod (UncivCN 5.0.1.4)
-- Unified Macro-Economy & War Aversion Mod
-- Combines War Weariness (with O(1) combat hook and rebel spawning) and Rolling-Average World Inflation.
-- Engine contract: every hook receives a single argument `ctx`.

local T1 = 24
local T2 = 48
local T3 = 72
local T4 = 96
local DIVISOR = 6
local STEP_PCT = 2
local WAR_TURN_DELTA = 1
local PEACE_TURN_DELTA = -1
local UNIT_LOST_DELTA = 2
local ENEMY_KILLED_DELTA = -1
local CITY_CONQUERED_DELTA = -15

local WINDOW_SIZE = 5
local MIN_AVG_FLOOR = 10.0
local SENSITIVITY = 100.0
local DEFLATION_FLOOR = -50
local INFLATION_CEIL = 200
local NOTIFY_ENABLED = true

local function getTier(val)
    if val >= T4 then return 4 end
    if val >= T3 then return 3 end
    if val >= T2 then return 2 end
    if val >= T1 then return 1 end
    return 0
end

local function applyWarDelta(civ, delta)
    if civ == nil or not civ.isMajorCiv or delta == 0 then return end
    local prev = civ.getVariable("WarAversion")
    local prevTier = getTier(prev)
    civ.addVariable("WarAversion", delta)
    if NOTIFY_ENABLED then
        local curr = civ.getVariable("WarAversion")
        local currTier = getTier(curr)
        if currTier > prevTier then
            civ.addNotification("War Aversion reached Tier " .. tostring(currTier) .. " (" .. tostring(curr) .. "): penalties active.")
        elseif currTier < prevTier then
            civ.addNotification("War Aversion eased to Tier " .. tostring(currTier) .. " (" .. tostring(curr) .. ").")
        end
    end
end

local function clampInt(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return math.floor(val + 0.5)
end

local function updateMacroEconomy(game)
    local majorCivs = game.getAliveMajorCivs()
    local civCount = #majorCivs
    if civCount == 0 then return end

    local totalGold = 0.0
    for i = 1, civCount do
        local gpt = majorCivs[i].getGoldPerTurn()
        if gpt > 0 then totalGold = totalGold + gpt end
    end
    local currentWorldAvg = totalGold / civCount

    local idx = tonumber(ctx.store.get("buf_idx", "0")) or 0
    local count = tonumber(ctx.store.get("buf_count", "0")) or 0
    local sum = tonumber(ctx.store.get("buf_sum", "0")) or 0

    local slotKey = "buf_s" .. tostring(idx)
    local evicted = 0.0
    if count >= WINDOW_SIZE then
        evicted = tonumber(ctx.store.get(slotKey, "0")) or 0.0
    else
        count = count + 1
    end

    sum = sum - evicted + currentWorldAvg
    ctx.store.set(slotKey, tostring(currentWorldAvg))
    ctx.store.set("buf_idx", tostring((idx + 1) % WINDOW_SIZE))
    ctx.store.set("buf_count", tostring(count))
    ctx.store.set("buf_sum", tostring(sum))

    local rollingAvg = sum / count
    game.setGlobalVariable("WorldAvgGold", math.floor(rollingAvg + 0.5))

    local benchmark = math.max(MIN_AVG_FLOOR, rollingAvg)

    for i = 1, civCount do
        local targetCiv = majorCivs[i]
        local gpt = targetCiv.getGoldPerTurn()
        local deviation = (gpt - benchmark) / benchmark
        local nextIndex = clampInt(deviation * SENSITIVITY, DEFLATION_FLOOR, INFLATION_CEIL)
        targetCiv.setVariable("InflationIndex", nextIndex)
    end
end

-- Unified turn start handler: advances war aversion and runs macro economy once per turn
function onTurnStart(ctx)
    local civ = ctx.civ
    if not civ.isMajorCiv then return true end

    -- 1. War aversion update
    if ctx.evaluateConditional("when at war") then
        applyWarDelta(civ, WAR_TURN_DELTA)
    else
        applyWarDelta(civ, PEACE_TURN_DELTA)
    end

    -- 2. Macro economy update (once per game turn)
    local game = ctx.game
    local currentTurn = game.turn
    local lastTurn = tonumber(ctx.store.get("last_turn", "-1")) or -1
    if currentTurn > lastTurn then
        ctx.store.set("last_turn", tostring(currentTurn))
        updateMacroEconomy(game)
    end

    return true
end

function onUnitDefeated(ctx)
    local loser = ctx.civ
    local killer = ctx.otherCiv
    if loser ~= nil and loser.isMajorCiv then
        applyWarDelta(loser, UNIT_LOST_DELTA)
    end
    if killer ~= nil and killer.isMajorCiv and (loser == nil or killer.id ~= loser.id) then
        applyWarDelta(killer, ENEMY_KILLED_DELTA)
    end
    return true
end

function onCityConquered(ctx)
    local civ = ctx.civ
    if civ.isMajorCiv then
        applyWarDelta(civ, CITY_CONQUERED_DELTA)
    end
    return true
end

function modifyCombatStrength(ctx)
    local civ = ctx.civ
    if civ == nil or not civ.isMajorCiv then return nil end
    local wa = civ.getVariable("WarAversion")
    if wa < T4 then return nil end
    local penaltyFraction = (math.floor(wa / DIVISOR) * STEP_PCT) / 100.0
    local effectiveMod = math.max(0.25, ctx.modifier - penaltyFraction)
    return ctx.value * effectiveMod
end
