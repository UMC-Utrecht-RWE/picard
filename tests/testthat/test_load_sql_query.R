# test-load_sql_query.R
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
