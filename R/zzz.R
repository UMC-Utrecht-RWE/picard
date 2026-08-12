# Package initialization hook
#
# This file (named zzz.R by convention) contains the .onLoad hook
# that R calls when the package is loaded. It initializes all registries
# used by load(), save(), and plot_data_features().
#
# For .init_reader_registry/.init_writer_registry/.init_plotter_registry
# each clear-then-rebuild their registry, so they must stay idempotent:
# .onLoad can run more than once per R session (e.g. devtools::load_all(),
# or a package reload between test files) and a non-idempotent init would
# leave stale or duplicated entries behind.
.onLoad <- function(libname, pkgname) {
  # Initialize reader registry (from load.R)
  .init_reader_registry()

  # Initialize writer registry (from save.R)
  .init_writer_registry()

  # Initialize plotter registry (from plot_data.R)
  .init_plotter_registry()

  invisible(NULL)
}

# Suppress R CMD check notes for non-standard evaluation. Not part of the
# package's documented API.
utils::globalVariables(c(
  # data.table's non-standard evaluation
  ".", # data.table's .() syntax
  ".SD", # Subset of Data
  ".N", # Number of rows
  ".I", # Row indices
  ".GRP", # Group counter
  ".BY", # List of by values

  # Columns used only inside analyze_pipeline_log() (R/post_run_analysis.R)
  "alert_summary",
  "clean_line",
  "delta_s",
  "duration_s",
  "end_run_s",
  "entry_type",
  "gap_label",
  "gap_s",
  "line_id",
  "max_gap_s",
  "midpoint_s",
  "min_start",
  "n_blocks",
  "n_logs",
  "pct_of_logged_run",
  "raw_line",
  "run_s",
  "script_display",
  "script_label",
  "script_s",
  "start_run_s",
  "step_block_id",
  "structured_entries",
  "timestamp",
  "timestamp_chr",
  "total_script_s",
  "total_step_s",
  "unstructured_entries",
  "verbosity",
  "verbosity_rank",
  "warning_entries",

  # NOTE: these are also ordinary parameter/local names elsewhere in the
  # package (e.g. `message`/`level` in the logging helpers, `n` and `step`
  # in the pipeline runners, `hash` in track_file_changes()). Whitelisting
  # them here suppresses "no visible binding" checks package-wide, not
  # just at their NSE use sites below, so a real undefined-variable bug
  # using one of these names elsewhere in the package would not be caught
  # by R CMD check. Prefer .data$<col> (or a narrower NSE pattern) over
  # adding more names to this group.
  "hash",
  "level",
  "message",
  "n",
  "script",
  "step",
  "column",
  "x",

  # ggplot2/rlang data-mask pronoun (used as bare `.data` in R/plot_data.R,
  # without an explicit rlang import)
  ".data",

  # for file R/plot_data.R
  "pct_missing"
))
