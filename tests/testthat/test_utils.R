################################################
# Test functions for load_config
################################################
# two ifs and two elses plus a for loop to cover.
# at least five tests needed.
testthat::test_that("Test for file_path not null, exists and it is a yaml", {
  # create a temporary YAML file
  temp_yaml <- tempfile(fileext = ".yaml")
  on.exit(unlink(temp_yaml)) # ensure the file is deleted after the test
  writeLines(c("start_study_date: 2023-8-24"), temp_yaml)

  # Test loading the configuration values
  config <- load_config(temp_yaml)

  testthat::expect_true(is.list(config))
  testthat::expect_equal(config$start_study_date, "2023-8-24")
})

testthat::test_that("Test for file_path not null but it does not exists", {
  # Test loading the configuration values absent
  testthat::expect_error(
    load_config(file_path = ""),
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
    load_config(file_path = temp_not_yaml),
    "Config must be .yaml or .yml"
  )
})

testthat::test_that("Test for file_path null but yaml file exists", {
  testthat::expect_error(
    load_config(),
    "No YAML configuration files found in 'configuration' folder."
  )
})

testthat::test_that("Test for file_path null and at least a yaml file exists", {
  # create a temporary configuration directory
  tmp <- withr::local_tempdir()
  config_dir <- file.path(tmp, "configuration")
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
  config <- load_config()

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
  writeLines("hello world", tmp) # valid YAML scalar, not a mapping

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

##############################
# Test get_tracked_files
##############################
testthat::test_that("get_tracked_files finds file on all OS", {
  test_dir <- normalizePath(
    withr::local_tempdir(), winslash = "/", mustWork = FALSE
  )

  tmp <- tempfile(tmpdir = test_dir, fileext = ".txt")
  writeLines("hello world", tmp)

  tmp_normalized <- normalizePath(tmp, winslash = "/", mustWork = FALSE)

  tracked_files <- get_tracked_files(path = test_dir)

  tracked_files_normalized <- normalizePath(
    tracked_files, winslash = "/", mustWork = FALSE
  )
  testthat::expect_true(tmp_normalized %in% tracked_files_normalized)
})


##############################
# Test get_hash_output
##############################
testthat::test_that("", {
  withr::local_tempdir()
  log_dir <- base::tempdir()

  tmp <- base::tempfile(fileext = ".txt", tmpdir = log_dir)
  writeLines("hello world", tmp)

  output_file <- get_hash_output(tmp)
  testthat::expect_equal(output_file, tmp)

  output_file <- get_hash_output(output_file = NULL, log_dir = log_dir)
  testthat::expect_equal(
    output_file, base::file.path(log_dir, "registry.csv")
  )
})

##############################
# Test compute_hash
##############################
testthat::test_that("", {
  tmp <- base::tempfile(fileext = ".txt")
  writeLines("hello world", tmp)

  testthat::expect_true(
    compute_hash(tmp) %in%
      c(
        "22596363b3de40b06f981fb85d82312e8c0ed511", # this is for mac/linux
        "88a5b867c3d110207786e66523cd1e4a484da697" # windows
      )
  )
})

##############################
# Test track_file_changes
##############################
testthat::test_that("track_file_changes creates registry correctly", {
  # Create a clean temp directory
  temp_dir <- withr::local_tempdir()

  # Create a test file with a normal name (not from tempfile)
  test_file <- file.path(temp_dir, "test_file.txt")
  writeLines("hello world", test_file)

  # Create log directory inside temp_dir
  log_dir <- file.path(temp_dir, "logs")

  # Track changes in temp_dir
  track_file_changes(log_dir = log_dir, path = temp_dir)

  # Read the registry
  dt <- picard::load(
    file_path = log_dir,
    file_name = "registry.csv"
  )

  testthat::expect_true(test_file %in% dt$file_path)
  testthat::expect_equal(nrow(dt), 1)  # Should only have our test file
})



################################################
# Test functions for set_dates
################################################
# Create test data
setup_data <- function() {
  data.table::data.table(
    id = 1:3,
    date_char = c("2020-01-01", "2020-01-02", "2020-01-03"),
    date_num = c(18262L, 18263L, 18264L), # Days since 1970-01-01
    data_num2 = c("20200101", "20200102", "20200103"),
    date_date = as.Date(c("2021-01-01", "2021-01-02", "2021-01-03")),
    date_dbl = c(18262.5, 18263.5, 18264.5), # double (numeric)
    factor_col = factor(c("A", "B", "C")),
    logical_col = c(TRUE, FALSE, TRUE)
  )
}

# -----------------------------
# TEST SUITE
# -----------------------------

testthat::test_that("set_dates works on character and numeric columns", {
  dt <- setup_data()
  testthat::expect_s3_class(dt, "data.table")

  result <- set_dates(
    dt,
    c("date_char", "date_num", "data_num2"),
    date_format = "%Y%m%d",
    reference_date = "1970-01-01"
  )

  testthat::expect_s3_class(result, "data.table")
  testthat::expect_identical(
    result$date_char,
    as.Date(c("2020-01-01", "2020-01-02", "2020-01-03"))
  )
  testthat::expect_identical(
    result$date_num,
    as.Date(c("2020-01-01", "2020-01-02", "2020-01-03"), origin = "1970-01-01")
  )
})

testthat::test_that("set_dates skips already-Date columns", {
  dt <- setup_data()
  original <- dt$date_date

  result <- set_dates(dt, "date_date", reference_date = "1970-01-01")

  testthat::expect_identical(result$date_date, original)
})

testthat::test_that("set_dates returns same df when no date_cols", {
  dt <- setup_data()
  result <- set_dates(dt, character(0))
  testthat::expect_identical(result, dt)
})

testthat::test_that("set_dates throws error if df is not data.table", {
  df <- base::data.frame(x = "2020-01-01")
  testthat::expect_error(
    set_dates(df, "x"),
    "df must be a data.table"
  )
})

testthat::test_that("set_dates throws error for non-existent columns", {
  dt <- setup_data()
  testthat::expect_error(
    set_dates(dt, c("date_char", "not_there")),
    "The following columns are not in the data.table: not_there"
  )
})

testthat::test_that("set_dates validates reference_date", {
  dt <- setup_data()

  testthat::expect_error(
    set_dates(dt, "date_char", reference_date = "invalid-date"),
    "Invalid reference_date: 'invalid-date'. Must be a valid date string."
  )

  testthat::expect_error(
    set_dates(dt, "date_char", reference_date = NA_character_),
    "Invalid reference_date: 'NA'. Must be a valid date string."
  )
})

testthat::test_that("set_dates returns data.table even if not originally", {
  dt <- setup_data()
  result <- set_dates(dt, "date_char")
  testthat::expect_true(data.table::is.data.table(result))
})


#####################################
# Tests for get_date_value
#####################################
testthat::test_that("Test date_input as POSIXct", {
  date_input <- as.POSIXct(c("2020-01-01", "2020-01-02"), tz = "UTC")
  result <- get_date_value(date_input)
  expected <- as.Date(c("2020-01-01", "2020-01-02"))
  testthat::expect_identical(result, expected)
})

testthat::test_that("Test date_input as factor", {
  date_input <- factor(c("2020-01-01", "2020-01-02"))
  result <- get_date_value(date_input)
  expected <- as.Date(c("2020-01-01", "2020-01-02"))
  testthat::expect_identical(result, expected)
})

testthat::test_that("Test date_input as NA_character_", {
  testthat::expect_warning(
    get_date_value(NA_character_),
    "Some date values could not be parsed and were set to NA."
  )
  testthat::expect_warning(
    get_date_value("invalid-date"),
    "Some date values could not be parsed and were set to NA."
  )
})

testthat::test_that("Test date_input as NA_character_", {
  testthat::expect_warning(
    get_date_value(TRUE),
    "Unsupported date_input type; returning NA of class Date."
  )
})
