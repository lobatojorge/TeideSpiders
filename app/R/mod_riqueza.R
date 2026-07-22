# =============================================================================
# app/R/mod_riqueza.R — Módulo Shiny: Riqueza de especies
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(dplyr)
library(vegan)

# ── UI ───────────────────────────────────────────────────────────────────────
mod_riqueza_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header(
          class = "d-flex align-items-center gap-2",
          icon("chart-bar"), "Riqueza por año"
        ),
        plotlyOutput(ns("boxplot_año"), height = "320px")
      ),
      card(
        card_header(
          class = "d-flex align-items-center gap-2",
          icon("filter"), "Riqueza por tipo de muestreo"
        ),
        plotlyOutput(ns("boxplot_muest"), height = "320px")
      )
    ),
    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        icon("table"), "Estimadores de riqueza (Chao)"
      ),
      card_body(
        tableOutput(ns("tabla_chao"))
      )
    )
  )
}

# ── Server ───────────────────────────────────────────────────────────────────
mod_riqueza_server <- function(id, aranas_r) {
  moduleServer(id, function(input, output, session) {

    riqueza_año <- reactive({
      aranas_r() |>
        filter(Año %in% c(1995, 2024)) |>
        group_by(Código_localidad, Año) |>
        summarise(riqueza = n_distinct(Taxon), .groups = "drop") |>
        mutate(Año = factor(Año))
    })

    output$boxplot_año <- renderPlotly({
      p <- ggplot(riqueza_año(),
                  aes(x = Año, y = riqueza, fill = Año,
                      text = paste0("Localidad: ", Código_localidad,
                                    "<br>Riqueza: ", riqueza))) +
        geom_boxplot(alpha = 0.75, outlier.shape = 21,
                     outlier.fill = "white", outlier.size = 2) +
        geom_jitter(aes(color = Año), width = 0.12,
                    alpha = 0.55, size = 2.5) +
        scale_fill_manual(values  = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
        scale_color_manual(values = c("1995" = "#5a8fa0", "2024" = "#b04040")) +
        labs(x = NULL, y = "Nº de especies") +
        theme_minimal(base_size = 13) +
        theme(legend.position = "none",
              panel.grid.major.x = element_blank())
      ggplotly(p, tooltip = "text") |>
        layout(hoverlabel = list(bgcolor = "white", font = list(size = 12)))
    })

    output$boxplot_muest <- renderPlotly({
      dat <- aranas_r() |>
        group_by(Código_localidad, Año, Muestreo) |>
        summarise(Riqueza = n_distinct(Taxon), .groups = "drop") |>
        mutate(Año = factor(Año))

      p <- ggplot(dat, aes(x = Muestreo, y = Riqueza, fill = Año,
                            text = paste0("Método: ", Muestreo,
                                          "<br>Año: ", Año,
                                          "<br>Riqueza: ", Riqueza))) +
        geom_boxplot(lwd = 0.35, outlier.size = 1.5, alpha = 0.75) +
        scale_fill_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
        labs(x = NULL, y = "Nº de especies", fill = "Año") +
        theme_minimal(base_size = 13) +
        theme(panel.grid.major.x = element_blank())
      ggplotly(p, tooltip = "text") |>
        layout(hoverlabel = list(bgcolor = "white"))
    })

    output$tabla_chao <- renderTable({
      make_mat <- function(df) {
        df |>
          tidyr::pivot_wider(id_cols = "Código_localidad",
                             names_from = "Taxon", values_from = "N_exx.",
                             values_fn = sum, values_fill = 0) |>
          select(-Código_localidad)
      }
      sp95 <- vegan::specpool(make_mat(filter(aranas_r(), Año == 1995)))
      sp24 <- vegan::specpool(make_mat(filter(aranas_r(), Año == 2024)))

      tibble::tibble(
        Año              = c("1995", "2024"),
        Observadas       = c(sp95$Species, sp24$Species),
        `Chao (est.)`    = c(round(sp95$chao), round(sp24$chao)),
        `Completitud (%)`= round(c(sp95$Species / sp95$chao,
                                   sp24$Species / sp24$chao) * 100, 1)
      )
    }, striped = TRUE, hover = TRUE, bordered = TRUE)
  })
}
