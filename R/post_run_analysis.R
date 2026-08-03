#' Analyse a pipeline log and surface runtime bottlenecks
#'
#' @description
#' This function reads a PICARD pipeline log, defaults to the latest
#' `pipeline_*.log` in `log_dir`, and returns a compact analysis bundle.
#' For `Normal` and `High` verbosity logs it estimates the slowest steps
#' and scripts; for `High` verbosity logs it also highlights the longest
#' silent gaps between log entries.
#'
#' When `create_plots` or `write_tables` is `TRUE`, the function writes
#' outputs to an analysis folder next to the selected log.
#'
#' @param log_file Optional path to a specific log file. If `NULL`,
#' the most recent `pipeline_*.log` found in `log_dir` is used.
#' @param log_dir Directory containing pipeline logs. Default `"logs"`.
#' @param pattern Pattern used to discover pipeline logs.
#' Default `"^pipeline_.*\\\\.log$"`.
#' @param output_dir Optional output directory for plots and tables.
#' If `NULL`, an `analysis/<log_name>` folder is created next to the log.
#' @param tz Time zone used to parse timestamps.
#' Default `"Europe/Amsterdam"`.
#' @param top_n Number of rows to keep in ranked summaries and bottleneck plots.
#' Default `10`.
#' @param create_plots Logical. If `TRUE`, save diagnostic plots.
#' Default `TRUE`.
#' @param write_tables Logical. If `TRUE`, save summary tables as CSV files.
#' Default `TRUE`.
#' @return A named list with the selected log path, parsed entries,
#' file-level summary, and analysis tables.
#' @export
analyze_pipeline_log <- function(
  log_file = NULL,
  log_dir = "logs",
  pattern = "^pipeline_.*\\.log$",
  output_dir = NULL,
  tz = "Europe/Amsterdam",
  top_n = 10,
  create_plots = TRUE,
  write_tables = TRUE
) {
  if (!base::is.null(log_file)) {
    if (!base::is.character(log_file) || base::length(log_file) != 1L) {
      stop("log_file must be NULL or a single character path.", call. = FALSE)
    }
    log_file <- fs::path_norm(log_file)
    if (!base::file.exists(log_file)) {
      stop("Log file not found: ", log_file, call. = FALSE)
    }
  } else {
    log_file <- .latest_pipeline_log(
      log_dir = log_dir,
      pattern = pattern
    )
  }

  if (!base::is.character(top_n) && !base::is.numeric(top_n)) {
    stop("top_n must be numeric.", call. = FALSE)
  }
  top_n <- base::as.integer(top_n[[1]])
  if (base::is.na(top_n) || top_n < 1L) {
    stop("top_n must be a positive integer.", call. = FALSE)
  }

  parsed_log <- .read_pipeline_log(
    log_file = log_file,
    tz = tz
  )

  structured_log <- parsed_log[entry_type == "structured"]

  run_summary <- .summarise_log_file(
    parsed_log = parsed_log,
    structured_log = structured_log,
    log_file = log_file
  )
  level_summary <- .summarise_levels(structured_log = structured_log)
  alert_summary <- .summarise_alerts(structured_log = structured_log)
  step_blocks <- .build_step_blocks(structured_log = structured_log)
  step_summary <- .summarise_steps(
    step_blocks = step_blocks,
    structured_log = structured_log
  )
  script_blocks <- .build_script_blocks(structured_log = structured_log)
  script_summary <- .summarise_scripts(
    script_blocks = script_blocks,
    structured_log = structured_log
  )
  gap_summary <- .summarise_gaps(
    structured_log = structured_log,
    top_n = top_n
  )
  unstructured_lines <- .summarise_unstructured(parsed_log = parsed_log)

  summary_files <- character(0)
  plot_files <- character(0)

  if (isTRUE(create_plots) || isTRUE(write_tables)) {
    output_dir <- .analysis_output_dir(
      log_file = log_file,
      output_dir = output_dir
    )
  }

  if (isTRUE(write_tables)) {
    summary_files <- .write_analysis_tables(
      output_dir = output_dir,
      run_summary = run_summary,
      level_summary = level_summary,
      alert_summary = alert_summary,
      step_summary = step_summary,
      script_summary = script_summary,
      gap_summary = gap_summary,
      unstructured_lines = unstructured_lines
    )
  }

  if (isTRUE(create_plots)) {
    plot_files <- .write_analysis_plots(
      output_dir = output_dir,
      level_summary = level_summary,
      step_blocks = step_blocks,
      step_summary = step_summary,
      script_blocks = script_blocks,
      script_summary = script_summary,
      gap_summary = gap_summary,
      top_n = top_n
    )
  }

  list(
    log_file = log_file,
    output_dir = output_dir,
    parsed_log = parsed_log,
    run_summary = run_summary,
    level_summary = level_summary,
    alert_summary = alert_summary,
    step_blocks = step_blocks,
    step_summary = step_summary,
    script_blocks = script_blocks,
    script_summary = script_summary,
    gap_summary = gap_summary,
    unstructured_lines = unstructured_lines,
    summary_files = summary_files,
    plot_files = plot_files
  )
}


