# =============================================================================
# setup.R — Inicialización del entorno del proyecto (ejecutar UNA sola vez)
# =============================================================================
# Pasos:
#   1. Mover archivos de datos a data/
#   2. Instalar renv y capturar snapshot de paquetes
# =============================================================================

# ── 1. Crear directorio de datos ─────────────────────────────────────────────
if (!dir.exists("data")) dir.create("data")

cat("
╔══════════════════════════════════════════════════════════════╗
║  PASO 1: Copiar archivos de datos a data/                   ║
╠══════════════════════════════════════════════════════════════╣
║  Origen original → Destino en data/                         ║
║  F:/TFM/arañas.xlsx            → data/arañas.xlsx           ║
║  F:/TFM/.../matrizTraits.xlsx  → data/matrizTraits.xlsx     ║
║  F:/TFM/.../zonas.xlsx         → data/zonas.xlsx            ║
║  F:/TFM/.../RAxML_bestTree.*   → data/RAxML_bestTree.result ║
╚══════════════════════════════════════════════════════════════╝
")

# Copiar automáticamente si los orígenes existen
origenes <- list(
  list(from = "F:/TFM/arañas.xlsx",
       to   = "data/arañas.xlsx"),
  list(from = "F:/TFM/desde enero/Funcional/matrizTraits.xlsx",
       to   = "data/matrizTraits.xlsx"),
  list(from = "F:/TFM/desde enero/Funcional/zonas.xlsx",
       to   = "data/zonas.xlsx"),
  list(from = "F:/TFM/desde enero/Filogenetica/RAxML_bestTree.result",
       to   = "data/RAxML_bestTree.result")
)

for (o in origenes) {
  if (file.exists(o$from)) {
    file.copy(o$from, o$to, overwrite = TRUE)
    cat("✓ Copiado:", basename(o$from), "→", o$to, "\n")
  } else {
    cat("✗ No encontrado (copiar manualmente):", o$from, "\n")
  }
}

# ── 2. Crear indicador de raíz de proyecto ───────────────────────────────────
# here::here() lo detecta automáticamente vía .git, pero si no hay Git aún:
if (!file.exists(".here") && !file.exists(".git")) {
  file.create(".here")
  cat("✓ Creado .here (raíz de proyecto para here::here())\n")
}

# ── 3. Instalar y capturar entorno con renv ──────────────────────────────────
cat("\n── Inicializando renv ──\n")
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

# Inicializar sin modificar .Rprofile automáticamente
renv::init(bare = TRUE)

# Instalar todos los paquetes requeridos por el proyecto
paquetes <- c(
  # Datos
  "here", "readxl", "openxlsx",
  # Manipulación
  "dplyr", "tidyr", "tibble", "purrr",
  # Análisis ecológico
  "vegan", "BAT", "picante", "ape", "phytools",
  # ML y clustering
  "randomForest", "cluster", "dendextend", "factoextra",
  # Estadística
  "MASS", "car", "DHARMa", "emmeans",
  # Visualización
  "ggplot2", "showtext", "corrplot",
  # Reporting
  "knitr", "rmarkdown"
)

install.packages(paquetes[!paquetes %in% rownames(installed.packages())])

# Capturar snapshot para renv.lock (versionar en Git)
renv::snapshot()
cat("\n✓ renv.lock generado. Añadir a Git: git add renv.lock\n")

cat("\n══ Setup completado ══\n")
cat("Ejecuta a continuación:\n")
cat("  source('config.R'); source('analysis/01_taxo.R')\n")
cat("  source('config.R'); source('analysis/02_fun.R')\n")
cat("  source('config.R'); source('analysis/03_filo.R')\n")
cat("  quarto::quarto_render('reports/diversity_report.Qmd')\n")
