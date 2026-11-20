-- scripts/main.lua
-- Verificado contra AutumnPizazz/Unciv (rama UncivCN):
--   - UniqueType.TriggerLuaFunction: "Trigger the function [luaFunction] with [comment]"
--   - LuaAPI.kt: ctx.civ, ctx.evaluateConditional("when at war"), civ.getVariable / setVariable / addVariable
--   - LuaAPI.kt: ctx.store.get(key, default) / ctx.store.set(key, value)

local VAR_NAME = "Warfare Aversion Level"
local WAR_TURN_DELTA = 1
local UNIT_LOST_DELTA = 2
local CONQUEST_RELIEF = 10
local CONQUEST_MIN_THRESHOLD = 10
local BASE_PEACE_DECAY = 1

local function computePeaceDecay(current)
  if current <= 0 then return 0 end
  local decay = BASE_PEACE_DECAY
  if current > 10 then decay = decay + 1 end
  if current > 30 then decay = decay + 1 end
  if current > 50 then decay = decay + 1 end
  if current > 70 then decay = decay + 1 end
  if current > 100 then decay = decay + 1 end
  return decay
end

-- Disparado desde GlobalUniques.uniques:
-- "Trigger the function [onTurnStart] with [] <upon turn start>"
function onTurnStart(ctx)
  local civ = ctx.civ
  if not civ or not civ.isMajorCiv then return true end

  local current = civ.getVariable(VAR_NAME)
  local atWar = ctx.evaluateConditional("when at war")

  if atWar then
    civ.addVariable(VAR_NAME, WAR_TURN_DELTA)
  elseif current > 0 then
    local decay = computePeaceDecay(current)
    civ.addVariable(VAR_NAME, -decay)
  end

  local updated = civ.getVariable(VAR_NAME)
  ctx.store.set("last_aversion_" .. tostring(civ.id), tostring(updated))
  return true
end

-- Disparado desde GlobalUniques.unitUniques (Battle.triggerDefeatUniques):
-- "Trigger the function [onUnitDefeated] with [] <upon being defeated>"
function onUnitDefeated(ctx)
  local civ = ctx.civ
  if not civ or not civ.isMajorCiv then return true end

  civ.addVariable(VAR_NAME, UNIT_LOST_DELTA)
  local updated = civ.getVariable(VAR_NAME)
  ctx.store.set("last_aversion_" .. tostring(civ.id), tostring(updated))
  ctx.log("[WarfareAversion] Unidad derrotada de " .. civ.name .. " -> " .. tostring(updated))
  return true
end

-- Disparado desde GlobalUniques.uniques (Battle.kt):
-- "Trigger the function [onCityConquered] with [] <upon conquering a city>"
function onCityConquered(ctx)
  local civ = ctx.civ
  if not civ or not civ.isMajorCiv then return true end

  local current = civ.getVariable(VAR_NAME)
  if current > CONQUEST_MIN_THRESHOLD then
    civ.addVariable(VAR_NAME, -CONQUEST_RELIEF)
    local updated = civ.getVariable(VAR_NAME)
    ctx.store.set("last_aversion_" .. tostring(civ.id), tostring(updated))
    ctx.log("[WarfareAversion] Conquista de " .. civ.name .. " -> " .. tostring(updated))
  end

  return true
end
