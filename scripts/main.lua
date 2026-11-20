-- scripts/main.lua
-- Arquitectura hibrida UncivCN (JSON primero + Lua con ctx y ctx.store)
-- Sandbox estricto: sin io, os, package, require, luajava ni string.dump.
-- IMPORTANTE (Regla 11): Las llamadas ctx.store y ctx.log siguen la especificacion de UncivCN.
-- Verifica en tu repositorio local de UncivCN el metodo exacto de ctx.civ para consultar guerra
-- y sincronizar el recurso [Warfare Aversion Level] si tu compilacion usa un nombre de metodo distinto.

local RESOURCE_NAME = "Warfare Aversion Level"
local WAR_TURN_DELTA = 1
local UNIT_LOST_DELTA = 2
local CONQUEST_RELIEF = 10
local CONQUEST_MIN_THRESHOLD = 10
local BASE_PEACE_DECAY = 1

local function getCivKey(civ)
  return "war_aversion_" .. tostring(civ.civName or civ.name or "unknown")
end

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

local function updateAversion(ctx, civ, rawValue)
  local clamped = math.max(0, rawValue)
  -- Sin limite superior

  local key = getCivKey(civ)
  local prev = ctx.store[key] or 0
  if clamped == prev then return clamped end

  ctx.store[key] = clamped

  -- Sincronizacion propuesta con la estadistica/recurso del motor JSON:
  -- Verifica en tu API local de UncivCN si el metodo en civ es addResource / setStockpiledResource.
  local delta = clamped - prev
  if civ.addResource and delta ~= 0 then
    civ.addResource(RESOURCE_NAME, delta)
  end

  ctx.log("[" .. RESOURCE_NAME .. "] " .. key .. ": " .. tostring(prev) .. " -> " .. tostring(clamped))
  return clamped
end

-- Disparado desde GlobalUniques: Trigger the function [onTurnStart] <upon turn start>
function onTurnStart(ctx)
  local civ = ctx.civ
  if not civ then return false end

  local current = ctx.store[getCivKey(civ)] or 0
  local atWar = false
  if civ.isAtWar then
    atWar = civ.isAtWar()
  end

  if atWar then
    updateAversion(ctx, civ, current + WAR_TURN_DELTA)
  elseif current > 0 then
    local decay = computePeaceDecay(current)
    updateAversion(ctx, civ, current - decay)
  end

  return true
end

-- Disparado desde unitUniques: Trigger the function [onUnitDefeated] <upon being defeated>
function onUnitDefeated(ctx)
  local civ = ctx.civ
  if not civ and ctx.unit then
    civ = ctx.unit.civ
  end
  if not civ then return false end

  local current = ctx.store[getCivKey(civ)] or 0
  updateAversion(ctx, civ, current + UNIT_LOST_DELTA)
  return true
end

-- Disparado desde GlobalUniques: Trigger the function [onCityConquered] <upon conquering a city>
function onCityConquered(ctx)
  local civ = ctx.civ
  if not civ then return false end

  local current = ctx.store[getCivKey(civ)] or 0
  if current > CONQUEST_MIN_THRESHOLD then
    updateAversion(ctx, civ, current - CONQUEST_RELIEF)
  end

  return true
end
