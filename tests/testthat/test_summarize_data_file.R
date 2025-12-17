# test summarize_data_file function
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

testthat::test_that("summarize_data_file returns correct summary", {
  # Create a temporary CSV file for testing
  dt <- setup_data()
  temp_file <- tempfile(fileext = ".csv")
  data.table::fwrite(dt, temp_file)
  result <- picard::summarize_data_file(temp_file)
  data <- result$data
  summary <- result$summary

  expected <- c(
    "file", "size_mb", "n_rows", "n_cols",
    "columns", "col_types", "missing", "memory_mb"
  )
  # two vectors have the same elements, regardless of order
  testthat::expect_setequal(names(summary), expected)
  testthat::expect_true(is.list(summary))
  testthat::expect_equal(summary$file, temp_file)
})
