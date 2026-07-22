# =============================================================================
# scripts/prepare_app_data.R — Pre-computa objetos ligeros para la app Shiny
# =============================================================================
# EJECUTAR DESPUÉS de los scripts de análisis (analysis/01-03).
# Lee desde output/cache/ (SES, beta) y data/processed/ (parquet).
# Escribe app_*.rds en output/cache/ — consumidos por app/app.R en lectura.
#
# La app Shiny NO calcula modelos. Solo lee y visualiza.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tibble)
  library(vegan)
  library(arrow)
})

source(here("config.R"))
source(here("R/data_prep.R"))

# ── 0. Verificar dependencias de análisis ────────────────────────────────────
required_rds <- file.path(CACHE_DIR, c(
  "SES_PD.rds", "SES_MPD.rds", "SES_MNTD.rds",
  "SES_fPD.rds", "SES_fMPD.rds", "SES_fMNTD.rds",
  "beta_T.rds", "beta_f.rds", "beta_p.rds"
))
missing_rds <- required_rds[!file.exists(required_rds)]
if (length(missing_rds) > 0) {
  stop(
    "Faltan objetos de caché. Ejecutar primero:\n",
    "  Rscript analysis/01_taxo.R\n",
    "  Rscript analysis/02_fun.R\n",
    "  Rscript analysis/03_filo.R\n",
    "Faltantes: ", paste(basename(missing_rds), collapse = ", ")
  )
}

# ── 1. app_aranas.rds — datos de comunidad limpios ──────────────────────────
cat("[prepare] app_aranas.rds\n")

if (file.exists(PATH_ARANAS_PARQUET)) {
  aranas <- arrow::read_parquet(PATH_ARANAS_PARQUET)
} else {
  aranas <- load_aranas()
}

saveRDS(aranas, file.path(CACHE_DIR, "app_aranas.rds"))
cat(sprintf("  ✓ %d filas\n", nrow(aranas)))

# ── 2. app_nmds.rds — coordenadas NMDS pre-calculadas ───────────────────────
cat("[prepare] app_nmds.rds\n")

aranas_nmds <- aranas |>
  dplyr::mutate(localidad_año = paste(Código_localidad, Año, sep = "_"))

NMDSPresAu <- build_samp(aranas_nmds, id_col = "localidad_año")

set.seed(SEED)
nmds_result <- vegan::metaMDS(
  vegan::vegdist(NMDSPresAu, method = "jaccard", na.rm = TRUE),
  k = 2, trymax = 100
)

nmds_sites <- as.data.frame(vegan::scores(nmds_result, "sites")) |>
  tibble::rownames_to_column("localidad_año") |>
  dplyr::mutate(
    localidad = sub("_.*", "", localidad_año),
    año       = sub(".*_", "", localidad_año)
  )

hull <- nmds_sites |>
  dplyr::group_by(año) |>
  dplyr::slice(grDevices::chull(NMDS1, NMDS2))

app_nmds <- list(sites = nmds_sites, hull = hull, stress = nmds_result$stress)
saveRDS(app_nmds, file.path(CACHE_DIR, "app_nmds.rds"))
cat(sprintf("  ✓ Stress = %.4f\n", nmds_result$stress))

# ── 3. app_ses_phylo.rds — SES filogenéticos combinados ─────────────────────
cat("[prepare] app_ses_phylo.rds\n")

zonas <- arrow::read_parquet(PATH_ZONAS_PARQUET)

bind_ses <- function(rds_file, y_col) {
  ses <- readRDS(file.path(CACHE_DIR, rds_file))
  dplyr::bind_cols(ses[, y_col, drop = FALSE], zonas) |>
    dplyr::rename(valor = dplyr::all_of(y_col)) |>
    dplyr::mutate(
      año  = factor(año),
      zona = factor(zona, levels = c("W", "E")),
      metrica = y_col
    )
}

app_ses_phylo <- dplyr::bind_cols(
  readRDS(file.path(CACHE_DIR, "SES_PD.rds"))   |> dplyr::select(pd.obs.z),
  readRDS(file.path(CACHE_DIR, "SES_MPD.rds"))  |> dplyr::select(mpd.obs.z),
  readRDS(file.path(CACHE_DIR, "SES_MNTD.rds")) |> dplyr::select(mntd.obs.z),
  zonas
) |>
  dplyr::mutate(
    año  = factor(año),
    zona = factor(zona, levels = c("W", "E"))
  )

saveRDS(app_ses_phylo, file.path(CACHE_DIR, "app_ses_phylo.rds"))
cat(sprintf("  ✓ %d filas\n", nrow(app_ses_phylo)))

# ── 4. app_ses_fun.rds — SES funcionales combinados ─────────────────────────
cat("[prepare] app_ses_fun.rds\n")

app_ses_fun <- dplyr::bind_cols(
  readRDS(file.path(CACHE_DIR, "SES_fPD.rds"))   |> dplyr::select(pd.obs.z),
  readRDS(file.path(CACHE_DIR, "SES_fMPD.rds"))  |> dplyr::select(mpd.obs.z),
  readRDS(file.path(CACHE_DIR, "SES_fMNTD.rds")) |> dplyr::select(mntd.obs.z),
  zonas
) |>
  dplyr::mutate(
    año  = factor(año),
    zona = factor(zona, levels = c("W", "E"))
  )

saveRDS(app_ses_fun, file.path(CACHE_DIR, "app_ses_fun.rds"))
cat(sprintf("  ✓ %d filas\n", nrow(app_ses_fun)))

# ── 5. app_beta.rds — matrices de beta diversidad ───────────────────────────
cat("[prepare] app_beta.rds\n")

load_beta_mat <- function(prefix, component) {
  obj <- readRDS(file.path(CACHE_DIR, paste0("beta_", prefix, ".rds")))
  as.data.frame(as.matrix(obj[[component]]))
}

app_beta <- list(
  T = list(
    Btotal = load_beta_mat("T", "Btotal"),
    Brepl  = load_beta_mat("T", "Brepl"),
    Brich  = load_beta_mat("T", "Brich")
  ),
  p = list(
    Btotal = load_beta_mat("p", "Btotal"),
    Brepl  = load_beta_mat("p", "Brepl"),
    Brich  = load_beta_mat("p", "Brich")
  ),
  f = list(
    Btotal = load_beta_mat("f", "Btotal"),
    Brepl  = load_beta_mat("f", "Brepl"),
    Brich  = load_beta_mat("f", "Brich")
  )
)

saveRDS(app_beta, file.path(CACHE_DIR, "app_beta.rds"))
cat("  ✓ 3 dimensiones × 3 componentes\n")

cat("\n[prepare] Datos de app listos en output/cache/\n")
cat("Lanzar app: shiny::runApp('app')\n")
