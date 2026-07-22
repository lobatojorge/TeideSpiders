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
  library(arrow)
})

# -----------------------------------------------------------------------------
#' Carga y limpia el dataset principal de arañas (con ingesta defensiva)
#'
#' 1. Si existe el archivo Parquet procesado, lo lee directamente (más rápido).
#' 2. Si no, lee el Excel crudo, elimina columnas no informativas y filtra NA.
#' 3. Si tampoco existe el crudo (ej. GitHub Actions), lee la dummy data en Parquet.
#'
#' @param path Ruta al archivo crudo Excel (alias config.R).
#' @param path_parquet Ruta al archivo Parquet procesado (alias config.R).
#' @param path_dummy Ruta al archivo Parquet dummy (alias config.R).
#' @param extra_drop Vector opcional de nombres de columna extra a eliminar.
#' @return Un tibble limpio.
# -----------------------------------------------------------------------------
load_aranas <- function(path = PATH_ARANAS_RAW, 
                        path_parquet = PATH_ARANAS_PARQUET, 
                        path_dummy = PATH_ARANAS_DUMMY,
                        extra_drop = NULL) {

  # 1. Carga rápida desde Parquet procesado real
  if (file.exists(path_parquet)) {
    df <- arrow::read_parquet(path_parquet)
    if (!is.null(extra_drop)) df <- dplyr::select(df, -dplyr::any_of(extra_drop))
    return(df)
  }

  # 2. Fallback a Excel crudo (y genera limpieza al vuelo)
  if (file.exists(path)) {
    df <- readxl::read_excel(path)
    to_drop <- c(COLS_DROP, extra_drop)
    df <- dplyr::select(df, -dplyr::any_of(to_drop)) |>
      dplyr::rename(Año = Año2) |>
      dplyr::mutate(N_exx. = as.numeric(N_exx.)) |>
      tidyr::drop_na()
    return(df)
  }

  # 3. Fallback a Dummy Data (CI/CD)
  if (file.exists(path_dummy)) {
    warning("Datos reales no encontrados. Cargando DUMMY DATA. El CI/CD o la App están corriendo en modo demo.")
    df <- arrow::read_parquet(path_dummy)
    if (!is.null(extra_drop)) df <- dplyr::select(df, -dplyr::any_of(extra_drop))
    return(df)
  }

  stop("ERROR CRÍTICO: No se encontraron datos reales ni dummy. Ejecuta data/create_dummy_data.R")
}

# -----------------------------------------------------------------------------
load_traits <- function(path = PATH_TRAITS_RAW,
                        path_parquet = PATH_TRAITS_PARQUET,
                        path_dummy = PATH_TRAITS_DUMMY) {
  if (file.exists(path_parquet)) return(arrow::read_parquet(path_parquet))
  if (file.exists(path)) {
    return(
      readxl::read_excel(path) |>
        dplyr::mutate(Body_Size  = as.numeric(Body_Size),
                      Leg_Length = as.numeric(Leg_Length)) |>
        dplyr::rename(species = Taxon)
    )
  }
  if (file.exists(path_dummy)) {
    warning("Cargando traits DUMMY.")
    return(arrow::read_parquet(path_dummy))
  }
  stop("ERROR: Faltan datos reales y dummy de traits.")
}

# -----------------------------------------------------------------------------
load_zonas <- function(path = PATH_ZONAS_RAW,
                       path_parquet = PATH_ZONAS_PARQUET,
                       path_dummy = PATH_ZONAS_DUMMY) {
  if (file.exists(path_parquet)) return(arrow::read_parquet(path_parquet))
  if (file.exists(path)) {
    return(
      readxl::read_excel(path) |>
        dplyr::rename(año = año1) |>
        dplyr::mutate(año = as.character(año))
    )
  }
  if (file.exists(path_dummy)) {
    warning("Cargando zonas DUMMY.")
    return(arrow::read_parquet(path_dummy))
  }
  stop("ERROR: Faltan datos reales y dummy de zonas.")
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
