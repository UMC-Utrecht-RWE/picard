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
  testthat::expect_is(result, "data.table")
  testthat::expect_equal(names(result), "a")

  # Test: rds reader
  tf_rds <- tempfile(fileext = ".rds")
  saveRDS(data.table::data.table(b = 2), tf_rds)
  result <- read_data(tf_rds)
  testthat::expect_is(result, "data.table")
  testthat::expect_equal(names(result), "b")
})

testthat::test_that("read_data passes ... to reader", {
  withr::defer(.init_reader_registry())
  withr::defer(picard:::register_reader("csv", function(path, skip = 0, ...) {
    testthat::expect_equal(skip, 2)
    data.table::data.table(a = 1)
  }))
  tf <- tempfile(fileext = ".csv")
  writeLines("a", tf)
  result <- read_data(tf, skip = 2)
  testthat::expect_is(result, "data.table")
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
      "test_file.txt", "test_file",
      actual_files = "test_file.txt"
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

###############################
# Tests for define_column_types
###############################
testthat::test_that("tests for define_column_types", {
  dt <- create_test_data()[, c("num", "int", "logi")]
  testthat::expect_no_error(
    define_column_types(
      df = head(dt),
      col_types = list(
        num = "integer",
        int = "numeric",
        logi = "factor"
      )
    )
  )

  testthat::expect_error(
    define_column_types(
      df = head(dt), col_types = list("integer", "numeric", "factor")
    ),
    regexp = "col_types must be a named list"
  )

  testthat::expect_warning(
    define_column_types(
      df = head(dt),
      col_types = list(
        num = "integer",
        int = "numeric",
        logi = "biribiri"
      )
    ),
    regexp = "Failed to convert column "
  )

  testthat::expect_warning(
    define_column_types(
      df = head(dt),
      col_types = list(
        num = "integer",
        int = "numeric",
        logic = "factor"
      )
    ),
    regexp = "Column 'logic' not present in data"
  )
})

testthat::test_that("Changing value of some columns", {
  df <- create_test_data()
  df <- define_column_types(df = df, col_types = c(
    date = "character",
    logi = as.logical,
    chr = as.factor
  ))
  testthat::expect_true(is.character(df$date))
  testthat::expect_true(is.logical(df$logi))
  testthat::expect_true(is.factor(df$chr))
})


###############################
# Tests for .init_reader_registry
###############################
testthat::test_that("Resets registry and loads defaults", {
  # Start clean
  picard:::.init_reader_registry()

  # Add a custom reader and verify it's there
  picard:::register_reader("zzz", function(path, ...) "ok")
  testthat::expect_true("zzz" %in% picard::list_readers())

  # Re-init should remove custom and restore built-ins
  picard:::.init_reader_registry()
  readers <- picard::list_readers()

  testthat::expect_false("zzz" %in% readers)
  testthat::expect_true(
    all(
      c("csv", "rdata", "rds", "xlsx", "fst", "duckdb", "parquet") %in% readers
    )
  )
})

testthat::test_that(".init_reader_registry for load_rdata reader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("rdata", function(path, ...) {
    data.table::data.table(a = 1)
  }))
  tf <- base::tempfile(fileext = ".RData")
  obj <- data.frame(a = 1:3, b = c("x", "y", "z"))
  base::save(obj, file = tf)

  result <- read_data(tf, skip = 2)
  testthat::expect_is(result, "data.table")
})

testthat::test_that(".init_reader_registry for readRDS reader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("rds", function(path, ...) {
    data.table::data.table(b = 2)
  }))
  tf_rds <- tempfile(fileext = ".rds")
  saveRDS(data.table::data.table(b = 2), tf_rds)
  result <- read_data(tf_rds)
  testthat::expect_is(result, "data.table")
})

testthat::test_that(".init_reader_registry for read_xlsx reader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("xlsx", function(path, ...) {
    data.table::data.table(c = 3)
  }))
  tf_xlsx <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(data.table::data.table(c = 3), tf_xlsx)
  result <- read_data(tf_xlsx)
  testthat::expect_is(result, "data.table")
})

testthat::test_that(".init_reader_registry for read_fst reader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("fst", function(path, ...) {
    data.table::data.table(d = 4)
  }))
  tf_fst <- tempfile(fileext = ".fst")
  fst::write_fst(data.table::data.table(d = 4), tf_fst)
  result <- read_data(tf_fst)
  testthat::expect_is(result, "data.table")
})

testthat::test_that(".init_reader_registry for duckdb reader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("duckdb", function(path, ...) {
    data.table::data.table(e = 5)
  }))
  tf_duckdb <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), tf_duckdb)
  DBI::dbWriteTable(con, "test_table", data.table::data.table(e = 5))
  DBI::dbDisconnect(con, shutdown = TRUE)
  result <- read_data(tf_duckdb)
  testthat::expect_is(result, "data.table")
})

