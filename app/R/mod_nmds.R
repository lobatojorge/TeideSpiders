# =============================================================================
# app/R/mod_nmds.R — Módulo Shiny: Ordenación NMDS
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(dplyr)

# ── UI ───────────────────────────────────────────────────────────────────────
mod_nmds_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      icon("circle-nodes"), "Ordenación NMDS · Jaccard (presencia/ausencia)"
    ),
    card_body(
      layout_columns(
        col_widths = c(2, 10),
        # Sidebar de controles
        tagList(
          tags$div(class = "mb-3",
            checkboxInput(ns("show_hulls"),  "Polígonos convexos", TRUE),
            checkboxInput(ns("show_labels"), "Etiquetas de sitio", FALSE)
          ),
          tags$hr(),
          uiOutput(ns("stress_info"))
        ),
        # Plot
        plotlyOutput(ns("nmds_plot"), height = "460px")
      )
    )
  )
}

# ── Server ───────────────────────────────────────────────────────────────────
mod_nmds_server <- function(id, nmds_r) {
  moduleServer(id, function(input, output, session) {

    output$stress_info <- renderUI({
      stress  <- nmds_r()$stress
      quality <- dplyr::case_when(
        stress < 0.05 ~ list(label = "Excelente", cls = "success"),
        stress < 0.10 ~ list(label = "Buena",     cls = "success"),
        stress < 0.20 ~ list(label = "Aceptable", cls = "warning"),
        TRUE          ~ list(label = "Pobre",      cls = "danger")
      )
      tagList(
        tags$p(class = "text-muted small mb-1", "Stress"),
        tags$span(
          class = paste0("badge bg-", quality$cls),
          paste0(round(stress, 4), " — ", quality$label)
        ),
        tags$p(class = "text-muted small mt-3",
               "Stress < 0.20 = representación fiable (Clarke 1993).")
      )
    })

    output$nmds_plot <- renderPlotly({
      d     <- nmds_r()
      sites <- d$sites
      hull  <- d$hull

      p <- ggplot(sites, aes(x = NMDS1, y = NMDS2,
                              color = año, shape = año,
                              text  = paste0("Sitio: ", localidad,
                                             "<br>Año: ",  año,
                                             "<br>NMDS1: ", round(NMDS1, 3),
                                             "<br>NMDS2: ", round(NMDS2, 3)))) +
        geom_point(size = 4, alpha = 0.9, stroke = 0.5)

      if (input$show_hulls) {
        p <- p +
          geom_polygon(
            data = hull,
            aes(x = NMDS1, y = NMDS2, group = año, fill = año),
            alpha = 0.15, color = NA, inherit.aes = FALSE
          )
      }

      if (input$show_labels) {
        p <- p +
          ggrepel::geom_text_repel(aes(label = localidad),
                                   size = 3, max.overlaps = 20,
                                   show.legend = FALSE)
      }

      p <- p +
        scale_color_manual(values = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
        scale_fill_manual(values  = c("1995" = "#AEC6CF", "2024" = "#F08080")) +
        scale_shape_manual(values = c("1995" = 16L, "2024" = 17L)) +
        labs(color = "Año", shape = "Año", fill = "Año") +
        theme_minimal(base_size = 13) +
        theme(panel.grid = element_line(color = "grey92"))

      ggplotly(p, tooltip = "text") |>
        layout(
          legend = list(orientation = "h", x = 0.3, y = -0.1),
          hoverlabel = list(bgcolor = "white", font = list(size = 12))
        )
    })
  })
}
