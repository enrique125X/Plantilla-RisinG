-- scripts/warfare_aversion.lua
-- Sistema completo de aversion a la guerra para UncivCN (100% Lua + variables, sin GlobalUniques).

local VAR_NAME = "Warfare Aversion Level"
local WAR_TURN_DELTA = 1
local UNIT_LOST_DELTA = 2
local CONQUEST_RELIEF = 10
local CONQUEST_MIN_THRESHOLD = 10
local BASE_PEACE_DECAY = 1

local TIERS = {
  { threshold = 10, gold = -1, unhappy = 0, prod = 0, faith = 0, culture = 0, science = 0, strength = 0, rebels = false },
  { threshold = 30, gold = 0, unhappy = 1, prod = 0, faith = 0, culture = 0, science = 0, strength = 0, rebels = false },
  { threshold = 50, gold = 0, unhappy = 0, prod = -1, faith = 0, culture = 0, science = 0, strength = 0, rebels = false },
  { threshold = 70, gold = 0, unhappy = 0, prod = 0, faith = -1, culture = 0, science = 0, strength = 0, rebels = true },
  { threshold = 100, gold = 0, unhappy = 0, prod = 0, faith = 0, culture = -1, science = -1, strength = -1, rebels = false }
}

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

local function applyDynamicPenalties(civ, aversion)
  local mult = math.floor(aversion / 3)
  local gold, unhappy, prod, faith, culture, science, strength = 0, 0, 0, 0, 0, 0, 0
  local canRebel = false

  for _, tier in ipairs(TIERS) do
    if aversion > tier.threshold then
      gold = gold + (tier.gold * mult)
      unhappy = unhappy + (tier.unhappy * mult)
      prod = prod + (tier.prod * mult)
      faith = faith + (tier.faith * mult)
      culture = culture + (tier.culture * mult)
      science = science + (tier.science * mult)
      strength = strength + (tier.strength * mult)
      if tier.rebels then canRebel = true end
    end
  end

  civ:setStatModifier("WarfareAversion", {
    GoldPercent = gold,
    PopulationUnhappinessPercent = unhappy,
    ProductionPercent = prod,
    FaithPercent = faith,
    CulturePercent = culture,
    SciencePercent = science,
    MilitaryStrengthPercent = strength,
    AllowRebelSpawn = canRebel
  })
end

local function setAversion(civ, rawNext)
  local nextVal = math.max(0, rawNext)
  -- Sin limite superior (escalado abierto)
  local prevVal = civ:getVariable(VAR_NAME) or 0
  if nextVal == prevVal then return end
  civ:setVariable(VAR_NAME, nextVal)
  applyDynamicPenalties(civ, nextVal)
end

-- 1. Acumulacion en guerra (+1) o decaimiento en paz al inicio de turno
ModEvents.on("onCivilizationTurnStart", function(event)
  local civ = event.civ
  if not civ or not civ:isMajorCiv() then return end

  local current = civ:getVariable(VAR_NAME) or 0
  if civ:isAtWar() then
    setAversion(civ, current + WAR_TURN_DELTA)
  elseif current > 0 then
    local decay = computePeaceDecay(current)
    setAversion(civ, current - decay)
  end
end)

-- 2. Bajas militares provocadas por el enemigo (+2)
ModEvents.on("onUnitDestroyed", function(event)
  local unit = event.unit
  local killer = event.attacker
  if not unit or not killer then return end

  local owner = unit:getOwner()
  if owner and owner:isMajorCiv() and killer:getOwner() ~= owner then
    local current = owner:getVariable(VAR_NAME) or 0
    setAversion(owner, current + UNIT_LOST_DELTA)
  end
end)

-- 3. Alivio de moral tras conquistar una ciudad enemiga (-10 si > 10)
ModEvents.on("onCityConquered", function(event)
  local conqueror = event.newOwner
  if not conqueror or not conqueror:isMajorCiv() then return end

  local current = conqueror:getVariable(VAR_NAME) or 0
  if current > CONQUEST_MIN_THRESHOLD then
    setAversion(conqueror, current - CONQUEST_RELIEF)
  end
end)