.latest_pipeline_log <- function(
  log_dir = "logs",
  pattern = "^pipeline_.*\\.log$",
  recursive = TRUE
) {
  if (!base::is.character(log_dir) || base::length(log_dir) != 1L) {
    stop("log_dir must be a single character path.", call. = FALSE)
  }

  log_dir <- fs::path_norm(log_dir)
  if (!base::dir.exists(log_dir)) {
    stop("Log directory not found: ", log_dir, call. = FALSE)
  }

  paths <- base::list.files(
    path = log_dir,
    pattern = pattern,
    full.names = TRUE,
    recursive = recursive
  )

  if (base::length(paths) == 0L) {
    stop(
      "No pipeline logs found in: ", log_dir,
      call. = FALSE
    )
  }

  info <- base::file.info(paths)
  ord <- base::order(info$mtime, decreasing = TRUE, na.last = TRUE)
  paths[[ord[[1L]]]]
}


.analysis_output_dir <- function(log_file, output_dir = NULL) {
  if (base::is.null(output_dir)) {
    output_dir <- base::file.path(
      base::dirname(log_file),
      "analysis",
      tools::file_path_sans_ext(base::basename(log_file))
    )
  }

  output_dir <- fs::path_norm(output_dir)
  if (!base::dir.exists(output_dir)) {
    base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  output_dir
}


.strip_ansi <- function(x) {
  base::gsub("\033\\[[0-9;]*m", "", x, perl = TRUE)
}


.parse_with_pattern <- function(line, pattern, field_names) {
  match_obj <- base::regexec(pattern, line, perl = TRUE)
  match_data <- base::regmatches(line, match_obj)[[1]]

  if (base::length(match_data) == 0L) {
    return(NULL)
  }

  parsed <- stats::setNames(
    base::as.list(match_data[-1L]),
    field_names
  )
  parsed
}


.parse_log_line <- function(line, line_id) {
  clean_line <- .strip_ansi(line)

  high_fields <- c(
    "timestamp_chr", "level", "run_time", "step_time",
    "script_time", "delta_time", "step_script", "message", "hash"
  )
  high_pattern <- base::paste0(
    "^(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})",
    " \\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*(.*)\\s*",
    "\\|\\s*(.*)$"
  )

  normal_fields <- c(
    "timestamp_chr", "level", "run_time",
    "script_time", "step_script", "message"
  )
  normal_pattern <- base::paste0(
    "^(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})",
    " \\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*([^|]+?)\\s*",
    "\\|\\s*(.*)$"
  )

  low_fields <- c("timestamp_chr", "level", "message")
  low_pattern <- base::paste0(
    "^(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})",
    " \\|\\s*([^|]+?)\\s*",
    "\\|\\s*(.*)$"
  )

  parsed <- .parse_with_pattern(clean_line, high_pattern, high_fields)
  if (!base::is.null(parsed)) {
    return(c(
      list(
        line_id = line_id,
        raw_line = line,
        clean_line = clean_line,
        entry_type = "structured",
        verbosity = "High"
      ),
      parsed
    ))
  }

  parsed <- .parse_with_pattern(clean_line, normal_pattern, normal_fields)
  if (!base::is.null(parsed)) {
    return(c(
      list(
        line_id = line_id,
        raw_line = line,
        clean_line = clean_line,
        entry_type = "structured",
        verbosity = "Normal",
        step_time = NA_character_,
        delta_time = NA_character_,
        hash = NA_character_
      ),
      parsed
    ))
  }

  parsed <- .parse_with_pattern(clean_line, low_pattern, low_fields)
  if (!base::is.null(parsed)) {
    return(c(
      list(
        line_id = line_id,
        raw_line = line,
        clean_line = clean_line,
        entry_type = "structured",
        verbosity = "Low",
        run_time = NA_character_,
        step_time = NA_character_,
        script_time = NA_character_,
        delta_time = NA_character_,
        step_script = NA_character_,
        hash = NA_character_
      ),
      parsed
    ))
  }

  list(
    line_id = line_id,
    raw_line = line,
    clean_line = clean_line,
    entry_type = "unstructured",
    verbosity = NA_character_,
    timestamp_chr = NA_character_,
    level = NA_character_,
    run_time = NA_character_,
    step_time = NA_character_,
    script_time = NA_character_,
    delta_time = NA_character_,
    step_script = NA_character_,
    message = base::trimws(clean_line),
    hash = NA_character_
  )
}


.read_pipeline_log <- function(log_file, tz = "Europe/Amsterdam") {
  lines <- base::readLines(log_file, warn = FALSE, encoding = "UTF-8")
  if (base::length(lines) == 0L) {
    stop("Log file is empty: ", log_file, call. = FALSE)
  }

  parsed <- data.table::rbindlist(
    lapply(seq_along(lines), function(i) {
      .parse_log_line(line = lines[[i]], line_id = i)
    }),
    fill = TRUE
  )

  if (parsed[entry_type == "structured", .N] == 0L) {
    stop("No structured log entries found in: ", log_file, call. = FALSE)
  }

  data.table::set(
    parsed,
    j = "timestamp",
    value = base::as.POSIXct(
      parsed[["timestamp_chr"]],
      format = "%Y-%m-%d %H:%M:%S",
      tz = tz
    )
  )

  data.table::set(
    parsed,
    j = "run_s", value = .extract_seconds(parsed[["run_time"]])
  )
  data.table::set(
    parsed,
    j = "delta_s", value = .extract_seconds(parsed[["delta_time"]])
  )

  step_parts <- .split_step_script(parsed[["step_script"]])
  data.table::set(parsed, j = "step", value = step_parts$step)
  data.table::set(parsed, j = "script", value = step_parts$script)
  data.table::set(parsed, j = "script_label", value = step_parts$script_label)

  data.table::set(
    parsed,
    j = "verbosity_rank",
    value = .verbosity_rank(parsed[["verbosity"]])
  )

  parsed[]
}


.extract_seconds <- function(x) {
  out <- base::rep(NA_real_, base::length(x))
  x <- base::trimws(base::as.character(x))

  ok <- !base::is.na(x) & base::grepl("-?[0-9]+(\\.[0-9]+)?", x)
  out[ok] <- base::as.numeric(
    base::sub(
      "^.*?(-?[0-9]+(?:\\.[0-9]+)?).*$",
      "\\1",
      x[ok]
    )
  )
  out
}


.split_step_script <- function(x) {
  x <- base::trimws(base::as.character(x))

  step <- base::rep(NA_character_, base::length(x))
  script <- base::rep(NA_character_, base::length(x))
  script_label <- base::rep(NA_character_, base::length(x))

  ok <- !base::is.na(x) & nzchar(x)
  sep <- base::regexpr("/", x, fixed = TRUE)
  has_sep <- ok & sep > 0L

  step[has_sep] <- base::substr(x[has_sep], 1L, sep[has_sep] - 1L)
  script[has_sep] <- base::substr(
    x[has_sep],
    sep[has_sep] + 1L,
    base::nchar(x[has_sep])
  )

  step[ok & !has_sep] <- x[ok & !has_sep]
  script_label[ok] <- x[ok]

  has_script <- !base::is.na(script) & nzchar(script)
  script_label[has_script] <- base::basename(script[has_script])

  list(
    step = .na_if_blank(step),
    script = .na_if_blank(script),
    script_label = .na_if_blank(script_label)
  )
}


.na_if_blank <- function(x) {
  x <- base::as.character(x)
  x[base::is.na(x) | !nzchar(base::trimws(x))] <- NA_character_
  x
}


.verbosity_rank <- function(x) {
  rank_map <- c("Low" = 1L, "Normal" = 2L, "High" = 3L)
  out <- unname(rank_map[x])
  out[base::is.na(out)] <- 0L
  base::as.integer(out)
}


.max_or_na <- function(x) {
  x <- x[base::is.finite(x)]
  if (base::length(x) == 0L) {
    return(NA_real_)
  }
  base::max(x)
}


.safe_unique_n <- function(x) {
  x <- x[!base::is.na(x) & nzchar(base::trimws(x)) & x != "-"]
  data.table::uniqueN(x)
}


.has_context <- function(x) {
  !base::is.na(x) & nzchar(base::trimws(x)) & x != "-"
}


.summarise_log_file <- function(parsed_log, structured_log, log_file) {
  max_rank <- .max_or_na(structured_log[["verbosity_rank"]])
  verbosity <- c(NA_character_, "Low", "Normal", "High")[[max_rank + 1L]]

  start_ts <- structured_log[["timestamp"]]
  start_ts <- start_ts[!base::is.na(start_ts)]

  logged_run_s <- .max_or_na(structured_log[["run_s"]])
  wall_clock_s <- NA_real_

  if (base::length(start_ts) > 0L) {
    wall_clock_s <- base::as.numeric(
      base::difftime(
        base::max(start_ts),
        base::min(start_ts),
        units = "secs"
      )
    )
  }

  data.table::data.table(
    log_file = log_file,
    log_name = base::basename(log_file),
    verbosity = verbosity,
    structured_entries = structured_log[, .N],
    unstructured_entries = parsed_log[entry_type == "unstructured", .N],
    started_at = if (base::length(start_ts) > 0L) {
      base::min(start_ts)
    } else {
      base::as.POSIXct(NA)
    },
    ended_at = if (base::length(start_ts) > 0L) {
      base::max(start_ts)
    } else {
      base::as.POSIXct(NA)
    },
    wall_clock_s = wall_clock_s,
    logged_run_s = logged_run_s,
    warning_entries = structured_log[level == "WARN", .N],
    error_entries = structured_log[level %in% c("ERROR", "FATAL"), .N],
    unique_steps = .safe_unique_n(structured_log[["step"]]),
    unique_scripts = .safe_unique_n(structured_log[["script_label"]])
  )
}


.summarise_levels <- function(structured_log) {
  structured_log[
    ,
    .(n = .N),
    by = "level"
  ][order(-n, level)]
}


.summarise_alerts <- function(structured_log) {
  structured_log[
    level %in% c("WARN", "ERROR", "FATAL"),
    .(n = .N),
    by = c("level", "message")
  ][order(-n, level, message)]
}


.build_step_blocks <- function(structured_log) {
  step_dt <- structured_log[
    !base::is.na(run_s) & .has_context(step)
  ]

  if (step_dt[, .N] == 0L) {
    return(data.table::data.table())
  }

  step_dt <- data.table::copy(step_dt)
  data.table::set(
    step_dt,
    j = "step_block_id",
    value = data.table::rleid(step_dt[["step"]])
  )

  step_dt[
    ,
    .(
      start_ts = base::min(timestamp, na.rm = TRUE),
      end_ts = base::max(timestamp, na.rm = TRUE),
      start_run_s = base::min(run_s, na.rm = TRUE),
      end_run_s = base::max(run_s, na.rm = TRUE),
      duration_s = base::max(run_s, na.rm = TRUE) -
        base::min(run_s, na.rm = TRUE),
      n_logs = .N,
      max_gap_s = .max_or_na(delta_s)
    ),
    by = c("step_block_id", "step")
  ][order(start_run_s)]
}


.summarise_steps <- function(step_blocks, structured_log) {
  if (step_blocks[, .N] == 0L) {
    return(data.table::data.table())
  }

  logged_run_s <- .max_or_na(structured_log[["run_s"]])

  out <- step_blocks[
    ,
    .(
      total_step_s = base::sum(duration_s, na.rm = TRUE),
      n_blocks = .N,
      n_logs = base::sum(n_logs, na.rm = TRUE),
      longest_block_s = .max_or_na(duration_s),
      max_gap_s = .max_or_na(max_gap_s)
    ),
    by = "step"
  ][order(-total_step_s, step)]

  if (base::is.finite(logged_run_s) && !base::is.na(logged_run_s) &&
    logged_run_s > 0) {
    out[, pct_of_logged_run := total_step_s / logged_run_s]
  } else {
    out[, pct_of_logged_run := NA_real_]
  }

  out[]
}


.build_script_blocks <- function(structured_log) {
  script_dt <- structured_log[
    !base::is.na(run_s) & .has_context(script_label) & .has_context(step)
  ]

  if (script_dt[, .N] == 0L) {
    return(data.table::data.table())
  }

  script_dt <- data.table::copy(script_dt)
  data.table::set(
    script_dt,
    j = "script_block_id",
    value = data.table::rleid(script_dt[["step_script"]])
  )

  script_dt[
    ,
    .(
      start_ts = base::min(timestamp, na.rm = TRUE),
      end_ts = base::max(timestamp, na.rm = TRUE),
      start_run_s = base::min(run_s, na.rm = TRUE),
      end_run_s = base::max(run_s, na.rm = TRUE),
      duration_s = base::max(run_s, na.rm = TRUE) -
        base::min(run_s, na.rm = TRUE),
      n_logs = .N,
      max_gap_s = .max_or_na(delta_s)
    ),
    by = c("script_block_id", "step", "script", "script_label")
  ][order(start_run_s)]
}


.summarise_scripts <- function(script_blocks, structured_log) {
  if (script_blocks[, .N] == 0L) {
    return(data.table::data.table())
  }

  logged_run_s <- .max_or_na(structured_log[["run_s"]])

  out <- script_blocks[
    ,
    .(
      total_script_s = base::sum(duration_s, na.rm = TRUE),
      n_blocks = .N,
      n_logs = base::sum(n_logs, na.rm = TRUE),
      longest_block_s = .max_or_na(duration_s),
      max_gap_s = .max_or_na(max_gap_s)
    ),
    by = c("step", "script", "script_label")
  ][order(-total_script_s, step, script_label)]

  if (base::is.finite(logged_run_s) && !base::is.na(logged_run_s) &&
    logged_run_s > 0) {
    out[, pct_of_logged_run := total_script_s / logged_run_s]
  } else {
    out[, pct_of_logged_run := NA_real_]
  }

  out[]
}


.summarise_gaps <- function(structured_log, top_n = 10L) {
  gap_dt <- structured_log[
    !base::is.na(delta_s) & base::is.finite(delta_s) & delta_s > 0
  ]

  if (gap_dt[, .N] == 0L) {
    return(data.table::data.table())
  }

  gap_dt[
    order(-delta_s)
  ][
    seq_len(base::min(.N, top_n)),
    .(
      timestamp,
      run_s,
      gap_s = delta_s,
      step,
      script,
      script_label,
      message
    )
  ]
}


.summarise_unstructured <- function(parsed_log) {
  parsed_log[
    entry_type == "unstructured" &
      !base::is.na(message) &
      nzchar(base::trimws(message)),
    .(line_id, message)
  ]
}


.plot_path <- function(output_dir, file_name) {
  base::file.path(output_dir, file_name)
}


.base_analysis_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.minor = ggplot2::element_blank()
    )
}


