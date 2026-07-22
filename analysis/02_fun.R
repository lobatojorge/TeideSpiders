# =============================================================================
# analysis/02_fun.R — Análisis de Diversidad Funcional (REFACTORIZADO)
# =============================================================================
# Construye árbol funcional mediante Random Forest + Gower, calcula fPD, fMPD,
# fMNTD y beta diversidad funcional.
#
# Bugs corregidos:
#   B5 (L42): scale() devuelve matrix; se preserva data.frame con as.data.frame().
#   B6 (L69): dos hclust con métodos distintos → un único objeto hc.
#   B7 (L78): Pearson sobre variables mixtas → Spearman.
#   B8 (L109): pivot_wider sin id_cols nombrado → argumento explícito.
#   B10:       xlsx::write.xlsx → openxlsx::write.xlsx (sin Java).
#   M4:        correlación coherente con tipos de variable.
#   M5:        distancia cophenética del mismo árbol que se exporta.
#   setwd():   eliminado (3 llamadas → here::here()).
#   set.seed(): añadido antes de randomForest y ses.*.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(openxlsx)
  library(randomForest)
  library(cluster)
  library(dendextend)
  library(factoextra)
  library(ape)
  library(picante)
  library(BAT)
  library(corrplot)
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
# 1. CARGA DE MATRIZ DE RASGOS FUNCIONALES
# =============================================================================
# Migrado de xlsx::read.xlsx2 (requiere Java) a openxlsx::read.xlsx

traits <- openxlsx::read.xlsx(PATH_TRAITS, sheet = 1, rowNames = TRUE)
str(traits)

# =============================================================================
# 2. PONDERACIÓN DE RASGOS MEDIANTE RANDOM FOREST NO SUPERVISADO
# =============================================================================

# Coerción de tipos
traits[, 1:3]  <- lapply(traits[, 1:3],  as.numeric)
traits[, 4:19] <- lapply(traits[, 4:19], factor)

# B5 CORREGIDO: scale() devuelve matrix; as.data.frame() preserva el data.frame
traits[, 1:3] <- as.data.frame(scale(traits[, 1:3]))

set.seed(SEED)  # REPRODUCIBILIDAD: faltaba en script original
rf_model <- randomForest::randomForest(
  x          = traits[, 1:19],
  importance = TRUE,
  ntree      = 500
)
randomForest::varImpPlot(rf_model)

# Importancias normalizadas (pesos para Gower)
importancia_traits <- randomForest::importance(rf_model)[, 1]
importancia_traits <- importancia_traits / sum(importancia_traits)
cat("\n--- Importancia relativa de rasgos ---\n")
print(round(sort(importancia_traits, decreasing = TRUE), 4))

# =============================================================================
# 3. CONSTRUCCIÓN DEL ÁRBOL FUNCIONAL
# =============================================================================

matDistancia <- cluster::daisy(traits, metric = "gower",
                                weights = importancia_traits)

# B6 CORREGIDO: UN único hclust (ward.D2); as.phylo sobre el mismo objeto
hc          <- stats::hclust(as.dist(matDistancia), method = "ward.D2")
arbol_phylo <- ape::as.phylo(hc)
ape::write.nexus(arbol_phylo, file = PATH_FTREE)

# Dendrograma coloreado (visualización)
dend   <- dendextend::as.dendrogram(hc)
groups <- stats::cutree(hc, k = 3)
dend   <- dendextend::color_branches(dend, k = 3)
factoextra::fviz_dend(dend, k = 3, cex = 0.3,
                       rect = TRUE, horiz = TRUE)

# =============================================================================
# 4. ANÁLISIS DE CORRELACIÓN ENTRE RASGOS (corrige M4)
# =============================================================================
# B7 CORREGIDO: Spearman válido para variables ordinales/binarias codificadas.
# Pearson de Pearson viola supuestos con estos tipos de variables.

traits_num <- as.data.frame(lapply(traits, as.numeric))
cor_matrix <- stats::cor(traits_num, method = "spearman")
openxlsx::write.xlsx(as.data.frame(cor_matrix),
                     file = file.path(TABLE_DIR, "correlation_matrix_spearman.xlsx"))
corrplot::corrplot(cor_matrix, method = "color", type = "upper", tl.cex = 0.8,
                   title = "Correlación de Spearman entre rasgos funcionales",
                   mar   = c(0, 0, 1, 0))

# =============================================================================
# 5. PREPARACIÓN DE DATOS DE COMUNIDAD
# =============================================================================

aranas <- load_aranas(extra_drop = "Muestreo")

aranas_fp <- aranas |>
  dplyr::mutate(LocAño = paste(Código_localidad, Año, sep = "_"))

# B8 CORREGIDO: id_cols nombrado explícitamente
samp <- build_samp(aranas_fp, id_col = "LocAño")

# Cargar tabla de zonas
zonas <- readxl::read_excel(PATH_ZONAS)

# =============================================================================
# 6. CARGA DEL ÁRBOL FUNCIONAL Y CÁLCULO DE fPD
# =============================================================================

Ftree <- ape::read.nexus(PATH_FTREE)
Ftree$tip.label <- gsub("'", "", Ftree$tip.label)

