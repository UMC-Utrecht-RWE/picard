#######################################
# tests for load_sql_query
#######################################
testthat::test_that("file_path not present", {
  testthat::expect_error(
    load_sql_query("non_existent_file.sql"),
    regexp = "SQL file not found: non_existent_file.sql"
  )
})

testthat::test_that("load_sql_query returns a single string", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c(
      "SELECT 1 AS a;",
      "SELECT 2 AS b;"
    ),
    tmp,
    useBytes = TRUE
  )

  out <- load_sql_query(tmp)

  testthat::expect_type(out, "character")
  testthat::expect_length(out, 1)

  # Expect the two lines joined by newline
  testthat::expect_equal(
    out,
    "SELECT 1 AS a;\nSELECT 2 AS b;"
  )
})

testthat::test_that("load_sql_query uses the shared raw loader", {
  picard:::.init_reader_registry()
  withr::defer(picard:::.init_reader_registry())

  picard:::register_reader("sql", function(path, encoding = "UTF-8", ...) {
    testthat::expect_identical(encoding, "UTF-8")
    "-- comment\tline\nSELECT 1;"
  })

  tmp <- tempfile(fileext = ".sql")
  writeLines("SELECT 0;", tmp, useBytes = TRUE)

  out <- load_sql_query(tmp)

  testthat::expect_equal(out, "/* comment line */\nSELECT 1;")
})

testthat::test_that("tabs are replaced by spaces", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c(
      "SELECT\tcol1,\tcol2",
      "\tFROM\ttable_x"
    ),
    tmp,
    useBytes = TRUE
  )

  out <- load_sql_query(tmp)

  expected <- paste(
    "SELECT col1, col2",
    " FROM table_x",
    sep = "\n"
  )

  testthat::expect_equal(out, expected)
  # Ensure no tab characters remain
  testthat::expect_false(grepl("\t", out, fixed = TRUE))
})

testthat::test_that("full-line -- comments are converted to /* ... */", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c(
      "-- this is a comment line",
      "   --    another comment with leading spaces",
      "SELECT * FROM sales;"
    ),
    tmp,
    useBytes = TRUE
  )

  out <- load_sql_query(tmp)

  lines <- strsplit(out, "\n", fixed = TRUE)[[1]]

  testthat::expect_equal(
    lines[[1]],
    "/* this is a comment line */"
  )
  testthat::expect_equal(
    lines[[2]],
    "/*    another comment with leading spaces */"
  )
  testthat::expect_equal(
    lines[[3]],
    "SELECT * FROM sales;"
  )
})

testthat::test_that("inline -- comments inside SQL line are NOT rewritten", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c(
      "SELECT 'abc--def' AS weird_string;",
      "SELECT col1 -- trailing comment we should NOT touch",
      "FROM table_y;"
    ),
    tmp,
    useBytes = TRUE
  )

  out <- load_sql_query(tmp)

  lines <- strsplit(out, "\n", fixed = TRUE)[[1]]

  # Line 1 should be untouched
  testthat::expect_match(
    lines[[1]],
    "^SELECT 'abc--def' AS weird_string;$"
  )

  # Line 2 should NOT have been converted to /* ... */
  # Because we only rewrite if line STARTS with --
  testthat::expect_match(
    lines[[2]],
    "SELECT col1 -- trailing comment we should NOT touch$"
  )
})

testthat::test_that("encoding argument is respected (UTF-16 simulation)", {
  # We'll write a UTF-16LE file (similar to SQL Server exports),
  # and make sure we can read it by passing encoding = "UTF-16LE".
  tmp <- tempfile(fileext = ".sql")

  txt <- c(
    "-- comment with utf16",
    "SELECT 123 AS value;"
  )

  # open in text mode with encoding, NOT binary mode
  con_write <- file(tmp, open = "w", encoding = "UTF-16LE")
  writeLines(txt, con = con_write, useBytes = FALSE)
  close(con_write)

  # Now read using the same encoding
  out <- load_sql_query(tmp, encoding = "UTF-16LE")

  lines <- strsplit(out, "\n", fixed = TRUE)[[1]]

  # Check comment got converted
  testthat::expect_equal(
    lines[[1]],
    "/* comment with utf16 */"
  )
  testthat::expect_equal(
    lines[[2]],
    "SELECT 123 AS value;"
  )
})

testthat::test_that("function does not leave connection open", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c("SELECT 1;"),
    tmp,
    useBytes = TRUE
  )

  # Run once
  out1 <- load_sql_query(tmp)
  testthat::expect_match(out1, "SELECT 1;")

  # Run again - if the previous connection was left open/locked,
  # some OS/filesystems would error on re-opening with 'file in use'
  out2 <- load_sql_query(tmp)
  testthat::expect_match(out2, "SELECT 1;")
})

testthat::test_that("test params passing", {
  tmp <- tempfile(fileext = ".sql")
  writeLines(
    c(
      "SELECT 1 AS {a};",
      "SELECT 2 AS {b};"
    ),
    tmp,
    useBytes = TRUE
  )

  out <- load_sql_query(tmp, params = list(a = "aa", b = "bb"))

  # Expect the two lines joined by newline
  testthat::expect_equal(
    out,
    "SELECT 1 AS aa;\nSELECT 2 AS bb;"
  )
})

