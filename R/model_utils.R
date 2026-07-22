# =============================================================================
# R/model_utils.R — Utilidades de modelado y exportación
# =============================================================================
# Requiere que config.R haya sido cargado previamente.
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(car)
  library(DHARMa)
  library(emmeans)
  library(openxlsx)
  library(purrr)
})

# -----------------------------------------------------------------------------
#' Pipeline completo: SES → cbind(zonas) → GLM gaussian → DHARMa → emmeans
#'
#' Elimina los 6 bloques idénticos (PD/MPD/MNTD × filo/fun) de los scripts
#' originales. Corrige además:
#'   - Nombre duplicado del objeto 'simulationOutput' que se sobreescribía
#'     silenciosamente entre bloques MPD y MNTD.
#'   - na.action = na.omit puede silenciar NAs en cbind(); se usa drop_na().
#'
#' @param ses_df   data.frame resultado de ses.pd / ses.mpd / ses.mntd
#' @param y_col    Nombre de la columna respuesta, ej: "pd.obs.z"
#' @param zonas    data.frame con columnas 'año' y 'zona' (mismo orden de filas)
#' @param label    Etiqueta para el plot y ggsave, ej: "PD", "fMPD"
#' @param out_dir  Directorio de salida para plots (default: PLOT_DIR)
#' @return         Lista nombrada: data, model, dharma, emmeans, contrasts
# -----------------------------------------------------------------------------
run_ses_pipeline <- function(ses_df, y_col, zonas, label,
                             out_dir = PLOT_DIR) {
  # 1. Unir con zonas y factorizar
  dat <- dplyr::bind_cols(ses_df, zonas) |>
    tidyr::drop_na(dplyr::all_of(y_col)) |>
    dplyr::mutate(
      año  = factor(año),
      zona = factor(zona, levels = c("W", "E"))
    )

  # 2. Boxplot
  p <- ggplot2::ggplot(dat, ggplot2::aes(
                         x    = año,
                         y    = .data[[y_col]],
                         fill = zona)) +
    ggplot2::geom_boxplot(width        = 0.5,
                          lwd          = 0.3,
                          outlier.size = 0.7) +
    ggplot2::geom_hline(yintercept = c(-1.96, 1.96),
                        linetype   = "dashed",
                        color      = "grey50",
                        linewidth  = 0.4) +
    ggplot2::scale_fill_manual(values = c("W" = "#B5C9D8", "E" = "#D4A9A9")) +
    ggplot2::labs(y    = paste("SES", label),
                  x    = "Año",
                  fill = "Zona",
                  title = paste("SES", label, "por año y zona")) +
    ggplot2::theme_bw(base_family = FONT_FAMILY) +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))

  ggplot2::ggsave(file.path(out_dir, paste0(label, ".png")), p,
                  width = 6, height = 4, dpi = 300)

  # 3. GLM gaussian
  frm <- stats::as.formula(paste(y_col, "~ año * zona"))
  mod <- stats::glm(frm, data = dat, family = gaussian)
  cat("\n====", label, "====\n")
  print(summary(mod))
  print(car::Anova(mod))

  # 4. Diagnóstico DHARMa
  sim <- DHARMa::simulateResiduals(fittedModel = mod, plot = FALSE)
  cat("-- DHARMa uniformity test --\n"); print(DHARMa::testUniformity(sim))
  cat("-- DHARMa dispersion test --\n"); print(DHARMa::testDispersion(sim))

  # 5. Comparaciones múltiples (solo si hay efecto significativo)
  emm <- emmeans::emmeans(mod, ~ año * zona)
  ctr <- emmeans::contrast(emm, method = "pairwise", adjust = "tukey")
  cat("-- Tukey contrasts --\n"); print(ctr)

  invisible(list(data      = dat,
                 model     = mod,
                 dharma    = sim,
                 emmeans   = emm,
                 contrasts = ctr))
}

# -----------------------------------------------------------------------------
#' Exporta los 3 componentes de beta diversidad a Excel
#'
#' Elimina los 9 bloques idénticos (Btotal/Brepl/Brich × taxo/fun/filo).
#' Corrige B10: usa openxlsx consistentemente en lugar de mezclar xlsx/openxlsx.
#'
#' @param beta_obj  Objeto BAT::beta() con slots $Btotal, $Brepl, $Brich
#' @param prefix    Prefijo del archivo: "T" (taxo), "f" (fun), "p" (filo)
#' @param out_dir   Directorio de salida (default: TABLE_DIR)
# -----------------------------------------------------------------------------
export_beta <- function(beta_obj, prefix, out_dir = TABLE_DIR) {
  comps <- list(Btotal = beta_obj$Btotal,
                Brepl  = beta_obj$Brepl,
                Brich  = beta_obj$Brich)
  purrr::iwalk(comps, function(mat, name) {
    fpath <- file.path(out_dir, paste0(prefix, name, ".xlsx"))
    openxlsx::write.xlsx(as.data.frame(as.matrix(mat)), file = fpath)
    message("[export] ", basename(fpath))
  })
  invisible(NULL)
}

# -----------------------------------------------------------------------------
#' Combina resultados SES de múltiples métricas para facet_wrap
#'
#' @param ...  Pares nombrados: list(data=df, y_col="pd.obs.z", label="PD")
#' @return     data.frame con columnas: año, valor, tipo, zona
# -----------------------------------------------------------------------------
combine_ses <- function(...) {
  entries <- list(...)
  purrr::map_dfr(entries, function(e) {
    data.frame(
      año   = e$data$año,
      valor = e$data[[e$y_col]],
      tipo  = e$label,
      zona  = e$data$zona
    )
  })
}