testthat::test_that("duckdb reader with load_only_table not null", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("duckdb", function(path, ...) {
    data.table::data.table(e = 5)
  }))
  tf_duckdb <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), tf_duckdb)
  DBI::dbWriteTable(con, "test_table", data.table::data.table(e = 5))
  DBI::dbDisconnect(con, shutdown = TRUE)
  result <- read_data(tf_duckdb, load_only_table = "test_table")
  testthat::expect_is(result, "data.table")

  testthat::expect_error(
    read_data(tf_duckdb, load_only_table = "nonexistent_table"),
    regexp = "Input known_table does not match any table in the DuckDB file."
  )
})

testthat::test_that("duckdb reader with length(tables) != 1", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())
  withr::defer(picard:::register_reader("duckdb", function(path, ...) {
    data.table::data.table(e = 5)
  }))
  tf_duckdb <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), tf_duckdb)
  DBI::dbWriteTable(con, "table1", data.table::data.table(e = 5))
  DBI::dbWriteTable(con, "table2", data.table::data.table(e = 6))
  DBI::dbDisconnect(con, shutdown = TRUE)
  result <- read_data(tf_duckdb)
  testthat::expect_is(result, "data.table")
})


###############################
# Tests for register_reader
###############################
testthat::test_that("Registers functions and rejects invalid input", {
  picard:::.init_reader_registry()

  f <- function(path, ...) data.table::data.table(x = 1L)
  picard:::register_reader("foo", f)

  # get_reader is internal; use ::: in tests if you want to assert exact storage
  testthat::expect_identical(picard:::get_reader("foo"), f)

  testthat::expect_error(
    picard:::register_reader("bar", "not_a_function"),
    "reader_func must be a function"
  )
})
###############################
# Tests for load_rdata
###############################
testthat::test_that("load_rdata loads single object and returns it", {
  tf <- base::tempfile(fileext = ".RData")

  obj <- data.frame(a = 1:3, b = c("x", "y", "z"))
  base::save(obj, file = tf)

  res <- load_rdata(tf)

  testthat::expect_s3_class(res, "data.frame")
  testthat::expect_equal(res, obj)
})
testthat::test_that("load_rdata more the one object", {
  tf <- base::tempfile(fileext = ".RData")

  a <- data.frame(id = 1:2)
  b <- data.frame(id = 3:4)

  base::save(a, b, file = tf)
  testthat::expect_warning(
    load_rdata(tf),
    regexp = "The RData file"
  )
})
###############################
# Tests for read_data_batch
###############################
testthat::test_that("read_data_batch errors on empty file_paths", {
  testthat::expect_error(
    read_data_batch(character(0)),
    "file_paths cannot be empty"
  )
})

testthat::test_that("read_data_batch combines using rbind", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())

  withr::local_tempdir()
  f1 <- withr::local_tempfile(pattern = "a", fileext = ".csv")
  f2 <- withr::local_tempfile(pattern = "b", fileext = ".csv")

  base::writeLines(c("id,val", "1,x"), f1)
  base::writeLines(c("id,val", "2,y"), f2)

  res <- picard::read_data_batch(c(f1, f2), combine_method = "rbind")

  testthat::expect_s3_class(res, "data.table")
  testthat::expect_equal(base::nrow(res), 2L)
  testthat::expect_setequal(res$id, c(1L, 2L))
})


testthat::test_that("Returns named list when combine_method=list", {
  picard:::.init_reader_registry()
  withr::local_tempdir()
  f1 <- withr::local_tempfile(pattern = "a", fileext = ".csv")
  f2 <- withr::local_tempfile(pattern = "b", fileext = ".csv")

  base::writeLines(c("id,val", "1,x"), f1)
  base::writeLines(c("id,val", "2,y"), f2)

  res <- picard::read_data_batch(c(f1, f2), combine_method = "list")

  testthat::expect_type(res, "list")
  testthat::expect_named(res, base::basename(c(f1, f2)))
  testthat::expect_s3_class(res[[1]], "data.table")
  testthat::expect_s3_class(res[[2]], "data.table")
})

testthat::test_that("read_data_batch errors on invalid combine_method", {
  picard:::.init_reader_registry()
  withr::local_tempdir()
  f1 <- withr::local_tempfile(pattern = "a", fileext = ".csv")
  base::writeLines(c("id,val", "1,x"), f1)

  testthat::expect_error(
    picard::read_data_batch(c(f1), combine_method = "nope"),
    "combine_method must be 'rbind' or 'list'"
  )
})