.plot_level_summary <- function(level_summary) {
  if (level_summary[, .N] == 0L) {
    return(NULL)
  }

  ggplot2::ggplot(
    level_summary,
    ggplot2::aes(
      x = stats::reorder(level, n),
      y = n
    )
  ) +
    ggplot2::geom_col(fill = "steelblue") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Log levels",
      x = "Level",
      y = "Entries"
    ) +
    .base_analysis_theme()
}


.plot_step_summary <- function(step_summary, top_n = 10L) {
  if (step_summary[, .N] == 0L) {
    return(NULL)
  }

  plot_dt <- data.table::copy(step_summary[
    seq_len(base::min(.N, top_n))
  ])

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(
      x = stats::reorder(step, total_step_s),
      y = total_step_s
    )
  ) +
    ggplot2::geom_col(fill = "steelblue") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Slowest steps",
      subtitle = base::paste(
        "Top", base::min(nrow(plot_dt), top_n), "by run time"
      ),
      x = "Step",
      y = "Estimated duration (s)"
    ) +
    .base_analysis_theme()
}


.plot_script_summary <- function(script_summary, top_n = 10L) {
  if (script_summary[, .N] == 0L) {
    return(NULL)
  }

  plot_dt <- data.table::copy(script_summary[
    seq_len(base::min(.N, top_n))
  ])
  plot_dt[, script_display := base::paste(step, script_label, sep = " / ")]

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(
      x = stats::reorder(script_display, total_script_s),
      y = total_script_s
    )
  ) +
    ggplot2::geom_col(fill = "sienna3") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Slowest scripts",
      subtitle = base::paste(
        "Top", base::min(nrow(plot_dt), top_n), "by run time"
      ),
      x = "Script",
      y = "Estimated duration (s)"
    ) +
    .base_analysis_theme()
}


