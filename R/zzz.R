#' Package initialization hook
#'
#' This file (named zzz.R by convention) contains the .onLoad hook
#' that R calls when the package is loaded. It initializes all registries
#' used by load(), save(), and plot_data_features().
#'
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  # Initialize reader registry (from load.R)
  .init_reader_registry()

  # Initialize writer registry (from save.R)
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
  ".BY",    # List of by values

  # Add unquoted column names here if needed:
  "alert_summary",
  "clean_line",
  "delta_s",
  "duration_s",
  "end_run_s",
  "entry_type",
  "gap_label",
  "gap_s",
  "hash",
  "level",
  "line_id",
  "max_gap_s",
  "message",
  "midpoint_s",
  "n",
  "n_blocks",
  "n_logs",
  "pct_of_logged_run",
  "raw_line",
  "run_s",
  "script",
  "script_display",
  "script_label",
  "script_s",
  "start_run_s",
  "step",
  "step_block_id",
  "step_s",
  "structured_entries",
  "timestamp",
  "timestamp_chr",
  "total_script_s",
  "total_step_s",
  "unstructured_entries",
  "verbosity",
  "verbosity_rank",
  "warning_entries",

  # Silence R CMD check NSE notes from ggplot2/rlang
  ".data",
  "x",
  "column",
  "pct_missing"
))
