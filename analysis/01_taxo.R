# =============================================================================
# analysis/01_taxo.R — Análisis de Diversidad Taxonómica (REFACTORIZADO)
# =============================================================================
# Compara riqueza de especies entre 1995 y 2024 en el P.N. Teide.
# Calcula beta diversidad taxonómica y curvas de acumulación.
#
# Bugs corregidos:
#   B1 (L169): asignación nula de rownames eliminada.
#   B2 (L170): doble [,-1] eliminado; build_samp() gestiona rownames.
#   B3 (L233): Sites permanece numérico para geom_smooth; factor solo en eje.
#   B4 (L210): completitud calculada Y reportada.
#   M1:        selección de distribución por AIC documentada en código.
#   M3:        pendiente con geom_smooth en Sites numérico (lineal global).
#   setwd():   eliminado; aquí::here() en config.R.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(vegan)
  library(BAT)
  library(MASS)
  library(car)
  library(DHARMa)
  library(emmeans)
})

source(here("config.R"))
source(here("R/data_prep.R"))
source(here("R/model_utils.R"))
source(here("R/plot_utils.R"))

# =============================================================================
# 1. CARGA DE DATOS
# =============================================================================

aranas <- load_aranas()

# =============================================================================
# 2. RIQUEZA POR AÑO — GLM Poisson con selección por AIC (corrige M1)
# =============================================================================

riqueza <- aranas |>
  dplyr::filter(Año %in% YEARS) |>
  dplyr::group_by(Código_localidad, Año) |>
  dplyr::summarise(riqueza = dplyr::n_distinct(Taxon), .groups = "drop") |>
  dplyr::mutate(Año = factor(Año))

# --- Plot --------------------------------------------------------------------
p_riqueza <- ggplot2::ggplot(riqueza,
                              ggplot2::aes(x    = Año,
                                           y    = riqueza,
                                           fill = Año)) +
  ggplot2::geom_boxplot() +
  ggplot2::scale_fill_manual(values = PALETTE) +
  ggplot2::labs(title = "Comparación de Riqueza entre 1995 y 2024",
                x     = "Año",
                y     = "Riqueza de especies",
                fill  = "Año") +
  theme_teide()

ggplot2::ggsave(file.path(PLOT_DIR, "boxplot_riqueza.png"),
                p_riqueza, width = 6, height = 4, dpi = 300)

# --- Selección de distribución por AIC (M1: documentado) --------------------
modelo_poisson    <- stats::glm(riqueza ~ Año, data = riqueza,
                                family = poisson)
modelo_nb_simple  <- MASS::glm.nb(riqueza ~ Año, data = riqueza)

cat("\n--- Selección de distribución (modelo 1: efecto Año) ---\n")
cat("AIC Poisson:          ", stats::AIC(modelo_poisson),    "\n")
cat("AIC Binomial Negativa:", stats::AIC(modelo_nb_simple),  "\n")

# Usar el modelo con menor AIC para el test
if (stats::AIC(modelo_poisson) <= stats::AIC(modelo_nb_simple)) {
  cat("Modelo seleccionado: Poisson\n")
  summary(modelo_poisson)
  stats::anova(modelo_poisson, test = "Chisq")
} else {
  cat("Modelo seleccionado: Binomial Negativa\n")
  summary(modelo_nb_simple)
  car::Anova(modelo_nb_simple)
}

# =============================================================================
# 3. RIQUEZA POR AÑO Y TIPO DE MUESTREO — GLM Binomial Negativa
# =============================================================================

riqueza_loc_muest <- aranas |>
  dplyr::group_by(Código_localidad, Año, Muestreo) |>
  dplyr::summarise(Riqueza = dplyr::n_distinct(Taxon), .groups = "drop") |>
  dplyr::mutate(Año = factor(Año))

# --- Plot --------------------------------------------------------------------
p_muest <- ggplot2::ggplot(riqueza_loc_muest,
                            ggplot2::aes(x    = Muestreo,
                                         y    = Riqueza,
                                         fill = Año)) +
  ggplot2::geom_boxplot(lwd = 0.3, outlier.size = 0.7) +
  ggplot2::scale_fill_manual(values = PALETTE) +
  ggplot2::labs(y = "Riqueza de especies") +
  ggplot2::theme_linedraw() +
  ggplot2::theme(panel.grid   = ggplot2::element_blank(),
                 axis.title.x = ggplot2::element_blank(),
                 text         = ggplot2::element_text(family = FONT_FAMILY))