.plot_step_timeline <- function(step_blocks, gap_summary = NULL) {
  if (step_blocks[, .N] == 0L) {
    return(NULL)
  }

  plot_dt <- data.table::copy(step_blocks)
  plot_dt[, midpoint_s := start_run_s + ((end_run_s - start_run_s) / 2)]

  has_gaps <- !base::is.null(gap_summary) && gap_summary[, .N] > 0L

  p <- ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(
      x = start_run_s,
      xend = end_run_s,
      y = step,
      yend = step,
      color = step
    )
  ) +
    ggplot2::geom_segment(linewidth = 5, lineend = "round") +
    ggplot2::geom_text(
      ggplot2::aes(
        x = midpoint_s,
        label = base::sprintf("%.1fs", duration_s)
      ),
      color = "black",
      size = 3,
      vjust = -0.8,
      show.legend = FALSE
    )

  if (has_gaps) {
    p <- p + ggplot2::geom_vline(
      data = gap_summary,
      mapping = ggplot2::aes(xintercept = run_s),
      linetype = "dashed",
      color = "firebrick3",
      alpha = 0.6
    )
  }

  p +
    ggplot2::labs(
      title = "Step timeline",
      subtitle = if (has_gaps) {
        "Dashed lines mark the longest silent gaps"
      } else {
        NULL
      },
      x = "Run time (s)",
      y = "Step"
    ) +
    .base_analysis_theme() +
    ggplot2::theme(legend.position = "none")
}


