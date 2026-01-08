###############################
# Tests for save_data
###############################
testthat::test_that("save_data errors when file has no extension", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "no_extension")

  testthat::expect_error(
    save_data(data.frame(a = 1), file_path = path),
    "File has no extension",
    fixed = TRUE
  )
})

testthat::test_that("Errors when no writer registered for extension", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.unknownext")

  testthat::expect_error(
    save_data(data.frame(a = 1), file_path = path),
    "No writer registered for extension",
    fixed = TRUE
  )
})

testthat::test_that("Dispatches to custom writer and returns file_path", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.foo")

  register_writer("foo", function(data, path, ...) {
    base::writeLines("ok", con = path)
    base::invisible(path)
  })

  res <- testthat::expect_invisible(
    save_data(list(a = 1), file_path = path)
  )
  testthat::expect_equal(res, fs::path_norm(path))
  testthat::expect_true(base::file.exists(path))
  testthat::expect_equal(base::readLines(path), "ok")
})

testthat::test_that("save_data wraps writer errors with helpful message", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.err")

  register_writer("err", function(data, path, ...) {
    base::stop("boom")
  })

  testthat::expect_error(
    save_data(list(a = 1), file_path = path),
    "Failed to save file:",
    fixed = TRUE
  )
  testthat::expect_error(
    save_data(list(a = 1), file_path = path),
    "boom",
    fixed = TRUE
  )
})

testthat::test_that("save_data can save csv via built-in writer", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")
  testthat::skip_if_not_installed("data.table")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.csv")

  save_data(data.frame(a = 1:3, b = c("x", "y", "z")), file_path = path)

  testthat::expect_true(base::file.exists(path))

  dt <- data.table::fread(path)
  testthat::expect_equal(dt$a, 1:3)
  testthat::expect_equal(dt$b, c("x", "y", "z"))
})

testthat::test_that("save_data can save rds via built-in writer", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.rds")

  obj <- list(a = 1, b = "x")
  save_data(obj, file_path = path)

  testthat::expect_true(base::file.exists(path))
  testthat::expect_equal(base::readRDS(path), obj)
})

testthat::test_that("create_plot does not error even if plotting fails", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")
  testthat::skip_if_not_installed("data.table")

  .init_writer_registry()

  root <- withr::local_tempdir()
  path <- base::file.path(root, "x.rds")

  dt <- data.table::data.table(
    person_id = 1:3,
    pregnancy_id = 10:12,
    unique_id = 100:102,
    value = c(0.1, 0.2, 0.3)
  )

  testthat::expect_no_error(
    save_data(
      dt,
      file_path = path,
      create_plot = TRUE,
      exclude_columns_from_plots = c(
        "person_id", "pregnancy_id", "unique_id"
      )
    )
  )
})

###############################
# Tests for prepare_output_path
###############################
testthat::test_that("prepare_output_path validates file_path", {
  withr::local_tempdir()

  testthat::expect_error(
    prepare_output_path(NULL),
    regexp = "file_path must be a single string, not a vector of length"
  )

  testthat::expect_error(
    prepare_output_path(c("a", "b")),
    "file_path must be a single string",
    fixed = TRUE
  )

  testthat::expect_error(
    prepare_output_path(""),
    "file_path cannot be an empty string",
    fixed = TRUE
  )
})

testthat::test_that("prepare_output_path validates file_name when provided", {
  withr::local_tempdir()

  tmpdir <- withr::local_tempdir()

  testthat::expect_error(
    prepare_output_path(tmpdir, file_name = 123),
    "file_name must be a character string",
    fixed = TRUE
  )

  testthat::expect_error(
    prepare_output_path(tmpdir, file_name = c("a", "b")),
    "file_name must be a single string",
    fixed = TRUE
  )

  testthat::expect_error(
    prepare_output_path(tmpdir, file_name = "   "),
    "file_name cannot be an empty string",
    fixed = TRUE
  )
})


testthat::test_that("prepare_output_path appends file_name and creates dir", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  root <- withr::local_tempdir()
  out_dir <- base::file.path(root, "newdir", "nested")
  out_file <- base::file.path(out_dir, "x.csv")

  res <- prepare_output_path(out_dir, file_name = "x.csv", create_dir = TRUE)

  testthat::expect_true(base::dir.exists(out_dir))
  testthat::expect_equal(
    fs::path_norm(res$normalized_path),
    fs::path_norm(out_file)
  )
})

testthat::test_that("Errors if dir missing and create_dir FALSE", {
  withr::local_tempdir()
  testthat::skip_if_not_installed("fs")

  root <- withr::local_tempdir()
  missing <- base::file.path(root, "missingdir", "file.csv")

  testthat::expect_error(
    prepare_output_path(missing, create_dir = FALSE),
    "Output directory does not exist",
    fixed = TRUE
  )
})

###############################
# Tests for register_writer
###############################
testthat::test_that("register_writer validates writer_func", {
  testthat::expect_error(
    register_writer("csv", "not_a_function"),
    "writer_func must be a function",
    fixed = TRUE
  )
})

testthat::test_that("list_writers returns sorted extensions", {
  .init_writer_registry()

  register_writer("zzz", function(data, path, ...) base::invisible(path))
  register_writer("aaa", function(data, path, ...) base::invisible(path))

  exts <- list_writers()
  testthat::expect_true(base::is.character(exts))
  testthat::expect_equal(exts, base::sort(exts))
  testthat::expect_true("aaa" %in% exts)
  testthat::expect_true("zzz" %in% exts)
})

testthat::test_that(".init_writer_registry clears existing writers", {
  .init_writer_registry()
  register_writer("temp", function(data, path, ...) base::invisible(path))
  testthat::expect_true("temp" %in% list_writers())

  .init_writer_registry()
  testthat::expect_false("temp" %in% list_writers())
  testthat::expect_true("csv" %in% list_writers())
  testthat::expect_true("rds" %in% list_writers())
})

###############################
# Tests for get_writer
###############################

###############################
# Tests for list_writers
###############################

###############################
# Tests for .init_writer_registry
###############################