#######################################
# tests for interpolate_sql_params
#######################################
testthat::test_that("Passing nulls", {
  sql_file <- tempfile(fileext = ".sql")
  sql <- "SELECT 1 AS {a} WHERE name AS {b};"

  writeLines(sql, sql_file, useBytes = TRUE)

  testthat::expect_error(
    interpolate_sql_params(sql, params = NULL),
    regexp = "params must be a named list"
  )

  testthat::expect_error(
    interpolate_sql_params(sql, params = list(a = "aa")),
    regexp = "Missing required parameters: b"
  )

  testthat::expect_no_error(
    interpolate_sql_params(
      "{a}, {b}, {c}, {d}, {e}",
      params = list(
        a = "aa", b = 1, c = 1, d = c("x", "y"), e = c(1, 2)
      )
    )
  )

  testthat::expect_error(
    interpolate_sql_params(
      "{a}",
      params = list(a = TRUE)
    ),
    regexp = "Unsupported parameter type for 'a': logical"
  )
})

#######################################
# tests for execute_sql_file
#######################################
testthat::test_that("execute=FALSE returns sql and does not hit DBI", {
  conn <- structure(list(), class = "dummy_conn")
  sql <- "SELECT 1"

  testthat::expect_equal(
    execute_sql_file(sql = sql, conn = conn, execute = FALSE),
    sql
  )
})

testthat::test_that("INSERT executes and SELECT returns a data frame", {

  conn <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  DBI::dbExecute(conn, "CREATE TABLE t (x INTEGER)")

  ins_n <- execute_sql_file(
    sql = "INSERT INTO t (x) VALUES (1)",
    conn = conn,
    execute = TRUE
  )
  testthat::expect_equal(ins_n, 1)

  out <- execute_sql_file(
    sql = "SELECT x FROM t",
    conn = conn,
    execute = TRUE
  )
  testthat::expect_s3_class(out, "data.frame")
  testthat::expect_equal(out$x, 1)
  DBI::dbDisconnect(conn)
})

testthat::test_that("SELECT query saves result to Parquet file", {
  conn <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  # Create a table and insert some data
  DBI::dbExecute(conn, "CREATE TABLE t (x INTEGER, y TEXT)")
  DBI::dbExecute(conn, "INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b')")

  # Temporary file or directory for Parquet output
  parquet_path <- tempfile()

  # Execute the SELECT query and save the result to Parquet
  execute_sql_file(
    sql = "SELECT * FROM t",
    conn = conn,
    execute = TRUE,
    save_as_parquet = TRUE,
    parquet_path = parquet_path
  )

  # Check if the output is a directory (partitioned) or a single file
  if (dir.exists(parquet_path)) {
    # If it's a directory, find the first Parquet file
    parquet_files <- list.files(
      parquet_path, recursive = TRUE, full.names = TRUE, pattern = "\\.parquet$"
    )
    testthat::expect_true(length(parquet_files) > 0)
    parquet_data <- arrow::read_parquet(parquet_files[1])
  } else {
    # If it's a single file, read it directly
    testthat::expect_true(file.exists(parquet_path))
    parquet_data <- arrow::read_parquet(parquet_path)
  }

  # Verify the contents of the Parquet file
  testthat::expect_s3_class(parquet_data, "data.frame")
  testthat::expect_equal(parquet_data$x, c(1, 2))
  testthat::expect_equal(parquet_data$y, c("a", "b"))

  DBI::dbDisconnect(conn)
})

testthat::test_that("SELECT query saves result to partitioned Parquet files", {
  conn <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  # Create a table and insert some data
  DBI::dbExecute(conn, "CREATE TABLE t (x INTEGER, y TEXT)")
  DBI::dbExecute(conn, "INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b')")

  # Temporary directory for partitioned Parquet output
  parquet_dir <- tempfile()

  # Execute the SELECT query and save the result to partitioned Parquet files
  execute_sql_file(
    sql = "SELECT * FROM t",
    conn = conn,
    execute = TRUE,
    save_as_parquet = TRUE,
    parquet_path = parquet_dir,
    partition_by = "y"
  )

  # Check that the partitioned Parquet files were created
  testthat::expect_true(dir.exists(parquet_dir))
  partition_files <- list.files(parquet_dir, recursive = TRUE)
  testthat::expect_true(length(partition_files) > 0)

  # Read one of the partitioned Parquet files and verify its contents
  partitioned_data <- arrow::read_parquet(
    file.path(parquet_dir, "y=a/part-0.parquet")
  )
  testthat::expect_s3_class(partitioned_data, "data.frame")
  testthat::expect_equal(partitioned_data$x, 1)

  DBI::dbDisconnect(conn)
})

testthat::test_that("If parquet_path provided and save_as_parquet is TRUE", {
  conn <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  # Create a table and insert some data
  DBI::dbExecute(conn, "CREATE TABLE t (x INTEGER)")
  DBI::dbExecute(conn, "INSERT INTO t (x) VALUES (1)")

  # Attempt to save to Parquet without providing parquet_path
  testthat::expect_error(
    execute_sql_file(
      sql = "SELECT * FROM t",
      conn = conn,
      execute = TRUE,
      save_as_parquet = TRUE
    ),
    regexp = "parquet_path must be provided when save_as_parquet is TRUE"
  )

  DBI::dbDisconnect(conn)
})