# Verificar que las especies del árbol coinciden con samp
species_in_samp <- colnames(samp)[colSums(samp) > 0]
species_in_tree <- Ftree$tip.label
missing_from_tree <- setdiff(species_in_samp, species_in_tree)
if (length(missing_from_tree) > 0) {
  warning("Especies en samp sin correspondencia en árbol: ",
          paste(missing_from_tree, collapse = ", "))
}

# Distancia cophenética del MISMO árbol (M5 CORREGIDO: antes se usaba
# cophenetic de un segundo hclust "average" distinto del árbol exportado)
distm <- ape::cophenetic.phylo(Ftree)

# --- fPD ---
SES_fPD <- cache_or_run(
  file.path(CACHE_DIR, "SES_fPD.rds"),
  {
    set.seed(SEED)
    picante::ses.pd(samp, Ftree, null.model = "taxa.labels",
                    runs = RUNS, iterations = ITER, include.root = TRUE)
  }
)

res_fPD <- run_ses_pipeline(SES_fPD,  y_col = "pd.obs.z",
                             zonas = zonas, label = "fPD")

# --- fMPD ---
SES_fMPD <- cache_or_run(
  file.path(CACHE_DIR, "SES_fMPD.rds"),
  {
    set.seed(SEED)
    picante::ses.mpd(samp, distm, null.model = "taxa.labels",
                     runs = RUNS, iterations = ITER)
  }
)

res_fMPD <- run_ses_pipeline(SES_fMPD, y_col = "mpd.obs.z",
                              zonas = zonas, label = "fMPD")

# --- fMNTD ---
SES_fMNTD <- cache_or_run(
  file.path(CACHE_DIR, "SES_fMNTD.rds"),
  {
    set.seed(SEED)
    picante::ses.mntd(samp, distm, null.model = "taxa.labels",
                      runs = RUNS, iterations = ITER)
  }
)

res_fMNTD <- run_ses_pipeline(SES_fMNTD, y_col = "mntd.obs.z",
                               zonas = zonas, label = "fMNTD")

# =============================================================================
# 7. VISUALIZACIÓN CONJUNTA: fPD, fMPD, fMNTD
# =============================================================================
# Bloque duplicado entre fun.R y filo.R → plot_combined_ses() en plot_utils.R

combined_fd <- combine_ses(
  list(data  = res_fPD$data,   y_col = "pd.obs.z",   label = "fPD"),
  list(data  = res_fMPD$data,  y_col = "mpd.obs.z",  label = "fMPD"),
  list(data  = res_fMNTD$data, y_col = "mntd.obs.z", label = "fMNTD")
)

plot_combined_ses(
  combined_fd,
  tipos_levels = c("fPD", "fMPD", "fMNTD"),
  out_path     = file.path(PLOT_DIR, "zona_año_fd.png")
)

# =============================================================================
# 8. BETA DIVERSIDAD FUNCIONAL
# =============================================================================

fbeta <- BAT::beta(samp, Ftree, func = "jaccard", abund = FALSE)
export_beta(fbeta, prefix = "f")

# =============================================================================
# 9. CONTRIBUCIÓN DE ESPECIES Y OTROS ÍNDICES
# =============================================================================

spcontribution <- BAT::contribution(samp, Ftree, abund = FALSE)

# Top-3 especies contribuyentes por comunidad (función interna, sin repetición)
get_top3 <- function(fila) {
  ord  <- order(fila, decreasing = TRUE, na.last = NA)
  top3 <- ord[seq_len(min(3L, length(ord)))]
  tibble::tibble(
    sp1 = names(fila)[top3[1]], val1 = fila[top3[1]],
    sp2 = names(fila)[top3[2]], val2 = fila[top3[2]],
    sp3 = names(fila)[top3[3]], val3 = fila[top3[3]]
  )
}

top3_resultados <- purrr::map_dfr(
  seq_len(nrow(spcontribution)),
  ~ get_top3(spcontribution[.x, ]),
  .id = "community"
)
openxlsx::write.xlsx(top3_resultados,
                     file = file.path(TABLE_DIR, "top3_contribution.xlsx"))

# Índices adicionales
disp_result <- BAT::dispersion(samp, Ftree, distm,
                                func = "originality",
                                abund = FALSE, relative = TRUE)
openxlsx::write.xlsx(as.data.frame(disp_result),
                     file = file.path(TABLE_DIR, "dispersion.xlsx"))

evenness_result <- BAT::evenness(samp, Ftree, distm,
                                  method = "expected",
                                  func = "camargo", abund = FALSE)
openxlsx::write.xlsx(as.data.frame(evenness_result),
                     file = file.path(TABLE_DIR, "evenness.xlsx"))

evenness_contrib <- BAT::evenness.contribution(samp, Ftree, distm,
                                                method = "expected",
                                                func   = "camargo",
                                                abund  = FALSE)
openxlsx::write.xlsx(as.data.frame(evenness_contrib),
                     file = file.path(TABLE_DIR, "evenness_contribution.xlsx"))

originality_result <- BAT::originality(samp, Ftree, distm,
                                        abund    = FALSE,
                                        relative = FALSE)
openxlsx::write.xlsx(as.data.frame(originality_result),
                     file = file.path(TABLE_DIR, "originality.xlsx"))

cat("\n[02_fun.R] Completado.\n")
