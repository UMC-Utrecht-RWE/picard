###############################
# Tests for read_data function
###############################
testthat::test_that("read_data validates input incorrectly", {
  testthat::expect_error(
    read_data(NULL),
    "file_path cannot be NULL"
  )
  testthat::expect_error(
    read_data(123), "file_path must be a character string, not numeric"
  )
  testthat::expect_error(
    read_data(c("a", "b")),
    "file_path must be a single string, not a vector of length 2"
  )
  testthat::expect_error(read_data(""), "file_path cannot be an empty string")

  testthat::expect_error(
    read_data("   "), "file_path cannot be an empty string"
  )
  testthat::expect_error(
    read_data("nonexistent_file.csv"), "File not found: nonexistent_file.csv"
  )
})

testthat::test_that("warns on case-insensitive file match and reads CSV", {
  temp_dir <- base::tempdir()
  temp_file <- base::file.path(temp_dir, "TestFile.CSV")
  base::writeLines("a,b,c\n1,2,3", temp_file)

  result <- read_data(base::file.path(temp_dir, "testfile.csv"))

  testthat::expect_true(data.table::is.data.table(result))
  testthat::expect_equal(base::names(result), c("a", "b", "c"))

  base::unlink(temp_file)
})

testthat::test_that("read_data calls the correct reader", {
  # Mock readers for testing
  picard:::register_reader("csv", function(path, ...) {
    data.table::data.table(a = 1)
  })
  picard:::register_reader("rds", function(path, ...) {
    data.table::data.table(b = 2)
  })

  # Test: csv reader
  tf_csv <- tempfile(fileext = ".csv")
  writeLines("a", tf_csv)
  result <- read_data(tf_csv)
  expect_is(result, "data.table")
  expect_equal(names(result), "a")

  # Test: rds reader
  tf_rds <- tempfile(fileext = ".rds")
  saveRDS(data.table::data.table(b = 2), tf_rds)
  result <- read_data(tf_rds)
  expect_is(result, "data.table")
  expect_equal(names(result), "b")
})

testthat::test_that("read_data passes ... to reader", {
  withr::defer(.init_reader_registry())
  withr::defer(picard:::register_reader("csv", function(path, skip = 0, ...) {
    expect_equal(skip, 2)
    data.table::data.table(a = 1)
  }))
  tf <- tempfile(fileext = ".csv")
  writeLines("a", tf)
  result <- read_data(tf, skip = 2)
  expect_is(result, "data.table")
})

testthat::test_that("read_data errors when file has no extension", {
  tmp <- tempfile() # no extension
  on.exit(unlink(tmp), add = TRUE)
  file.create(tmp)

  testthat::expect_error(
    read_data(tmp)
  )
})

testthat::test_that("read_data no method for the extension", {
  tmp <- tempfile(fileext = ".weird")
  on.exit(unlink(tmp), add = TRUE)
  file.create(tmp)
  # ext should be lowered; expect message to include the ext
  testthat::expect_error(
    read_data(tmp),
    regexp = "No reader registered for extension: 'weird'",
    fixed  = TRUE
  )
})

testthat::test_that("read_data wraps reader errors with clear message", {
  withr::defer(picard:::.init_reader_registry())

  picard:::register_reader("csv", function(path, ...) {
    stop("ciao")
  })

  tf <- base::tempfile(fileext = ".csv")
  base::writeLines("a\n1", tf)

  err <- base::tryCatch(
    picard::read_data(tf),
    error = function(e) e
  )

  testthat::expect_true(base::inherits(err, "error"))
  testthat::expect_match(
    base::conditionMessage(err),
    "Failed to read file: .*\\nError: ciao"
  )
  testthat::expect_null(base::conditionCall(err))
})



###############################
# tests for validate_and_normalize_path
###############################
testthat::test_that("tests for validate_and_normalize_path", {
  testthat::expect_error(
    validate_and_normalize_path(file_path = NULL),
    "file_path cannot be NULL"
  )

  testthat::expect_error(
    validate_and_normalize_path(file_path = TRUE),
    "file_path must be a character string"
  )

  testthat::expect_error(
    validate_and_normalize_path(file_path = "file.txt", file_name = TRUE),
    "file_name must be a character string, not logical"
  )

  testthat::expect_error(
    validate_and_normalize_path(
      file_path = "file.txt", file_name = c("a", "b")
    ),
    "file_name must be a single string, not a vector of length 2"
  )

  testthat::expect_error(
    validate_and_normalize_path(file_path = "file.txt", file_name = ""),
    "file_name cannot be an empty string"
  )

  file_path <- base::tempdir()
  file_name <- "test_file.txt"
  temp_file <- base::file.path(file_path, file_name)
  base::writeLines("Sample text", temp_file)

  res <- validate_and_normalize_path(
    file_path = file_path, file_name = file_name
  )
  base::unlink(file_path)
})


###############################
# Tests for case_sensitive_filename function
###############################
testthat::test_that("tests for case_sensitive_filename", {
  testthat::expect_error(
    case_sensitive_filename(
      "test_file.txt", "test_file", actual_files = "test_file.txt"
    ),
    regexp = "File not found: "
  )

  file_path <- tempdir() # or your specific directory
  file_name <- file.path(file_path, "test_file.txt")
  file_name_1 <- file.path(file_path, "test_File.txt")
  file_name_2 <- file.path(file_path, "Test_file.txt")

  base::writeLines("Sample text", file_name)
  base::writeLines("Sample text", file_name_1)
  base::writeLines("Sample text", file_name_2)
  testthat::expect_error(
    case_sensitive_filename(
      file_path = file_path,
      file_name = "test_file.txt", actual_files = c(
        base::basename(file_name_1),
        base::basename(file_name_2)
      )
    ),
    regexp = "Multiple case-insensitive matches found fo"
  )
  base::unlink(file_path)
})