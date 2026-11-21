-- scripts/aversion_belica.lua
-- Arquitectura Ultraoptimizada 100% compatible con UncivCN estándar (sin editar Kotlin):
--   1) Descomposición binaria O(log N) en 7 edificios ocultos (1..64):
--      elimina por completo los bucles repeat(N/4) de Unique.forEachMultiplied().
--   2) Dirty-Sync O(1): si floor(nivel/4) y el estado de rebeldía no cambian, retorna al instante
--      sin tocar getCapital(), sin addBuilding/removeBuilding ni reconstruir builtBuildingUniqueMap.
--   3) Retiro antes de inserción: reduce builtBuildingUniqueMap antes de ejecutar addBuilding().
--   4) Persistencia nativa en Civilization.variables (partidas guardadas y multijugador).

local VAR_INDICE = "AversionBelica_Indice"
local VAR_MASCARA_APLICADA = "AversionBelica_MascaraAplicada"

local DELTA_TURNO_GUERRA = 1
local DELTA_BAJA_PROPIA = 2
local DELTA_BAJA_ENEMIGA = -1
local ALIVIO_CONQUISTA_CIUDAD = 10
local RECUPERACION_BASE_PAZ = 1
local MAX_INDICE = 500

local MIN_UMBRAL_PENALIZACION = 10
local UMBRAL_REBELION = 70
local DIVISOR_ESCALADO = 4
local MAX_MULTIPLICADOR = 127
local BIT_REBEL = 128

local BIT_EDIFICIOS = { "AversionBelica_Bit_1", "AversionBelica_Bit_2", "AversionBelica_Bit_4", "AversionBelica_Bit_8", "AversionBelica_Bit_16", "AversionBelica_Bit_32", "AversionBelica_Bit_64" }
local NUM_BITS = #BIT_EDIFICIOS
local EDIFICIO_INSURGENCIA = "AversionBelica_Insurgencia"

local function sincronizarEfectosCapital(civ, nivel, forzarVerificacion)
  local objetivoP = (nivel > MIN_UMBRAL_PENALIZACION) and math.min(MAX_MULTIPLICADOR, math.floor(nivel / DIVISOR_ESCALADO)) or 0
  local objetivoRebel = (UMBRAL_REBELION ~= nil and nivel > UMBRAL_REBELION) and 1 or 0
  local objetivoMascara = objetivoP + objetivoRebel * BIT_REBEL
  local mascaraActual = civ.getVariable(VAR_MASCARA_APLICADA)

  if not forzarVerificacion and objetivoMascara == mascaraActual then
    return true
  end

  local capital = civ.getCapital()
  if not capital then
    if mascaraActual ~= 0 then
      civ.setVariable(VAR_MASCARA_APLICADA, 0)
    end
    return true
  end

  if forzarVerificacion then
    local rem = objetivoP
    local paraAnadir = {}
    local nAnadir = 0
    for i = 1, NUM_BITS do
      local bit = rem % 2
      local debe = bit == 1
      local edificio = BIT_EDIFICIOS[i]
      local tiene = capital.hasBuilding(edificio)
      if not debe and tiene then
        capital.removeBuilding(edificio)
      elseif debe and not tiene then
        nAnadir = nAnadir + 1
        paraAnadir[nAnadir] = edificio
      end
      rem = (rem - bit) * 0.5
    end
    for i = 1, nAnadir do
      capital.addBuilding(paraAnadir[i])
    end

    if UMBRAL_REBELION ~= nil then
      local debeRebel = objetivoRebel == 1
      local tieneRebel = capital.hasBuilding(EDIFICIO_INSURGENCIA)
      if not debeRebel and tieneRebel then
        capital.removeBuilding(EDIFICIO_INSURGENCIA)
      elseif debeRebel and not tieneRebel then
        capital.addBuilding(EDIFICIO_INSURGENCIA)
      end
    end
  else
    local oldP = mascaraActual % BIT_REBEL
    if oldP ~= objetivoP then
      local rOld = oldP
      local rNew = objetivoP
      local paraAnadir = {}
      local nAnadir = 0
      for i = 1, NUM_BITS do
        local bOld = rOld % 2
        local bNew = rNew % 2
        if bOld ~= bNew then
          if bOld == 1 then
            capital.removeBuilding(BIT_EDIFICIOS[i])
          else
            nAnadir = nAnadir + 1
            paraAnadir[nAnadir] = BIT_EDIFICIOS[i]
          end
        end
        rOld = (rOld - bOld) * 0.5
        rNew = (rNew - bNew) * 0.5
      end
      for i = 1, nAnadir do
        capital.addBuilding(paraAnadir[i])
      end
    end

    if UMBRAL_REBELION ~= nil then
      local estabaRebel = mascaraActual >= BIT_REBEL
      local debeRebel = objetivoRebel == 1
      if estabaRebel and not debeRebel then
        capital.removeBuilding(EDIFICIO_INSURGENCIA)
      elseif debeRebel and not estabaRebel then
        capital.addBuilding(EDIFICIO_INSURGENCIA)
      end
    end
  end

  if objetivoMascara ~= mascaraActual then
    civ.setVariable(VAR_MASCARA_APLICADA, objetivoMascara)
  end
  return true
end

local function aplicarDelta(civ, delta)
  local actual = civ.getVariable(VAR_INDICE)
  local nuevo = actual + delta
  if nuevo < 0 then nuevo = 0 end
  if MAX_INDICE and nuevo > MAX_INDICE then nuevo = MAX_INDICE end
  if nuevo == actual then
    return true
  end
  civ.setVariable(VAR_INDICE, nuevo)
  return sincronizarEfectosCapital(civ, nuevo, false)
end

function aversionBelica_sumarTurnoGuerra(ctx)
  if not ctx.civ then return false end
  return aplicarDelta(ctx.civ, DELTA_TURNO_GUERRA)
end

function aversionBelica_aliviarTurnoPaz(ctx)
  if not ctx.civ then return false end
  local actual = ctx.civ.getVariable(VAR_INDICE)
  local reduccion = RECUPERACION_BASE_PAZ
  local nuevo = actual - reduccion
  if nuevo < 0 then nuevo = 0 end
  if nuevo == actual then
    return true
  end
  ctx.civ.setVariable(VAR_INDICE, nuevo)
  return sincronizarEfectosCapital(ctx.civ, nuevo, false)
end

function aversionBelica_alPerderUnidad(ctx)
  if not ctx.civ then return false end
  return aplicarDelta(ctx.civ, DELTA_BAJA_PROPIA)
end

function aversionBelica_alMatarEnemigo(ctx)
  if not ctx.civ then return false end
  return aplicarDelta(ctx.civ, DELTA_BAJA_ENEMIGA)
end

function aversionBelica_alConquistarCiudad(ctx)
  if not ctx.civ then return false end
  return aplicarDelta(ctx.civ, -ALIVIO_CONQUISTA_CIUDAD)
end

function aversionBelica_resincronizarCapital(ctx)
  if not ctx.civ then return false end
  local actual = ctx.civ.getVariable(VAR_INDICE)
  return sincronizarEfectosCapital(ctx.civ, actual, true)
end
