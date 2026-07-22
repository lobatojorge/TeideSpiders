# =============================================================================
# R/data_prep.R — Módulo de carga y preparación de datos
# =============================================================================
# Funciones compartidas por 01_taxo.R, 02_fun.R y 03_filo.R.
# Requiere que config.R haya sido cargado previamente.
# =============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(tibble)
})

# -----------------------------------------------------------------------------
#' Carga y limpia arañas.xlsx
#'
#' @param path  Ruta al archivo Excel (default: PATH_ARANAS de config.R)
#' @param extra_drop  Columnas adicionales a eliminar (character vector)
#' @return tibble con columnas: Código_localidad, Año, Taxon, N_exx., Muestreo
#'
#' Correcciones aplicadas:
#'   - Unifica las 3 versiones distintas de limpieza presentes en los scripts
#'     originales (taxo.R L22-36, fun.R L88-98, filo.R L23-29).
#'   - Siempre renombra Año2 → Año (consistencia entre scripts).
#'   - drop_na() en lugar de complete.cases() (más legible, mismo efecto).
# -----------------------------------------------------------------------------
load_aranas <- function(path       = PATH_ARANAS,
                        extra_drop = character(0)) {
  drop <- unique(c(COLS_DROP, extra_drop))
  readxl::read_excel(path) |>
    dplyr::select(-dplyr::any_of(drop)) |>
    dplyr::rename(Año = Año2) |>
    dplyr::mutate(N_exx. = as.numeric(N_exx.)) |>
    tidyr::drop_na()
}

# -----------------------------------------------------------------------------
#' Construye matriz sitio × especie en presencia/ausencia
#'
#' @param df      data.frame con columnas: id_col, "Taxon", "N_exx."
#' @param id_col  Nombre de la columna identificadora de sitio (string)
#' @return data.frame con rownames = id_col, columnas = especies, valores 0/1
#'
#' Correcciones aplicadas:
#'   - Elimina el bloque duplicado en fun.R (L101-117) y filo.R (L32-54).
#'   - Corrige B2 (taxo.R L170): no hay doble eliminación de columna; el
#'     id_col se convierte directamente en rownames, nunca en [,-1].
#'   - Presencia/ausencia vía `as.integer(. > 0L)`, sin asignación ambigua.
#'   - pivot_wider con argumentos explícitamente nombrados (corrige B8).
# -----------------------------------------------------------------------------
build_samp <- function(df, id_col = "LocAño") {
  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(id_col, "Taxon")))) |>
    dplyr::summarise(Abundance = sum(N_exx., na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(
      id_cols     = dplyr::all_of(id_col),   # argumento nombrado (corrige B8)
      names_from  = "Taxon",
      values_from = "Abundance",
      values_fill = 0L
    ) |>
    tibble::column_to_rownames(var = id_col) |>
    as.data.frame() |>
    dplyr::mutate(dplyr::across(dplyr::everything(),
                                ~ as.integer(. > 0L)))
}

# -----------------------------------------------------------------------------
#' Patrón cache-or-compute para operaciones costosas (ses.pd, ses.mpd, ses.mntd)
#'
#' @param cache_file  Ruta al archivo .rds de caché
#' @param expr        Expresión entre quote() o llaves {} a evaluar si no hay caché
#' @return Objeto R (leído de caché o calculado)
#'
#' Uso:
#'   SES_PD <- cache_or_run(
#'     file.path(CACHE_DIR, "SES_PD.rds"),
#'     { set.seed(SEED); picante::ses.pd(samp, pt, ...) }
#'   )
#'
#' Para invalidar caché: borrar el .rds o el directorio output/cache/.
# -----------------------------------------------------------------------------
cache_or_run <- function(cache_file, expr) {
  if (file.exists(cache_file)) {
    message("[cache] Leyendo: ", basename(cache_file))
    readRDS(cache_file)
  } else {
    message("[cache] Calculando: ", basename(cache_file), " ...")
    result <- force(expr)
    saveRDS(result, cache_file)
    message("[cache] Guardado: ", basename(cache_file))
    result
  }
}
