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
