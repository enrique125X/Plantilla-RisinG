-- UncivCNMacroWarMod :: Configuración Macroeconómica (UncivCN 5.0.1.4)
-- La Aversión a la Guerra se ejecuta 100% en JSON nativo (sin sobrecarga Lua).
-- Este módulo contiene únicamente los parámetros del índice global de Inflación/Deflación.

MACRO_ECO_CONFIG = {
    WINDOW_SIZE = 5,
    MIN_AVG_FLOOR = 10.0,
    SENSITIVITY = 100.0,
    DEFLATION_FLOOR = -50,
    INFLATION_CEIL = 200,
    NOTIFY_ENABLED = true,
    NOTIFY_DELTA_THRESHOLD = 15
}
