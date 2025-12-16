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
