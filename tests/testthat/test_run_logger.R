testthat::teardown({
  # Reset the internal singleton (as before)
  picard:::.reset_logger_manager_instance()

  # Reset the global logger package to defaults.
  namespaces <- c("global", "picard")
  try(
    logger::log_appender(logger::appender_console, namespace = namespaces),
    silent = TRUE
  )
  try(
    logger::log_layout(logger::layout_simple, namespace = namespaces),
    silent = TRUE
  )

  # Close any open sinks.
  while (base::sink.number() > 0) {
    base::sink()
  }

  unlink("tests/testthat/data/intermediate_plots/", recursive = TRUE)
})

testthat::test_that("main log is created and has run marker", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_1")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }

  # Ensure cleanup of this specific directory even if test fails
  on.exit(base::unlink(log_dir, recursive = TRUE, force = TRUE), add = TRUE)

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir)

  testthat::expect_true(base::file.exists(lm$global_log_file))

  main_lines <- base::readLines(lm$global_log_file, warn = FALSE)
  testthat::expect_true(any(base::grepl("Pipeline configured.", main_lines)))

  # Note: The global teardown handles the .reset_logger_manager_instance()
})

# All loggings
testthat::test_that("step log is created, receives messages and, closed", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_basic_2")
  if (base::dir.exists(log_dir)) {
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  }
  on.exit(base::unlink(log_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Code
  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir) # Config level

  lm$start_step_logger("T2") # Step level
  temp_tep_log_t2 <- lm$step_log_file # Need to store for tests
  logger::log_info("Begin T2")

  lm$start_script("substep_a.R") # Script level
  logger::log_info("Inside the script a")
  lm$end_script()

  lm$start_script("substep_b.R") # Script level
  logger::log_success("Inside the script b")
  lm$end_script()
  lm$end_step_logger()

  lm$start_step_logger("T3") # Step level
  logger::log_info("Begin T3")
  temp_tep_log_t3 <- lm$step_log_file # Step level

  lm$start_script("substep_c.R") # Script level
  logger::log_success("Inside the script c")

  # --- CRITICAL FIX START ---
  lm$start_capturing_prints()
  # Safety: ensure capturing stops even if the expectation below fails or errors
  on.exit(try(lm$stop_capturing_prints(), silent = TRUE), add = TRUE)

  print("A random print statement")
  lm$stop_capturing_prints()
  # --- CRITICAL FIX END ---

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

testthat::test_that("Low verbose format is short", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_low")
  if (base::dir.exists(log_dir))
    base::unlink(log_dir, recursive = TRUE, force = TRUE)
  on.exit(base::unlink(log_dir, recursive = TRUE, force = TRUE), add = TRUE)

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir, verbose = "Low")

  logger::log_info("marker_low")

  lines <- base::readLines(lm$global_log_file, warn = FALSE)
  last <- utils::tail(lines, 1)

  parts <- strsplit(last, "\\|")[[1]]
  parts <- trimws(parts)

  testthat::expect_equal(length(parts), 3)
  testthat::expect_false(grepl("run\\+", last))
})


testthat::test_that("Normal verbose includes run+ but not full timers", {
  log_dir <- base::tempdir()

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir, verbose = "Normal")

  logger::log_info("marker_normal")

  lines <- base::readLines(lm$global_log_file, warn = FALSE)
  last <- utils::tail(lines, 1)

  testthat::expect_true(grepl("run\\+", last))
  testthat::expect_false(grepl("d\\+", last))

  testthat::expect_equal(length(strsplit(last, "\\|")[[1]]), 6)
})

testthat::test_that("High verbose includes full timers", {
  temp_dir <- withr::local_tempdir()

  # Ensure logger reset specifically for this test if needed,
  # though global teardown handles it too.
  withr::defer(picard:::.reset_logger_manager_instance())

  test_file <- file.path(temp_dir, "test_file.txt")
  writeLines("hello world", test_file)

  log_dir <- file.path(temp_dir, "logs")

  track_file_changes(log_dir = log_dir, path = temp_dir)

  lm <- picard:::LoggerManager$new()
  lm$configure(log_dir = log_dir, verbose = "High")

  substep_a <- base::tempfile(pattern = "substep_a", fileext = ".R")
  writeLines("Ciao", substep_a)

  lm$current_script <- substep_a
  logger::log_info("marker_high")

  lines <- base::readLines(lm$global_log_file, warn = FALSE)
  last <- utils::tail(lines, 1)

  testthat::expect_true(grepl("run\\+", last))
  testthat::expect_true(grepl("d\\+", last))
  testthat::expect_equal(length(strsplit(last, "\\|")[[1]]), 9)

  # modify the test file
  writeLines("ciao mondo", test_file)
  lm$current_script <- test_file
  logger::log_info("test_file")

  lines <- base::readLines(lm$global_log_file, warn = FALSE)

  testthat::expect_true("Script modified by user" %in% lines)

})


testthat::test_that("Test error verbose options", {
  lm <- picard:::LoggerManager$new()
  testthat::expect_error(
    lm$configure(
      log_dir = base::tempdir(),
      verbose = "Pizza"
    ),
    regexp = "'arg' should be one of "
  )
})

testthat::test_that("picard log wrappers work standalone", {
  namespaces <- c("global", "picard")
  logger::log_appender(logger::appender_console, namespace = namespaces)
  logger::log_layout(logger::layout_simple, namespace = namespaces)

  testthat::expect_silent(picard::log_info("wrapper ok"))
  testthat::expect_silent(picard::start_script_logging("standalone-script"))
  testthat::expect_silent(picard::stop_script_logging())
})

testthat::test_that("picard log wrappers use configured picard logger", {
  log_dir <- withr::local_tempdir()
  lm <- picard::logger_manager
  lm$configure(log_dir = log_dir)

  picard::log_info("wrapper configured")

  lines <- base::readLines(lm$global_log_file, warn = FALSE)
  testthat::expect_true(any(grepl("wrapper configured", lines, fixed = TRUE)))
})

testthat::test_that("script logging helper works in sourced scripts", {
  log_dir <- withr::local_tempdir()
  lm <- picard::logger_manager
  lm$configure(log_dir = log_dir)
  lm$start_step_logger("T2")
  on.exit(try(lm$end_step_logger(), silent = TRUE), add = TRUE)
  step_log <- lm$step_log_file

  script_path <- tempfile(fileext = ".R")
  base::writeLines(
    c(
      "picard::start_script_logging(\"helper-script\")",
      "on.exit(picard::stop_script_logging(), add = TRUE)",
      "picard::log_info(\"from sourced script\")",
      "print(\"captured print\")"
    ),
    con = script_path
  )

  base::source(script_path, local = new.env(parent = globalenv()))
  lm$end_step_logger()

  lines <- base::readLines(step_log, warn = FALSE)
  testthat::expect_true(any(grepl("Script started: helper-script", lines)))
  testthat::expect_true(any(grepl("from sourced script", lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("Script ended: helper-script", lines)))
})


#######################
# Log cleanup tests
#######################
testthat::test_that("cleanup_old_logs removes files older than cutoff", {
  log_dir <- base::file.path(base::tempdir(), "picard_logs_4")
  if (base::dir.exists(log_dir)) {
    unlink(log_dir, recursive = TRUE, force = TRUE)
  }
  base::dir.create(log_dir, recursive = TRUE)
  on.exit(base::unlink(log_dir, recursive = TRUE, force = TRUE), add = TRUE)

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
#######################
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
