#' Package initialization hook
#'
#' This file (named zzz.R by convention) contains the .onLoad hook
#' that R calls when the package is loaded. It initializes all registries
#' used by read_data(), save_data(), and plot_data_features().
#'
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  # Initialize reader registry (from read_data.R)
  .init_reader_registry()

  # Initialize writer registry (from save_data.R)
  .init_writer_registry()

  # Initialize plotter registry (from plot_data.R)
  .init_plotter_registry()

  invisible(NULL)
}

#' Suppress R CMD check notes for data.table's non-standard evaluation
#' @name suppress_cmd_checks
#' @keywords internal
utils::globalVariables(c(
  # data.table's non-standard evaluation
  ".",      # data.table's .() syntax
  ".SD",    # Subset of Data
  ".N",     # Number of rows
  ".I",     # Row indices
  ".GRP",   # Group counter
  ".BY"     # List of by values

  # Add unquoted column names here if needed:
  # "column_name",
  # "another_column"
))
