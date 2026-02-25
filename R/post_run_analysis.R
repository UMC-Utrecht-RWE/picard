paths <- "/Users/mcinelli/repos/RSV-1026/logs"
read_pipeline_logs <- function(
  paths,
  tz = "Europe/Amsterdam",
  pattern = "\\.log$",
  recursive = TRUE,
  fill_forward = TRUE,
  keep_unparsed = FALSE
) {
  if (base::length(paths) == 1L && base::dir.exists(paths)) {
    paths <- base::list.files(
      paths,
      pattern = pattern,
      full.names = TRUE,
      recursive = recursive
    )
  }

  stopifnot(base::length(paths) > 0L)
  paths
}
tz <- "Europe/Amsterdam"

paths <- read_pipeline_logs(paths)
path_low <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_low.log"
path_nor <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_normal.log"
path_hig <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_high.log"
df <- readr::read_delim(
  file = path_hig,
  delim = "|",
  col_names = FALSE,
  trim_ws = TRUE,
  show_col_types = FALSE,
  progress = FALSE
)
n <- ncol(df)

names(df) <- if (n == 3L) {
  c("timestamp", "level", "message")
} else if (n == 6L) {
  c("timestamp", "level", "run_time", "script_time", "step_script", "message")
} else if (n == 9L) {
  c(
    "timestamp", "level", "run_time", "step_time", "script_time", "delta_time",
    "step_script", "message", "hash"
  )
} else {
  stop("Unexpected number of columns in log file.")
}

df <- dplyr::mutate(
  df,
  ts = as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%S", tz = tz),
  file = basename(path_hig)
)
