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
# Only config
testthat::test_that("main log is created and has run marker", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_1")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir)  # Config level

  testthat::expect_true(base::file.exists(lm$global_log_file))

  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  testthat::expect_true(any(base::grepl("Pipeline configured.", main_lines)))
})

# Config and step logging
testthat::test_that("step log is created, receives messages and, closed", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  # Code
  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir)  # Config level
  lm$init_step_logger("T2")
  logger::log_info("Ciao")
  temp_tep_log <- lm$step_log_file
  lm$end_step_logger()

  # Tests
  testthat::expect_true(base::file.exists(temp_tep_log))
  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  step_lines <- base::readLines(temp_tep_log, warn = FALSE)

  testthat::expect_true(base::any(base::grepl("Ciao", main_lines)))
  testthat::expect_true(base::any(base::grepl("Ciao", step_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended:", main_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended:", step_lines)))
  testthat::expect_null(lm$step_log_file)
  rm(temp_tep_log)
})

# Config, step logging and script logging
testthat::test_that("Testing levels up to script", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  # Code
  lm <- picard:::LoggerManager$new() # Config level
  lm$configure(log_dir = log_dir)
  lm$init_step_logger("T2") # Step level
  temp_tep_log <- lm$step_log_file
  logger::log_info("Begining of the step")

  lm$start_script("first_substep.R") # Script level
  logger::log_info("Inside the script")
  lm$end_script()
  lm$end_step_logger()

  # Tests
  testthat::expect_true(base::file.exists(temp_tep_log))
  step_lines <- base::readLines(temp_tep_log, warn = FALSE)

  testthat::expect_true(base::any(base::grepl("Script started:", step_lines)))
  testthat::expect_true(base::any(base::grepl("Inside the script", step_lines)))
  testthat::expect_true(base::any(base::grepl("Script ended:", step_lines)))
})

# Config, step logging and script logging
testthat::test_that("Testing capturing prints", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  # Code
  lm <- picard:::LoggerManager$new() # Config level
  lm$configure(log_dir = log_dir)
  lm$start_capturing_prints()
  print("Ciao mondo")
  lm$stop_capturing_prints()

  # Tests
  testthat::expect_true(base::file.exists(lm$global_log_file))
  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)

  testthat::expect_true(base::any(base::grepl("Ciao mondo", main_lines)))
})

#######################
# Log cleanup tests
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

#######################
# Test .get_logger_manager_instance
testthat::test_that("singleton can be reset to a new instance", {
  picard:::.reset_logger_manager_instance()

  a <- picard:::.get_logger_manager_instance()
  picard:::.reset_logger_manager_instance()
  b <- picard:::.get_logger_manager_instance()

  testthat::expect_false(base::identical(a, b))
})

testthat::test_that("getter returns same instance", {
  ns <- base::asNamespace("picard")
  get_lm <- base::get(".get_logger_manager_instance", envir = ns)
  testthat::expect_true(base::identical(get_lm(), get_lm()))
})
