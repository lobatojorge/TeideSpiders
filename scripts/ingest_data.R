# =============================================================================
# scripts/ingest_data.R — Ingesta única: .xlsx → .parquet (Snappy)
# =============================================================================
# FLUJO INMUTABLE: los archivos en data/raw/ son de solo lectura.
# Este script se ejecuta solo cuando los crudos cambian.
# En CI/CD, la caché de output/cache/ invalida esta ejecución automáticamente
# si el hash de data/raw/ cambia (ver render-report.yml).
#
# ANTI-PATRÓN ELIMINADO: setup.R con rutas absolutas de máquina (F:/TFM/...).
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(readxl)
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(arrow)
})

source(here("config.R"))
source(here("R/data_prep.R"))

# Verificar que los crudos existen
required_raw <- c(PATH_ARANAS_RAW, PATH_TRAITS_RAW, PATH_ZONAS_RAW)
missing_raw  <- required_raw[!file.exists(required_raw)]
if (length(missing_raw) > 0) {
  stop(
    "Archivos crudos no encontrados en data/raw/:\n  ",
    paste(basename(missing_raw), collapse = "\n  "),
    "\nCopiar manualmente a data/raw/ (ver README)."
  )
}

# ── 1. arañas.xlsx → aranas.parquet ─────────────────────────────────────────
cat("[ingest] arañas.xlsx → aranas.parquet\n")

aranas <- load_aranas(path = PATH_ARANAS_RAW)
arrow::write_parquet(aranas, PATH_ARANAS_PARQUET, compression = "snappy")
cat(sprintf("  ✓ %d filas × %d columnas | %.1f KB\n",
            nrow(aranas), ncol(aranas),
            file.size(PATH_ARANAS_PARQUET) / 1024))

# ── 2. matrizTraits.xlsx → traits.parquet ───────────────────────────────────
cat("[ingest] matrizTraits.xlsx → traits.parquet\n")

traits_df <- openxlsx::read.xlsx(PATH_TRAITS_RAW, sheet = 1, rowNames = TRUE) |>
  tibble::rownames_to_column("species")

arrow::write_parquet(traits_df, PATH_TRAITS_PARQUET, compression = "snappy")
cat(sprintf("  ✓ %d especies × %d rasgos | %.1f KB\n",
            nrow(traits_df), ncol(traits_df) - 1L,
            file.size(PATH_TRAITS_PARQUET) / 1024))

# ── 3. zonas.xlsx → zonas.parquet ───────────────────────────────────────────
cat("[ingest] zonas.xlsx → zonas.parquet\n")

zonas_df <- readxl::read_excel(PATH_ZONAS_RAW)
arrow::write_parquet(zonas_df, PATH_ZONAS_PARQUET, compression = "snappy")
cat(sprintf("  ✓ %d registros | %.1f KB\n",
            nrow(zonas_df),
            file.size(PATH_ZONAS_PARQUET) / 1024))

cat("\n[ingest] Completado. Archivos en data/processed/\n")
cat("Siguiente paso: ejecutar los scripts de analysis/ y scripts/prepare_app_data.R\n")
