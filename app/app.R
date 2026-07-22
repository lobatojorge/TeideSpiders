# =============================================================================
# app/app.R — TeideSpiders: Visor Interactivo de Diversidad
# =============================================================================
# La app es SOLO-LECTURA: lee datos pre-calculados de output/cache/.
# Para regenerar los datos: ejecutar scripts/prepare_app_data.R.
#
# Ejecutar localmente: shiny::runApp("app")
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(plotly)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(vegan)
  library(ggrepel)
  library(here)
})

# Cargar módulos y configuración
source(here("config.R"))
source(here("R/data_prep.R"))

for (f in list.files(here("app", "R"), full.names = TRUE, pattern = "\\.R$")) {
  source(f)
}

# ── Carga de datos pre-calculados (startup, no dentro de reactive) ────────────
.cache_names <- c("app_aranas", "app_nmds",
                   "app_ses_phylo", "app_ses_fun", "app_beta")
.missing <- .cache_names[!file.exists(
  file.path(CACHE_DIR, paste0(.cache_names, ".rds"))
)]

if (length(.missing) > 0) {
  stop(
    "Archivos de caché no encontrados. Ejecutar primero:\n",
    "  Rscript scripts/prepare_app_data.R\n",
    "Faltantes: ", paste(.missing, collapse = ", ")
  )
}

app_data <- lapply(
  setNames(.cache_names, .cache_names),
  function(nm) readRDS(file.path(CACHE_DIR, paste0(nm, ".rds")))
)
rm(.cache_names, .missing)

# ── Tema ─────────────────────────────────────────────────────────────────────
app_theme <- bs_theme(
  version    = 5,
  bootswatch = "darkly",
  primary    = "#58a6ff",
  "navbar-bg"     = "#0d1117",
  "body-bg"       = "#0d1117",
  "card-bg"       = "#161b22",
  "card-border-color" = "rgba(255,255,255,0.08)",
  "font-size-base" = "0.9rem"
)

# ── UI ───────────────────────────────────────────────────────────────────────
ui <- page_navbar(
  title = tags$div(
    class = "d-flex align-items-center gap-2",
    tags$span("\U0001F577", style = "font-size:1.3em; line-height:1;"),
    tags$div(
      tags$strong("TeideSpiders", style = "letter-spacing:0.03em;"),
      tags$small(" · P.N. Teide 1995–2024",
                 style = "opacity:0.55; font-weight:400; font-size:0.8em;")
    )
  ),
  theme    = app_theme,
  fillable = TRUE,
  window_title = "TeideSpiders · Diversidad de Arañas",

  tags$head(
    tags$link(rel = "stylesheet", href = "custom.css"),
    tags$link(
      rel  = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap"
    )
  ),

  # ── Tab 1: Diversidad Taxonómica ──────────────────────────────────────────
  nav_panel(
    title = tagList(icon("layer-group"), " Taxonómica"),
    value = "taxo",
    layout_columns(
      col_widths = 12,
      mod_riqueza_ui("riqueza"),
      mod_nmds_ui("nmds")
    )
  ),

  # ── Tab 2: Diversidad Filogenética ────────────────────────────────────────
  nav_panel(
    title = tagList(icon("sitemap"), " Filogenética"),
    value = "filo",
    mod_metrics_ui("phylo_metrics",
                   title  = "Diversidad Filogenética — SES (PD / MPD / MNTD)",
                   prefix = "")
  ),

  # ── Tab 3: Diversidad Funcional ───────────────────────────────────────────
  nav_panel(
    title = tagList(icon("gears"), " Funcional"),
    value = "fun",
    mod_metrics_ui("fun_metrics",
                   title  = "Diversidad Funcional — SES (fPD / fMPD / fMNTD)",
                   prefix = "f")
  ),

  # ── Tab 4: Beta Diversidad ────────────────────────────────────────────────
  nav_panel(
    title = tagList(icon("table-cells"), " Beta Diversidad"),
    value = "beta",
    mod_beta_ui("beta")
  ),

  # ── Elementos de navbar ───────────────────────────────────────────────────
  nav_spacer(),

  nav_item(
    tags$a(
      href   = "https://github.com/lobatojorge/TeideSpiders",
      target = "_blank",
      class  = "nav-link d-flex align-items-center gap-1",
      icon("github"), "GitHub"
    )
  ),

  # ── Footer ────────────────────────────────────────────────────────────────
  footer = tags$div(
    class = "app-footer text-muted",
    "TeideSpiders · Universidad de La Laguna · ",
    tags$a(href = "https://github.com/lobatojorge/TeideSpiders/blob/main/LICENSE",
           "MIT License")
  )
)

# ── Server ───────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Reactives sobre datos pre-cargados (trivialmente baratos)
  aranas_r    <- reactive(app_data$app_aranas)
  nmds_r      <- reactive(app_data$app_nmds)
  ses_phylo_r <- reactive(app_data$app_ses_phylo)
  ses_fun_r   <- reactive(app_data$app_ses_fun)
  beta_r      <- reactive(app_data$app_beta)

  # Instanciar módulos
  mod_riqueza_server("riqueza",       aranas_r)
  mod_nmds_server("nmds",             nmds_r)
  mod_metrics_server("phylo_metrics", ses_phylo_r, prefix = "")
  mod_metrics_server("fun_metrics",   ses_fun_r,   prefix = "f")
  mod_beta_server("beta",             beta_r)
}

shinyApp(ui, server)
