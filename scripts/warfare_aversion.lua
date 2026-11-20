-- scripts/warfare_aversion.lua
-- Complemento ligero para capturar bajas militares en combate (+2)
-- El resto de acumuladores y umbrales permanecen en GlobalUniques.json

local VAR_NAME = "Warfare Aversion Level"
local UNIT_LOST_DELTA = 2

local function addAversion(civ, delta)
  if not civ or not civ:isMajorCiv() then return end
  local current = civ:getVariable(VAR_NAME) or 0
  local nextVal = math.max(0, current + delta)
  civ:setVariable(VAR_NAME, nextVal)
end

-- Hook de muerte de unidad en combate (evita dispararse al disolver o mejorar)
ModEvents.on("onUnitDestroyed", function(event)
  local unit = event.unit
  local killer = event.attacker
  if not unit or not killer then return end
  local owner = unit:getOwner()
  if owner and killer:getOwner() ~= owner then
    addAversion(owner, UNIT_LOST_DELTA)
  end
end)
