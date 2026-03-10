
rm(list = ls())

get_pipeline_logs <- function(
  directory,
  pattern = "\\.log$",
  recursive = TRUE
) {
  if (base::length(directory) == 1L && base::dir.exists(directory)) {
    paths <- base::list.files(
      directory,
      pattern = pattern,
      full.names = TRUE,
      recursive = recursive
    )
  }
  stopifnot(base::length(paths) > 0L)
  paths
}


load_log_dt <- function(path, tz = "Europe/Amsterdam") {
  dt <- data.table::fread(
    file = path,
    sep = "|",
    header = FALSE,
    fill = TRUE,
    strip.white = TRUE,
    data.table = TRUE
  )

  n <- base::ncol(dt)

  if (n == 3L) {
    data.table::setnames(dt, c("timestamp", "level", "message"))
  } else if (n == 6L) {
    data.table::setnames(
      dt,
      c("timestamp", "level", "run_time", "script_time",
        "step_script", "message")
    )
  } else if (n == 9L) {
    data.table::setnames(
      dt,
      c("timestamp", "level", "run_time", "step_time",
        "script_time", "delta_time", "step_script",
        "message", "hash")
    )
  } else {
    base::stop("Unexpected number of columns in log file.")
  }
  data.table::set(
    dt,
    j = "timestamp",
    value = base::as.POSIXct(
      dt[["timestamp"]],
      format = "%Y-%m-%d %H:%M:%S",
      tz = tz
    )
  )
  dt
}

parse_log_dt <- function(dt) {
  # Placeholder for any additional parsing or processing of the data.table
  dt
}
tz <- "Europe/Amsterdam"
path_low <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_low.log"
path_nor <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_normal.log"
path_hig <- "/Users/mcinelli/repos/RSV-1026/logs/pipeline_high.log"

directory <- "/Users/mcinelli/repos/RSV-1026/logs"
paths <- get_pipeline_logs(directory = directory)
dt_hig <- load_log_dt(path_hig)


extract_seconds <- function(x) {
  if (base::is.numeric(x)) return(x)
  y <- base::sub("^[^0-9]*", "", x)
  y <- base::sub("s.*$", "", y)
  base::suppressWarnings(base::as.numeric(y))
}

parse_log_dt <- function(dt) {

}

need <- c("run_time", "step_time", "script_time", "delta_time",
          "step_script", "hash")
miss <- need[!need %in% base::names(dt)]
if (base::length(miss) > 0L) {
  for (nm in miss) data.table::set(dt, j = nm, value = NA_character_)
}

dt[, c("step", "script") := data.table::tstrsplit(
  step_script,
  "/",
  fixed = TRUE
)]

data.table::set(dt, j = "run_s", value = extract_seconds(dt[["run_time"]]))
data.table::set(dt, j = "step_s", value = extract_seconds(dt[["step_time"]]))
data.table::set(dt, j = "scr_s", value = extract_seconds(dt[["script_time"]]))
data.table::set(dt, j = "d_s", value = extract_seconds(dt[["delta_time"]]))

prev <- data.table::shift(dt[["run_s"]], fill = -base::Inf)
reset <- !base::is.na(dt[["run_s"]]) & (dt[["run_s"]] < prev)
data.table::set(dt, j = "run_id", value = base::cumsum(reset) + 1L)

dt


summarise_times_dt <- function(dt) {}
dt_ok <- dt[!base::is.na(run_s) & !base::is.na(step_script)]

run_totals <- dt_ok[
,
.(
start_ts = base::min(timestamp, na.rm = TRUE),
end_ts = base::max(timestamp, na.rm = TRUE),
total_run_s = base::max(run_s, na.rm = TRUE)
),
by = .(file, run_id)
]

step_totals <- dt_ok[
,
.(
step_run_s = base::max(run_s, na.rm = TRUE) -
base::min(run_s, na.rm = TRUE)
),
by = .(file, run_id, step)
][order(file, run_id, -step_run_s)]

dt_ok[, script_block := data.table::rleid(step_script), by = .(file, run_id)]

script_blocks <- dt_ok[
,
.(
block_s = base::max(run_s, na.rm = TRUE) -
base::min(run_s, na.rm = TRUE)
),
by = .(file, run_id, step, script, script_block)
]

script_totals <- script_blocks[
,
.(script_run_s = base::sum(block_s, na.rm = TRUE)),
by = .(file, run_id, step, script)
][order(file, run_id, -script_run_s)]

list(
run_totals = run_totals,
step_totals = step_totals,
script_totals = script_totals
)
