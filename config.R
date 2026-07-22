# =============================================================================
# config.R — Configuración global del proyecto (v2 — inmutabilidad de datos)
# =============================================================================
# FUENTE DE VERDAD ÚNICA. Todos los scripts hacen source() de este fichero.
# REGLA: data/raw/ es solo-lectura; data/processed/ es derivado regenerable.
# =============================================================================

# --- Reproducibilidad --------------------------------------------------------
SEED  <- 42L
RUNS  <- 999L
ITER  <- 1000L
YEARS <- c(1995L, 2024L)

# --- Estética ----------------------------------------------------------------
PALETTE     <- c("1995" = "#AEC6CF", "2024" = "#F08080")
FONT_FAMILY <- "Lexend"

# --- Rutas base --------------------------------------------------------------
DATA_DIR  <- here::here("data")
OUT_DIR   <- here::here("output")
CACHE_DIR <- here::here("output", "cache")
PLOT_DIR  <- here::here("output", "plots")
TABLE_DIR <- here::here("output", "tables")

# --- Datos CRUDOS (inmutables — solo lectura) --------------------------------
RAW_DIR          <- file.path(DATA_DIR, "raw")
PATH_ARANAS_RAW  <- file.path(RAW_DIR, "arañas.xlsx")
PATH_TRAITS_RAW  <- file.path(RAW_DIR, "matrizTraits.xlsx")
PATH_ZONAS_RAW   <- file.path(RAW_DIR, "zonas.xlsx")
PATH_RAXML_RAW   <- file.path(RAW_DIR, "RAxML_bestTree.result")

# --- Datos PROCESADOS (derivados regenerables — .parquet Snappy) -------------
PROC_DIR             <- file.path(DATA_DIR, "processed")
PATH_ARANAS_PARQUET  <- file.path(PROC_DIR, "aranas.parquet")
PATH_TRAITS_PARQUET  <- file.path(PROC_DIR, "traits.parquet")
PATH_ZONAS_PARQUET   <- file.path(PROC_DIR, "zonas.parquet")

# --- Alias de compatibilidad hacia atrás (scripts de análisis existentes) ----
# Los scripts de análisis prefieren parquet si existe; si no, xlsx crudo.
PATH_ARANAS <- PATH_ARANAS_RAW
PATH_TRAITS <- PATH_TRAITS_RAW
PATH_ZONAS  <- PATH_ZONAS_RAW
PATH_RAXML  <- PATH_RAXML_RAW
PATH_FTREE  <- file.path(DATA_DIR, "arbolbueno.nexus")
PATH_PTREE  <- file.path(DATA_DIR, "arbol_podado.nex")

# --- Columnas a eliminar de arañas.xlsx (constante compartida) ---------------
COLS_DROP <- c("Cod_DZUL", "Ordenar", "X", "Y", "Camp", "Localidad",
               "Código_95", "Fecha", "Trampa", "Código_muestra",
               "Orden", "Familia", "Género", "Especie",
               "Determinador", "Observaciones")

# --- Crear directorios de salida si no existen (idempotente en CI/CD) --------
for (.d in c(CACHE_DIR, PLOT_DIR, TABLE_DIR, RAW_DIR, PROC_DIR)) {
  if (!dir.exists(.d)) dir.create(.d, recursive = TRUE, showWarnings = FALSE)
}
rm(.d)
