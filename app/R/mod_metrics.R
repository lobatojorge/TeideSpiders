# =============================================================================
# app/R/mod_metrics.R — Módulo Shiny: SES de diversidad (filogenética/funcional)
# =============================================================================
# Módulo reutilizable: funciona tanto para SES filogenéticos (PD/MPD/MNTD)
# como funcionales (fPD/fMPD/fMNTD) pasando el parámetro `prefix`.
# Recibe un data.frame con columnas: año, zona, pd.obs.z, mpd.obs.z, mntd.obs.z
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(dplyr)

# ── UI ───────────────────────────────────────────────────────────────────────
mod_metrics_ui <- function(id, title = "Índices SES", prefix = "") {
  ns <- NS(id)

  choices <- setNames(
    c("pd.obs.z", "mpd.obs.z", "mntd.obs.z"),
    paste0(prefix, c("PD", "MPD", "MNTD"))
  )

  tagList(
    layout_columns(
      col_widths = c(3, 9),
      card(
        card_header(icon("sliders"), " Controles"),
        card_body(
          selectInput(ns("metric"), "Métrica:",
                      choices  = choices,
                      selected = "pd.obs.z"),
          tags$hr(),
          checkboxInput(ns("show_ref"), "Umbrales ±1.96", value = TRUE),
          checkboxInput(ns("show_jitter"), "Puntos individuales", value = TRUE),
          tags$hr(),
          tags$p(class = "text-muted small",
                 tags$strong("SES > 1.96:"), " overdispersion",  tags$br(),
                 tags$strong("SES < −1.96:"), " clustering",     tags$br(),
                 tags$strong("~0:"),          " sin patrón")
        )
      ),
      card(
        card_header(
          class = "d-flex align-items-center gap-2",
          icon("chart-bar"), title
        ),
        plotlyOutput(ns("ses_plot"), height = "420px"),
        card_footer(
          class = "text-muted small",
          "Boxplot de SES por zona (W/E) y año. SES = (obs − E[null]) / SD[null]."
        )
      )
    ),
    card(
      card_header(icon("table"), " Tabla de valores SES"),
      card_body(
        tableOutput(ns("ses_table"))
      )
    )
  )
}

# ── Server ───────────────────────────────────────────────────────────────────
mod_metrics_server <- function(id, ses_data_r, prefix = "") {
  moduleServer(id, function(input, output, session) {

    dat <- reactive({
      ses_data_r() |>
        tidyr::drop_na(dplyr::all_of(input$metric)) |>
        dplyr::rename(valor = dplyr::all_of(input$metric))
    })

    metric_label <- reactive({
      lbl <- switch(input$metric,
                    "pd.obs.z"   = "PD",
                    "mpd.obs.z"  = "MPD",
                    "mntd.obs.z" = "MNTD")
      paste0(prefix, lbl)
    })

    output$ses_plot <- renderPlotly({
      d <- dat()

      p <- ggplot(d, aes(x = año, y = valor, fill = zona,
                          text = paste0("Año: ",  año,
                                        "<br>Zona: ", zona,
                                        "<br>SES: ", round(valor, 3)))) +
        geom_boxplot(position     = position_dodge(0.75),
                     width        = 0.55,
                     lwd          = 0.35,
                     outlier.size = 1.8,
                     alpha        = 0.75)

      if (input$show_jitter) {
        p <- p + geom_jitter(aes(color = zona),
                              position = position_jitterdodge(
                                jitter.width = 0.1, dodge.width = 0.75
                              ),
                              size  = 2, alpha = 0.5, show.legend = FALSE)
      }

      if (input$show_ref) {
        p <- p +
          geom_hline(yintercept =  1.96, linetype = "dashed",
                     color = "grey55", linewidth = 0.5) +
          geom_hline(yintercept = -1.96, linetype = "dashed",
                     color = "grey55", linewidth = 0.5) +
          annotate("text", x = 0.6, y = 2.15, label = "+1.96",
                   size = 3, color = "grey50") +
          annotate("text", x = 0.6, y = -2.15, label = "−1.96",
                   size = 3, color = "grey50")
      }

      p <- p +
        scale_fill_manual(values  = c("W" = "#B5C9D8", "E" = "#D4A9A9")) +
        scale_color_manual(values = c("W" = "#5a8fa0", "E" = "#a04040")) +
        labs(x = "Año", y = paste("SES", metric_label()), fill = "Zona") +
        theme_minimal(base_size = 13) +
        theme(panel.grid.major.x = element_blank())

      ggplotly(p, tooltip = "text") |>
        layout(
          boxmode    = "group",
          hoverlabel = list(bgcolor = "white", font = list(size = 12))
        )
    })

    output$ses_table <- renderTable({
      dat() |>
        dplyr::group_by(año, zona) |>
        dplyr::summarise(
          n      = dplyr::n(),
          media  = round(mean(valor, na.rm = TRUE), 3),
          sd     = round(sd(valor, na.rm = TRUE), 3),
          mediana = round(median(valor, na.rm = TRUE), 3),
          .groups = "drop"
        ) |>
        dplyr::rename(
          Año = año, Zona = zona, N = n,
          Media = media, SD = sd, Mediana = mediana
        )
    }, striped = TRUE, hover = TRUE, bordered = TRUE)
  })
}
