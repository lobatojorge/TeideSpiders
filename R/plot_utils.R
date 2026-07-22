# =============================================================================
# R/plot_utils.R — Tema y funciones gráficas compartidas
# =============================================================================
# Requiere que config.R haya sido cargado previamente.
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(showtext)
})

# Cargar fuente una sola vez al cargar el módulo
font_add_google(FONT_FAMILY, FONT_FAMILY)
showtext_auto()

# -----------------------------------------------------------------------------
#' Tema ggplot estándar del proyecto
#'
#' Evita redefinir theme() en cada plot. Aplica familia tipográfica de config.R.
# -----------------------------------------------------------------------------
theme_teide <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size   = base_size,
                         base_family = FONT_FAMILY) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position  = "right"
    )
}

# -----------------------------------------------------------------------------
#' Plot combinado de múltiples SES con facet_wrap
#'
#' Elimina el bloque duplicado entre filo.R (L180-202) y fun.R (L225-247).
#'
#' @param combined_df   data.frame de combine_ses() con cols: año, valor, tipo, zona
#' @param tipos_levels  Orden de los facets, ej: c("PD", "MPD", "MNTD")
#' @param out_path      Ruta de salida completa para ggsave
#' @param width, height Dimensiones en pulgadas
#' @return ggplot object (invisible)
# -----------------------------------------------------------------------------
plot_combined_ses <- function(combined_df, tipos_levels, out_path,
                              width = 8, height = 6) {
  combined_df$tipo <- factor(combined_df$tipo, levels = tipos_levels)

  p <- ggplot2::ggplot(combined_df,
                       ggplot2::aes(x    = zona,
                                    y    = valor,
                                    fill = factor(año))) +
    ggplot2::geom_boxplot(position = ggplot2::position_dodge(width = 0.75),
                          lwd          = 0.3,
                          outlier.size = 0.7) +
    ggplot2::geom_hline(yintercept = c(-1.96, 1.96),
                        linetype   = "dashed",
                        color      = "grey50",
                        linewidth  = 0.4) +
    ggplot2::scale_fill_manual(values = PALETTE) +
    ggplot2::facet_wrap(~ tipo) +
    ggplot2::theme_minimal(base_size   = 14,
                           base_family = FONT_FAMILY) +
    ggplot2::labs(x = "Zona", y = "SES", fill = "Año") +
    ggplot2::theme(
      legend.position = "top",
      axis.title      = ggplot2::element_text(size = 16),
      axis.text       = ggplot2::element_text(size = 14),
      strip.text      = ggplot2::element_text(size = 16),
      panel.border    = ggplot2::element_rect(color     = "black",
                                              fill      = NA,
                                              linewidth = 0.5)
    )

  ggplot2::ggsave(out_path, p, width = width, height = height, dpi = 300)
  invisible(p)
}
