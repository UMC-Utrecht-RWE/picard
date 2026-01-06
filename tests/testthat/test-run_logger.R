# rm(list = ls())
# source("/Users/mcinelli/repos/picard/R/run_logger.R", encoding = "UTF-8")
# logger_manager$configure()
# logger_manager$init_step_logger("T2")
# logger_manager$start_script("create_something.R")

# logger::log_info("Doing something...")
# logger::log_debug("Debug details...")
# logger::log_success("Success")
# logger::log_warn("Warning message")

# logger_manager$end_script()
# logger_manager$end_step_logger()

# rm(list = ls())
# source("/Users/mcinelli/repos/picard/R/run_logger.R", encoding = "UTF-8")
testthat::test_that("main log is created and has run marker", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_1")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir)

  testthat::expect_true(base::file.exists(lm$global_log_file))

  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  testthat::expect_true(any(base::grepl("Pipeline run started", main_lines)))
})

testthat::test_that("step log is created and receives messages", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir)

  lm$init_step_logger("step_a")
  testthat::expect_true(base::file.exists(lm$step_log_file))

  logger::log_info("hello")

  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  step_lines <- base::readLines(lm$step_log_file, warn = FALSE)

  testthat::expect_true(base::any(base::grepl("hello", main_lines)))
  testthat::expect_true(base::any(base::grepl("hello", step_lines)))
})


testthat::test_that("cleanup_old_logs removes files older than cutoff", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_4")
  if (base::dir.exists(log_dir)) {
    unlink(log_dir, recursive = TRUE, force = TRUE)
  }
  base::dir.create(log_dir, recursive = TRUE)

  old_file <- base::file.path(log_dir, "old.log")
  base::writeLines("x", old_file)

  ok <- TRUE
  tryCatch(
    {
      base::Sys.setFileTime(
        old_file,
        base::as.POSIXct(base::Sys.Date() - 40)
      )
    },
    error = function(e) ok <<- FALSE
  )

  if (!ok) {
    testthat::skip("Sys.setFileTime not supported on this filesystem")
  }

  lm <- picard:::LoggerManager$new()
  lm$log_dir <- log_dir
  lm$cleanup_old_logs(days_to_keep = 30)

  testthat::expect_false(base::file.exists(old_file))
})
