# Analyse a pipeline log and surface runtime bottlenecks

This function reads a PICARD pipeline log, defaults to the latest
`pipeline_*.log` in `log_dir`, and returns a compact analysis bundle.
For `Normal` and `High` verbosity logs it estimates the slowest steps
and scripts; for `High` verbosity logs it also highlights the longest
silent gaps between log entries.

When `create_plots` or `write_tables` is `TRUE`, the function writes
outputs to an analysis folder next to the selected log.

## Usage

``` r
analyze_pipeline_log(
  log_file = NULL,
  log_dir = "logs",
  pattern = "^pipeline_.*\\.log$",
  output_dir = NULL,
  tz = "Europe/Amsterdam",
  top_n = 10,
  create_plots = TRUE,
  write_tables = TRUE
)
```

## Arguments

- log_file:

  Optional path to a specific log file. If `NULL`, the most recent
  `pipeline_*.log` found in `log_dir` is used.

- log_dir:

  Directory containing pipeline logs. Default `"logs"`.

- pattern:

  Pattern used to discover pipeline logs. Default
  `"^pipeline_.*\\\\.log$"`.

- output_dir:

  Optional output directory for plots and tables. If `NULL`, an
  `analysis/<log_name>` folder is created next to the log.

- tz:

  Time zone used to parse timestamps. Default `"Europe/Amsterdam"`.

- top_n:

  Number of rows to keep in ranked summaries and bottleneck plots.
  Default `10`.

- create_plots:

  Logical. If `TRUE`, save diagnostic plots. Default `TRUE`.

- write_tables:

  Logical. If `TRUE`, save summary tables as CSV files. Default `TRUE`.

## Value

A named list with the selected log path, parsed entries, file-level
summary, and analysis tables.
