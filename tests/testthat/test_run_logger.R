testthat::test_that("main log is created and has run marker", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_1")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir) # Config level

  testthat::expect_true(base::file.exists(lm$global_log_file))

  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  testthat::expect_true(any(base::grepl("Pipeline configured.", main_lines)))
})

# All loggings
testthat::test_that("step log is created, receives messages and, closed", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  # Code
  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir) # Config level

  lm$init_step_logger("T2") # Step level
  temp_tep_log_t2 <- lm$step_log_file # Need to store for tests
  logger::log_info("Begin T2")

  lm$start_script("substep_a.R") # Script level
  logger::log_info("Inside the script a")
  lm$end_script()

  lm$start_script("substep_b.R") # Script level
  logger::log_success("Inside the script b")
  lm$end_script()
  lm$end_step_logger()

  lm$init_step_logger("T3") # Step level
  logger::log_info("Begin T3")
  temp_tep_log_t3 <- lm$step_log_file # Step level

  lm$start_script("substep_c.R") # Script level
  logger::log_success("Inside the script c")

  lm$start_capturing_prints()
  print("A random print statement")

  lm$stop_capturing_prints()
  lm$end_script()
  lm$end_step_logger()

  # Tests
  # Do files in their own folder exist?
  testthat::expect_true(base::file.exists(temp_tep_log_t2))
  testthat::expect_true(base::file.exists(temp_tep_log_t3))

  # Read them
  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  step_t2_lines <- base::readLines(temp_tep_log_t2, warn = FALSE)
  step_t3_lines <- base::readLines(temp_tep_log_t3, warn = FALSE)

  # Test if the main log has got all messages from the steps.
  testthat::expect_true(base::any(base::grepl("Begin T2", main_lines)))
  testthat::expect_true(base::any(base::grepl("Begin T3", main_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended: T2", main_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended: T3", main_lines)))

  # Test if the step logs have got their messages
  testthat::expect_true(base::any(base::grepl("Step ended: T2", step_t2_lines)))
  testthat::expect_true(base::any(base::grepl("Begin T2", step_t2_lines)))
  testthat::expect_true(base::any(grepl("Inside the script a", step_t2_lines)))
  testthat::expect_true(base::any(grepl("Inside the script b", step_t2_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended: T2", step_t2_lines)))

  testthat::expect_true(base::any(base::grepl("Step ended: T3", step_t3_lines)))
  testthat::expect_true(base::any(base::grepl("Begin T3", step_t3_lines)))
  testthat::expect_true(base::any(base::grepl("Step ended: T3", step_t3_lines)))
  testthat::expect_true(base::any(base::grepl("A random print", step_t3_lines)))
  testthat::expect_null(lm$step_log_file)
  rm(temp_tep_log_t2, temp_tep_log_t3)
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