.plot_script_timeline <- function(script_blocks) {
  if (script_blocks[, .N] == 0L) {
    return(NULL)
  }

  plot_dt <- data.table::copy(script_blocks)
  plot_dt[, midpoint_s := start_run_s + ((end_run_s - start_run_s) / 2)]

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(
      x = start_run_s,
      xend = end_run_s,
      y = script_label,
      yend = script_label,
      color = script_label
    )
  ) +
    ggplot2::geom_segment(linewidth = 5, lineend = "round") +
    ggplot2::geom_text(
      ggplot2::aes(
        x = midpoint_s,
        label = base::sprintf("%.1fs", duration_s)
      ),
      color = "black",
      size = 3,
      vjust = -0.8,
      show.legend = FALSE
    ) +
    ggplot2::facet_wrap(
      facets = ggplot2::vars(step),
      scales = "free_y",
      ncol = 1
    ) +
    ggplot2::labs(
      title = "Script timeline",
      subtitle = "Grouped by step",
      x = "Run time (s)",
      y = "Script"
    ) +
    .base_analysis_theme() +
    ggplot2::theme(legend.position = "none")
}


.plot_gap_summary <- function(gap_summary) {
  if (gap_summary[, .N] == 0L) {
    return(NULL)
  }

  plot_dt <- data.table::copy(gap_summary)
  plot_dt[
    ,
    gap_label := ifelse(
      .has_context(script_label),
      base::paste(step, script_label, sep = " / "),
      ifelse(.has_context(step), step, "outside script context")
    )
  ]

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(
      x = stats::reorder(gap_label, gap_s),
      y = gap_s
    )
  ) +
    ggplot2::geom_col(fill = "firebrick3") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Longest silent gaps",
      subtitle = "Largest deltas between consecutive log entries",
      x = "Context",
      y = "Gap (s)"
    ) +
    .base_analysis_theme()
}


