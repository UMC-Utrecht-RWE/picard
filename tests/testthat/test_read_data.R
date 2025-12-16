testthat::test_that("read_data validates input incorrectly", {
  testthat::expect_error(
    read_data(NULL),
    "file_path must be a single string, not a vector of length 0"
  )
  testthat::expect_error(
    read_data(123), "File not found: 123"
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
