# =============================================================================
# data/create_dummy_data.R — Genera datos sintéticos para CI/CD
# =============================================================================
# Crea archivos .parquet dummy estructurados de manera idéntica a los procesados
# para permitir que los flujos en GitHub Actions o shinyapps.io funcionen
# sin los datos crudos reales (que se omiten por peso y privacidad).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
  library(here)
})

source(here("config.R"))

set.seed(42)

if (!dir.exists(DUMMY_DIR)) {
  dir.create(DUMMY_DIR, recursive = TRUE)
}

# ── 1. arañas_dummy.parquet ──────────────────────────────────────────────────
# Simula la estructura limpia de aranas_parquet (columnas Código_localidad, Año, Taxon, N_exx., Muestreo)
localidades <- c("L1", "L2", "L3", "L4", "L5")
taxones <- c("Lycosa_tarentula", "Pardosa_proxima", "Xysticus_cristatus", 
             "Zodarion_italicum", "Linyphia_triangularis")
muestreos <- c("Trampa de caída", "Mangueo")

tax_dummy <- expand.grid(
  Código_localidad = localidades,
  Año = YEARS,
  Taxon = taxones,
  Muestreo = muestreos,
  stringsAsFactors = FALSE
) |>
  mutate(
    N_exx. = rpois(n(), lambda = 5)  # Abundancia simulada
  ) |>
  filter(N_exx. > 0) # Quitar ceros para simular presencia real

arrow::write_parquet(tax_dummy, PATH_ARANAS_DUMMY, compression = "snappy")
cat(sprintf("✓ Generado %s (%d filas)\n", basename(PATH_ARANAS_DUMMY), nrow(tax_dummy)))


# ── 2. traits_dummy.parquet ──────────────────────────────────────────────────
# Simula la estructura limpia de traits_parquet (columna species y traits)
traits_dummy <- data.frame(
  species = taxones,
  Body_Size = runif(length(taxones), 2, 15),
  Leg_Length = runif(length(taxones), 5, 30),
  Dispersal = sample(c("Ballooning", "Walking"), length(taxones), replace = TRUE),
  Hunting = sample(c("Web", "Active"), length(taxones), replace = TRUE),
  stringsAsFactors = FALSE
)

arrow::write_parquet(traits_dummy, PATH_TRAITS_DUMMY, compression = "snappy")
cat(sprintf("✓ Generado %s (%d filas)\n", basename(PATH_TRAITS_DUMMY), nrow(traits_dummy)))


# ── 3. zonas_dummy.parquet ───────────────────────────────────────────────────
# Simula el mapeo de localidades a zonas (W/E) y años
zonas_dummy <- expand.grid(
  localidad = localidades,
  año = as.character(YEARS),
  stringsAsFactors = FALSE
) |>
  mutate(
    zona = if_else(row_number() %% 2 == 0, "W", "E")
  ) |>
  rename(`Código_localidad` = localidad) # A menudo las zonas ligan por loc/año

arrow::write_parquet(zonas_dummy, PATH_ZONAS_DUMMY, compression = "snappy")
cat(sprintf("✓ Generado %s (%d filas)\n", basename(PATH_ZONAS_DUMMY), nrow(zonas_dummy)))

cat("\nTodos los datos sintéticos han sido generados en output/dummy_data/.\n")