.save_plot <- function(plot_obj, file_path, width = 10, height = 6) {
  if (base::is.null(plot_obj)) {
    return(NA_character_)
  }

  ggplot2::ggsave(
    filename = file_path,
    plot = plot_obj,
    width = width,
    height = height,
    units = "in",
    dpi = 150
  )
  file_path
}


.write_analysis_plots <- function(
  output_dir,
  level_summary,
  step_blocks,
  step_summary,
  script_blocks,
  script_summary,
  gap_summary,
  top_n = 10L
) {
  plot_paths <- c(
    level_summary = .save_plot(
      plot_obj = .plot_level_summary(level_summary),
      file_path = .plot_path(output_dir, "level_summary.png"),
      width = 8,
      height = 4.5
    ),
    step_summary = .save_plot(
      plot_obj = .plot_step_summary(step_summary, top_n = top_n),
      file_path = .plot_path(output_dir, "step_summary.png"),
      width = 10,
      height = 6
    ),
    script_summary = .save_plot(
      plot_obj = .plot_script_summary(script_summary, top_n = top_n),
      file_path = .plot_path(output_dir, "script_summary.png"),
      width = 11,
      height = 7
    ),
    step_timeline = .save_plot(
      plot_obj = .plot_step_timeline(step_blocks, gap_summary = gap_summary),
      file_path = .plot_path(output_dir, "step_timeline.png"),
      width = 11,
      height = 5
    ),
    script_timeline = .save_plot(
      plot_obj = .plot_script_timeline(script_blocks),
      file_path = .plot_path(output_dir, "script_timeline.png"),
      width = 11,
      height = 7
    ),
    gap_summary = .save_plot(
      plot_obj = .plot_gap_summary(gap_summary),
      file_path = .plot_path(output_dir, "gap_summary.png"),
      width = 10,
      height = 6
    )
  )

  plot_paths[!base::is.na(plot_paths)]
}


.write_analysis_tables <- function(
  output_dir,
  run_summary,
  level_summary,
  alert_summary,
  step_summary,
  script_summary,
  gap_summary,
  unstructured_lines
) {
  tables <- list(
    run_summary = run_summary,
    level_summary = level_summary,
    alert_summary = alert_summary,
    step_summary = step_summary,
    script_summary = script_summary,
    gap_summary = gap_summary,
    unstructured_lines = unstructured_lines
  )

  written <- character(0)
  for (nm in base::names(tables)) {
    dt <- tables[[nm]]
    if (base::is.null(dt) || dt[, .N] == 0L) {
      next
    }

    path <- .plot_path(output_dir, base::paste0(nm, ".csv"))
    data.table::fwrite(dt, file = path, na = "")
    written <- c(written, stats::setNames(path, nm))
  }

  written
}