ggplot2::ggsave(file.path(PLOT_DIR, "riqueza_año_muest.png"),
                p_muest, width = 6, height = 4, dpi = 300)

# --- Modelo ------------------------------------------------------------------
model_NB <- MASS::glm.nb(Riqueza ~ Año * Muestreo,
                          data      = riqueza_loc_muest,
                          na.action = na.omit)
summary(model_NB)
anova_am <- car::Anova(model_NB)
print(anova_am)

sim_NB <- DHARMa::simulateResiduals(fittedModel = model_NB, plot = TRUE)

marginal_nb <- emmeans::emmeans(model_NB, ~ Año * Muestreo)
pairs(marginal_nb, adjust = "tukey")

# =============================================================================
# 4. ANÁLISIS NMDS
# =============================================================================
# M2 corregido: la conversión a presencia/ausencia ocurre dentro de build_samp(),
# antes de calcular la distancia de Jaccard. El flujo es explícito y sin objetos
# intermedios ambiguos.

aranas_nmds <- aranas |>
  dplyr::mutate(localidad_año = paste(Código_localidad, Año, sep = "_"))

# B2 CORREGIDO: build_samp() maneja rownames; no hay doble [,-1]
NMDSPresAu <- build_samp(aranas_nmds, id_col = "localidad_año")

set.seed(SEED)
matriz_distancia <- vegan::vegdist(NMDSPresAu, method = "jaccard", na.rm = TRUE)

set.seed(SEED)
nmds_result <- vegan::metaMDS(matriz_distancia, k = 2, trymax = 100)
cat("\nStress NMDS:", nmds_result$stress, "\n")

# Extraer coordenadas y metadatos de sitios
nmds_sites <- as.data.frame(vegan::scores(nmds_result, display = "sites")) |>
  tibble::rownames_to_column("localidad_año") |>
  dplyr::mutate(
    localidad = sub("_.*", "", localidad_año),
    año       = sub(".*_", "", localidad_año)
  )

# Polígonos convexos por año
hull <- nmds_sites |>
  dplyr::group_by(año) |>
  dplyr::slice(grDevices::chull(NMDS1, NMDS2))

p_nmds <- ggplot2::ggplot(nmds_sites, ggplot2::aes(x = NMDS1, y = NMDS2)) +
  ggplot2::geom_point(ggplot2::aes(color = localidad),
                      size        = 3,
                      show.legend = FALSE) +
  ggplot2::geom_polygon(data  = hull,
                        ggplot2::aes(group = año, fill = año),
                        alpha = 0.3) +
  ggplot2::scale_fill_manual(values  = PALETTE) +
  ggplot2::scale_color_manual(values = PALETTE) +
  ggplot2::labs(title = "NMDS por Año y Localidad",
                x     = "NMDS1",
                y     = "NMDS2",
                fill  = "Año") +
  ggplot2::annotate("text", x = Inf, y = Inf,
                    label  = paste("Stress =", round(nmds_result$stress, 3)),
                    hjust  = 1.1, vjust = 1.5, size = 3.5,
                    family = FONT_FAMILY) +
  theme_teide()

ggplot2::ggsave(file.path(PLOT_DIR, "nmds.png"), p_nmds,
                width = 7, height = 5, dpi = 300)

# =============================================================================
# 5. BETA DIVERSIDAD TAXONÓMICA
# =============================================================================

Tbeta <- BAT::beta(NMDSPresAu, func = "jaccard", abund = FALSE)
export_beta(Tbeta, prefix = "T")

# =============================================================================
# 6. CURVAS DE ACUMULACIÓN DE ESPECIES
# =============================================================================

aranas_95 <- dplyr::filter(aranas, Año == 1995)
aranas_24 <- dplyr::filter(aranas, Año == 2024)

# Función auxiliar local para construir matriz por año
make_accum_matrix <- function(df) {
  df |>
    tidyr::pivot_wider(
      id_cols     = "Código_localidad",
      names_from  = "Taxon",
      values_from = "N_exx.",
      values_fn   = sum,
      values_fill = 0
    ) |>
    dplyr::select(-Código_localidad)
}

