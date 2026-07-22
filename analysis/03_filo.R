# =============================================================================
# analysis/03_filo.R — Análisis de Diversidad Filogenética (REFACTORIZADO)
# =============================================================================
# Calcula PD, MPD, MNTD y beta diversidad filogenética sobre árbol RAxML
# con constraint de topología (Fernández et al. 2018).
#
# Bugs corregidos:
#   B9 (L70):  force.ultrametric(method=c(...)) → método único + is.ultrametric()
#   B10:       write.xlsx → openxlsx::write.xlsx (sin Java, sin conflictos).
#   setwd():   eliminado (3 llamadas → here::here()).
#   set.seed(): añadido antes de cada ses.*.
#   M7:        verificación explícita de ultramétrico y ramas >= 0.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(openxlsx)
  library(ape)
  library(phytools)
  library(picante)
  library(BAT)
  library(readxl)
  library(car)
  library(DHARMa)
  library(emmeans)
})

source(here("config.R"))
source(here("R/data_prep.R"))
source(here("R/model_utils.R"))
source(here("R/plot_utils.R"))

# =============================================================================
# 1. PREPARACIÓN DE DATOS
# =============================================================================

# --- Carga de comunidad de arañas (desde R/data_prep.R) ----------------------
# load_aranas() ya incluye drop_na() internamente.
aranas <- load_aranas()

# --- Carga de zonas (ingesta defensiva) --------------------------------------
zonas <- load_zonas()

# --- Carga del árbol filogenético (defensiva) --------------------------------
if (file.exists(PATH_RAXML)) {
  tree <- ape::read.tree(PATH_RAXML)
} else {
  warning("Árbol filogenético real no encontrado. Generando árbol aleatorio (DUMMY DATA).")
  tax_tips <- unique(aranas$Taxon)
  tree <- ape::rtree(n = length(tax_tips), tip.label = tax_tips)
}

# Limpiar nombres de taxones para coincidir con etiquetas del árbol filogenético
aranas_fp <- aranas |>
  dplyr::mutate(
    LocAño = paste(Código_localidad, Año, sep = "_"),
    Taxon  = gsub("\\(|\\)", "", Taxon),  # eliminar paréntesis
    Taxon  = gsub(" ", "_",    Taxon)     # espacios → guiones bajos
  )

samp <- build_samp(aranas_fp, id_col = "LocAño")

# =============================================================================
# 2. CARGA Y PREPARACIÓN DEL ÁRBOL FILOGENÉTICO
# =============================================================================

# Filtrar solo especies presentes en la muestra
species_present <- colnames(samp)[colSums(samp) > 0]

# B9 CORREGIDO: force.ultrametric acepta UN único método.
# "nnls" (Non-Negative Least Squares) es el método más conservador.
ut <- phytools::force.ultrametric(tree, method = "nnls")

# M7 CORREGIDO: verificar que el árbol es realmente ultramétrico
stopifnot("El árbol no es ultramétrico tras force.ultrametric()" =
            ape::is.ultrametric(ut, tol = 1e-6))

# Verificar longitudes de rama ≥ 0 (force.ultrametric puede generar negativas)
neg_branches <- sum(ut$edge.length < 0)
if (neg_branches > 0) {
  warning(neg_branches, " ramas con longitud negativa → corregidas a 0.")
  ut$edge.length <- pmax(ut$edge.length, 0)
}

# Podar el árbol a las especies presentes
pt <- ape::keep.tip(ut, intersect(species_present, ut$tip.label))

# Especies presentes en samp pero ausentes en árbol
missing <- setdiff(species_present, pt$tip.label)
if (length(missing) > 0) {
  warning("Especies en samp sin nodo en árbol podado: ",
          paste(missing, collapse = ", "))
}

ape::plot.phylo(pt, cex = 0.5)
ape::write.nexus(pt, file = PATH_PTREE)

# Matriz de distancias filogenéticas cophenéticas
distm <- ape::cophenetic.phylo(pt)

# =============================================================================
# 3. DIVERSIDAD FILOGENÉTICA — PD (Faith 1992)
# =============================================================================

SES_PD <- cache_or_run(
  file.path(CACHE_DIR, "SES_PD.rds"),
  {
    set.seed(SEED)
    picante::ses.pd(samp, pt, null.model = "taxa.labels",
                    runs = RUNS, iterations = ITER, include.root = TRUE)
  }
)

res_PD <- run_ses_pipeline(SES_PD, y_col = "pd.obs.z",
                            zonas = zonas, label = "PD")

# =============================================================================
# 4. MEAN PAIRWISE DISTANCE — MPD (Webb 2000)
# =============================================================================

SES_MPD <- cache_or_run(
  file.path(CACHE_DIR, "SES_MPD.rds"),
  {
    set.seed(SEED)
    picante::ses.mpd(samp, distm, null.model = "taxa.labels",
                     runs = RUNS, iterations = ITER)
  }
)

res_MPD <- run_ses_pipeline(SES_MPD, y_col = "mpd.obs.z",
                             zonas = zonas, label = "MPD")

# =============================================================================
# 5. MEAN NEAREST TAXON DISTANCE — MNTD (Webb et al. 2002)
# =============================================================================

SES_MNTD <- cache_or_run(
  file.path(CACHE_DIR, "SES_MNTD.rds"),
  {
    set.seed(SEED)
    picante::ses.mntd(samp, distm, null.model = "taxa.labels",
                      runs = RUNS, iterations = ITER)
  }
)

res_MNTD <- run_ses_pipeline(SES_MNTD, y_col = "mntd.obs.z",
                              zonas = zonas, label = "MNTD")

# =============================================================================
# 6. VISUALIZACIÓN CONJUNTA: PD, MPD, MNTD
# =============================================================================
# plot_combined_ses() en R/plot_utils.R elimina el bloque duplicado con fun.R

combined_pd <- combine_ses(
  list(data  = res_PD$data,   y_col = "pd.obs.z",   label = "PD"),
  list(data  = res_MPD$data,  y_col = "mpd.obs.z",  label = "MPD"),
  list(data  = res_MNTD$data, y_col = "mntd.obs.z", label = "MNTD")
)

plot_combined_ses(
  combined_pd,
  tipos_levels = c("PD", "MPD", "MNTD"),
  out_path     = file.path(PLOT_DIR, "zona_año_pd.png")
)

# =============================================================================
# 7. BETA DIVERSIDAD FILOGENÉTICA
# =============================================================================

pbeta <- BAT::beta(samp, pt, func = "jaccard", abund = FALSE)
export_beta(pbeta, prefix = "p")

cat("\n[03_filo.R] Completado.\n")
