# =============================================================================
# config.R — Configuración global del proyecto
# =============================================================================
# FUENTE DE VERDAD ÚNICA: todos los scripts cargan este fichero vía source()
# No editar rutas ni parámetros en los scripts individuales.
# =============================================================================

# --- Reproducibilidad --------------------------------------------------------
SEED  <- 42L
RUNS  <- 999L
ITER  <- 1000L
YEARS <- c(1995L, 2024L)

# --- Estética ----------------------------------------------------------------
PALETTE     <- c("1995" = "#AEC6CF", "2024" = "#F08080")
FONT_FAMILY <- "Lexend"

# --- Rutas -------------------------------------------------------------------
# here::here() busca el directorio raíz del proyecto (donde esté .here o .git)
DATA_DIR  <- here::here("data")
OUT_DIR   <- here::here("output")
CACHE_DIR <- here::here("output", "cache")
PLOT_DIR  <- here::here("output", "plots")
TABLE_DIR <- here::here("output", "tables")

# Crear directorios si no existen (seguro en CI/CD)
for (.d in c(CACHE_DIR, PLOT_DIR, TABLE_DIR)) {
  if (!dir.exists(.d)) dir.create(.d, recursive = TRUE, showWarnings = FALSE)
}
rm(.d)

# --- Archivos de datos -------------------------------------------------------
PATH_ARANAS  <- file.path(DATA_DIR, "arañas.xlsx")
PATH_TRAITS  <- file.path(DATA_DIR, "matrizTraits.xlsx")
PATH_ZONAS   <- file.path(DATA_DIR, "zonas.xlsx")
PATH_RAXML   <- file.path(DATA_DIR, "RAxML_bestTree.result")
PATH_FTREE   <- file.path(DATA_DIR, "arbolbueno.nexus")
PATH_PTREE   <- file.path(DATA_DIR, "arbol_podado.nex")

# --- Columnas a eliminar de arañas.xlsx (constante compartida) ---------------
COLS_DROP <- c("Cod_DZUL", "Ordenar", "X", "Y", "Camp", "Localidad",
               "Código_95", "Fecha", "Trampa", "Código_muestra",
               "Orden", "Familia", "Género", "Especie",
               "Determinador", "Observaciones")