matriz_95 <- make_accum_matrix(aranas_95)
matriz_24 <- make_accum_matrix(aranas_24)

# Estimadores de riqueza asintótica
specpool_95 <- vegan::specpool(matriz_95)
specpool_24 <- vegan::specpool(matriz_24)

# B4 CORREGIDO: completitud calculada y reportada
completitud <- tibble::tibble(
  Year        = c("1995", "2024"),
  Chao        = c(specpool_95$chao,    specpool_24$chao),
  Observadas  = c(specpool_95$Species, specpool_24$Species),
  Completitud = round(Observadas / Chao * 100, 1)
)
cat("\n--- Completitud del muestreo (Chao) ---\n")
print(completitud)

# Curvas de acumulación con semilla fijada (reproducibilidad)
set.seed(SEED); accum_95 <- vegan::specaccum(matriz_95, method = "random",
                                              permutations = 1000)
set.seed(SEED); accum_24 <- vegan::specaccum(matriz_24, method = "random",
                                              permutations = 1000)

# Preparar data.frame para plot
accum_df <- dplyr::bind_rows(
  data.frame(Sites   = accum_95$sites,
             Richness = accum_95$richness,
             SD       = accum_95$sd,
             Year     = "1995"),
  data.frame(Sites   = accum_24$sites,
             Richness = accum_24$richness,
             SD       = accum_24$sd,
             Year     = "2024")
)
# B3 CORREGIDO: Sites permanece NUMÉRICO; factor solo como breaks en el eje

# Pendientes como coeficiente de regresión lineal (descriptivo)
pendientes <- accum_df |>
  dplyr::group_by(Year) |>
  dplyr::summarise(
    pendiente = stats::coef(stats::lm(Richness ~ Sites))[["Sites"]],
    .groups   = "drop"
  )
cat("\n--- Pendientes de acumulación (regresión lineal) ---\n")
print(pendientes)

p_accum <- ggplot2::ggplot(accum_df,
                            ggplot2::aes(x     = Sites,
                                         y     = Richness,
                                         color = Year,
                                         group = Year)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = Richness - SD,
                                     ymax = Richness + SD,
                                     fill = Year),
                       alpha    = 0.15,
                       color    = NA) +
  ggplot2::geom_point() +
  ggplot2::geom_line(linewidth = 1.5) +
  ggplot2::geom_smooth(method    = "lm",
                       se        = FALSE,
                       linetype  = "dashed",
                       color     = "grey50",
                       linewidth = 1) +
  ggplot2::scale_color_manual(values = PALETTE) +
  ggplot2::scale_fill_manual(values  = PALETTE) +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::annotate("text",
                    x      = max(accum_df$Sites) * 0.75,
                    y      = max(accum_df$Richness) * 0.95,
                    label  = paste("Chao 1995 =",
                                   round(specpool_95$chao)),
                    size   = 4,
                    family = FONT_FAMILY) +
  ggplot2::annotate("text",
                    x      = max(accum_df$Sites) * 0.75,
                    y      = max(accum_df$Richness) * 0.75,
                    label  = paste("Chao 2024 =",
                                   round(specpool_24$chao)),
                    size   = 4,
                    family = FONT_FAMILY) +
  ggplot2::annotate("text",
                    x      = max(accum_df$Sites) * 0.75,
                    y      = max(accum_df$Richness) * 0.55,
                    label  = paste0(
                      "m₁₉₉₅ = ", round(pendientes$pendiente[1], 2),
                      "\nm₂₀₂₄ = ", round(pendientes$pendiente[2], 2)),
                    size   = 3.5,
                    family = FONT_FAMILY) +
  ggplot2::labs(title = "Curvas de acumulación de especies por año",
                x     = "Número de localidades",
                y     = "Riqueza acumulada",
                color = "Año",
                fill  = "Año") +
  theme_teide()

ggplot2::ggsave(file.path(PLOT_DIR, "curvas_acumulacion.png"),
                p_accum, width = 20, height = 20, units = "cm", dpi = 300)

cat("\n[01_taxo.R] Completado.\n")
