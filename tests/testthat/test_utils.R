################################################
# Test functions for load_config_values
################################################
# two ifs and two elses plus a for loop to cover.
# at least five tests needed.
testthat::test_that("Test for file_path not null, exists and it is a yaml", {
  # create a temporary YAML file
  temp_yaml <- tempfile(fileext = ".yaml")
  on.exit(unlink(temp_yaml)) # ensure the file is deleted after the test
  writeLines(c("start_study_date: 2023-8-24"), temp_yaml)

  # Test loading the configuration values
  config <- load_config_values(temp_yaml)

  testthat::expect_true(is.list(config))
  testthat::expect_equal(config$start_study_date, "2023-8-24")
})

testthat::test_that("Test for file_path not null but it does not exists", {
  # Test loading the configuration values absent
  testthat::expect_error(
    load_config_values(file_path = ""),
    "Configuration file not found at: "
  )
})

testthat::test_that("Test for file_path not null, exists but not a yaml", {
  # Test loading the configuration values absent
  temp_not_yaml <- tempfile(fileext = ".txt")
  on.exit(unlink(temp_not_yaml)) # ensure the file is deleted after the test
  writeLines(c("Ciao Mondo!"), temp_not_yaml)

  # Test loading the configuration values
  testthat::expect_error(
    load_config_values(file_path = temp_not_yaml),
    "Config must be .yaml or .yml"
  )
})

testthat::test_that("Test for file_path null but yaml file exists", {
  testthat::expect_error(
    load_config_values(),
    "No YAML configuration files found in 'configuration' folder."
  )
})

testthat::test_that("Test for file_path null and at least a yaml file exists", {
  # create a temporary configuration directory
  tmp <- withr::local_tempdir()
  config_dir <- file.path(tmp, "configuration")
  # dir.create(config_dir, showWarnings = FALSE)
  fs::dir_create(config_dir)

  # create a temporary YAML file in the configuration directory
  temp_yaml <- file.path(config_dir, "config_values.yaml")
  writeLines(c("start_study_date: 2023-8-24"), temp_yaml)

  # change working directory to tempdir to use here::here correctly
  old_wd <- getwd()
  setwd(tmp)
  file.create(".here")
  here::i_am(".here")

  # Test loading the configuration values
  config <- load_config_values()

  testthat::expect_equal(config_values$start_study_date, "2023-8-24")

  on.exit(unlink(config_dir, recursive = TRUE)) # clean up after test
  on.exit(setwd(old_wd), add = TRUE) # ensure we return to old
})


##############################
# Test read_yaml
##############################
testthat::test_that("read_yaml reads a valid yaml mapping", {
  tmp <- tempfile(fileext = ".yaml")
  writeLines(c("a: 1", "b: true"), tmp)

  out <- read_yaml(tmp)

  testthat::expect_true(is.list(out))
  testthat::expect_identical(out$a, 1L)
  testthat::expect_identical(out$b, TRUE)
})

testthat::test_that("read_yaml rejects yaml that is not a mapping", {
  tmp <- tempfile(fileext = ".yaml")
  writeLines("hello world", tmp)  # valid YAML scalar, not a mapping

  testthat::expect_error(
    read_yaml(tmp),
    "YAML mapping"
  )
})

testthat::test_that("read_yaml rejects non-yaml files", {
  tmp <- tempfile(fileext = ".txt")
  writeLines("hello world", tmp)

  testthat::expect_error(
    read_yaml(tmp),
    "Config must be \\.yaml or \\.yml"
  )
})

testthat::test_that("read_yaml rejects invalid YAML syntax", {
  tmp <- tempfile(fileext = ".yaml")
  writeLines("not: [valid", tmp)

  testthat::expect_error(
    read_yaml(tmp),
    "^Invalid YAML:"
  )
})


testthat::test_that("run_script creates log dir, logs, and returns meta", {
  log_dir <- base::file.path(base::tempdir(), "logs_run_script_a")
  script <- base::tempfile(fileext = ".R")

  base::writeLines(c(
    "a <- 1:3",
    "b <- base::sum(a)"
  ), con = script, useBytes = TRUE)

  sha1 <- digest::digest(file = script, algo = "sha1")

  res <- run_script(file_path = script, log_dir = log_dir, quiet = FALSE)

  testthat::expect_true(base::dir.exists(log_dir))
  testthat::expect_true(base::file.exists(res$registry))
  testthat::expect_equal(res$sha1, sha1)

  b_val <- base::get("b", envir = res$env, inherits = FALSE)
  testthat::expect_equal(b_val, 6L)

  log_txt <- base::readLines(res$registry, warn = FALSE)
  testthat::expect_true(any(base::grepl(sha1, log_txt, fixed = TRUE)))

  testthat::expect_true(base::inherits(res$timing, "proc_time"))
})

testthat::test_that("run_script appends to provided registry_path", {
  log_dir <- base::file.path(base::tempdir(), "logs_run_script_b")
  base::dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

  registry_path <- base::file.path(
    log_dir,
    base::paste0(
      "registry_", base::format(base::Sys.time(), "%Y%m%d"),
      "_custom.log"
    )
  )
  base::writeLines("header", con = registry_path, useBytes = TRUE)

  script <- base::tempfile(fileext = ".R")
  base::writeLines("x <- 42L", con = script, useBytes = TRUE)

  res1 <- run_script(
    file_path = script, log_dir = log_dir,
    registry_path = registry_path, quiet = FALSE
  )
  res2 <- run_script(
    file_path = script, log_dir = log_dir,
    registry_path = registry_path, quiet = FALSE
  )

  testthat::expect_identical(res1$registry, registry_path)
  testthat::expect_identical(res2$registry, registry_path)

  lines_now <- base::readLines(registry_path, warn = FALSE)
  testthat::expect_gte(base::length(lines_now), 3L)

  testthat::expect_true(any(base::grepl("SHA1:", lines_now, fixed = TRUE)))
})

testthat::test_that("run_script logs even if script errors", {
  log_dir <- base::file.path(base::tempdir(), "logs_run_script_c")
  err_script <- base::tempfile(fileext = ".R")
  base::writeLines("base::stop(\"boom\")", con = err_script, useBytes = TRUE)

  sha1 <- digest::digest(file = err_script, algo = "sha1")
  reg <- base::file.path(log_dir, "registry_err.log")

  testthat::expect_error(
    run_script(file_path = err_script, log_dir = log_dir, registry_path = reg),
    "boom"
  )

  testthat::expect_true(base::file.exists(reg))
  log_txt <- base::readLines(reg, warn = FALSE)
  testthat::expect_true(any(base::grepl(sha1, log_txt, fixed = TRUE)))
})


testthat::test_that("uses existing registry in log_dir when none passed", {
  log_dir <- base::file.path(base::tempdir(), "logs_run_script_use_existing")
  base::dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

  # Pre-create an empty registry file that matches the pattern
  existing_log <- base::file.path(
    log_dir,
    base::paste0(
      "registry_",
      base::format(base::Sys.time(), "%Y%m%d_%H%M%S"),
      ".log"
    )
  )
  base::file.create(existing_log)

  # Create a tiny script file that actually exists
  script <- base::tempfile(fileext = ".R")
  base::writeLines("x <- 1L", con = script, useBytes = TRUE)
  run_script(file_path = script, log_dir = log_dir)

  # One new line should have been appended to the existing file
  lines_now <- base::readLines(existing_log, warn = FALSE)
  testthat::expect_equal(base::length(lines_now), 1L)
})
