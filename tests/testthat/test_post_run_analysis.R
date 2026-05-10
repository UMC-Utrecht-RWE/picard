testthat::test_that(
  "analyze_pipeline_log selects the latest log and writes analysis outputs", {
    temp_dir <- withr::local_tempdir()
    log_dir <- base::file.path(temp_dir, "logs")

    base::dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

    old_log <- base::file.path(log_dir, "pipeline_20000101_000000.log")
    base::writeLines("2000-01-01 00:00:00 | INFO  | old log", old_log)
    base::Sys.setFileTime(old_log, base::Sys.time() - 3600)

    withr::defer(picard:::.reset_logger_manager_instance())

    picard::track_file_changes(log_dir = log_dir, path = temp_dir)

    lm <- picard:::LoggerManager$new()
    lm$configure(log_dir = log_dir, verbose = "High")

    lm$start_step_logger("T2")
    logger::log_info("Step bootstrap")

    lm$start_script("scripts/substep_a.R")
    base::Sys.sleep(0.02)
    logger::log_info("Load source data")
    base::Sys.sleep(0.02)
    logger::log_warn("Potential slowdown")
    lm$end_script()

    lm$start_script("scripts/substep_b.R")
    base::Sys.sleep(0.02)
    logger::log_info("Transform data")
    lm$end_script()

    lm$start_capturing_prints(target = "global")
    withr::defer(
      try(lm$stop_capturing_prints(), silent = TRUE),
      envir = parent.frame()
    )
    base::cat("plain output line\n")
    lm$stop_capturing_prints()

    lm$end_step_logger()

    analysis <- picard::analyze_pipeline_log(
      log_dir = log_dir,
      top_n = 3
    )

    testthat::expect_equal(
      fs::path_norm(analysis$log_file),
      fs::path_norm(lm$global_log_file)
    )
    testthat::expect_equal(analysis$run_summary$verbosity[[1]], "High")
    testthat::expect_true("T2" %in% analysis$step_summary$step)
    testthat::expect_true(nrow(analysis$script_summary) >= 2)
    testthat::expect_true(nrow(analysis$gap_summary) >= 1)
    testthat::expect_true(
      "plain output line" %in% analysis$unstructured_lines$message
    )
    testthat::expect_named(
      analysis$summary_files,
      c(
        "run_summary", "level_summary", "alert_summary",
        "step_summary", "script_summary", "gap_summary",
        "unstructured_lines"
      )
    )
    testthat::expect_true(base::length(analysis$plot_files) >= 4L)
    testthat::expect_true(base::all(base::file.exists(analysis$plot_files)))
    testthat::expect_true(base::all(base::file.exists(analysis$summary_files)))
  }
)


testthat::test_that(
  "analyze_pipeline_log handles low-verbosity logs without timing outputs", {
    temp_dir <- withr::local_tempdir()
    log_dir <- base::file.path(temp_dir, "logs")

    withr::defer(picard:::.reset_logger_manager_instance())

    lm <- picard:::LoggerManager$new()
    lm$configure(log_dir = log_dir, verbose = "Low")
    logger::log_info("marker_low")

    analysis <- picard::analyze_pipeline_log(
      log_file = lm$global_log_file,
      create_plots = FALSE,
      write_tables = FALSE
    )

    testthat::expect_equal(analysis$run_summary$verbosity[[1]], "Low")
    testthat::expect_equal(nrow(analysis$step_summary), 0L)
    testthat::expect_equal(nrow(analysis$script_summary), 0L)
    testthat::expect_equal(nrow(analysis$gap_summary), 0L)
    testthat::expect_true(nrow(analysis$level_summary) >= 1L)
    testthat::expect_null(analysis$output_dir)
  }
)
