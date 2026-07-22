# =============================================================================
# app/R/mod_beta.R — Módulo Shiny: Beta diversidad (heatmap interactivo)
# =============================================================================
# Recibe app_beta.rds: lista [T/p/f][[Btotal/Brepl/Brich]] de data.frames.
# =============================================================================

library(shiny)
library(bslib)
library(plotly)
library(dplyr)

# ── UI ───────────────────────────────────────────────────────────────────────
mod_beta_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(3, 9),
    card(
      card_header(icon("sliders"), " Selección"),
      card_body(
        selectInput(ns("dimension"), "Dimensión:",
                    choices = c(
                      "Taxonómica"   = "T",
                      "Filogenética" = "p",
                      "Funcional"    = "f"
                    )),
        selectInput(ns("component"), "Componente:",
                    choices = c(
                      "β Total"           = "Btotal",
                      "β Reemplazamiento" = "Brepl",
                      "β Riqueza"         = "Brich"
                    )),
        tags$hr(),
        tags$div(class = "text-muted small",
          tags$strong("β Total = β Reempl. + β Riqueza"), tags$br(),
          "Escala: 0 (alta similitud) → 1 (alta diferencia).", tags$br(), tags$br(),
          tags$strong("β Reemplazamiento:"), " diversidad debida a recambio de especies.", tags$br(),
          tags$strong("β Riqueza:"),         " diversidad debida a diferencia de riqueza."
        ),
        tags$hr(),
        uiOutput(ns("stats_summary"))
      )
    ),
    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        icon("th"), "Mapa de calor de beta diversidad"
      ),
      plotlyOutput(ns("heatmap"), height = "560px"),
      card_footer(
        class = "text-muted small",
        "Cada celda representa la distancia beta entre dos sitios.",
        " La diagonal (mismo sitio) se muestra como NA."
      )
    )
  )
}

# ── Server ───────────────────────────────────────────────────────────────────
mod_beta_server <- function(id, beta_r) {
  moduleServer(id, function(input, output, session) {

    selected_mat <- reactive({
      beta_r()[[input$dimension]][[input$component]]
    })

    output$stats_summary <- renderUI({
      mat    <- as.matrix(selected_mat())
      vals   <- mat[lower.tri(mat)]
      tagList(
        tags$p(class = "text-muted small mb-1",
               tags$strong("Estadísticos (triángulo inferior):")),
        tags$table(
          class = "table table-sm table-borderless",
          style = "font-size: 0.78rem;",
          tags$tbody(
            tags$tr(tags$td("Media"),   tags$td(round(mean(vals, na.rm=TRUE), 3))),
            tags$tr(tags$td("Mediana"), tags$td(round(median(vals, na.rm=TRUE), 3))),
            tags$tr(tags$td("SD"),      tags$td(round(sd(vals, na.rm=TRUE), 3))),
            tags$tr(tags$td("Mín"),     tags$td(round(min(vals, na.rm=TRUE), 3))),
            tags$tr(tags$td("Máx"),     tags$td(round(max(vals, na.rm=TRUE), 3)))
          )
        )
      )
    })

    output$heatmap <- renderPlotly({
      mat  <- as.matrix(selected_mat())
      diag(mat) <- NA  # diagonal no informativa

      dim_label <- switch(input$dimension,
                          "T" = "Taxonómica",
                          "p" = "Filogenética",
                          "f" = "Funcional")
      comp_label <- switch(input$component,
                           "Btotal" = "β Total",
                           "Brepl"  = "β Reemplazamiento",
                           "Brich"  = "β Riqueza")

      plot_ly(
        x             = colnames(mat),
        y             = rownames(mat),
        z             = mat,
        type          = "heatmap",
        colorscale    = list(
          c(0, "#2C7BB6"), c(0.25, "#ABD9E9"),
          c(0.5, "#FFFFBF"), c(0.75, "#FDAE61"),
          c(1,  "#D7191C")
        ),
        zmin          = 0,
        zmax          = 1,
        colorbar      = list(title = "β", len = 0.7),
        hovertemplate = paste0(
          "Sitio A: %{y}<br>",
          "Sitio B: %{x}<br>",
          "β: %{z:.3f}<extra></extra>"
        )
      ) |>
        layout(
          title = list(text = paste(dim_label, "·", comp_label),
                       font = list(size = 14)),
          xaxis = list(tickangle = -45, tickfont = list(size = 10)),
          yaxis = list(autorange  = "reversed",
                       tickfont   = list(size = 10)),
          margin = list(l = 80, b = 80)
        )
    })
  })
}
