# Helper to create test data
create_test_data <- function() {
  data.table::data.table(
    num = stats::rnorm(10),
    int = base::sample.int(50, 10, replace = TRUE),
    logi = base::sample(c(TRUE, FALSE, NA), 10,
      replace = TRUE,
      prob = c(0.45, 0.45, 0.10)
    ),
    fct = base::factor(base::sample(LETTERS[1:4], 10, replace = TRUE)),
    chr = base::sample(c(letters[1:3], NA), 10, replace = TRUE),
    date = as.Date("2023-01-01") + base::sample.int(365, 10, replace = TRUE),
    time = as.POSIXct("2023-01-01", tz = "UTC") +
      base::sample.int(86400, 10, replace = TRUE)
  )
}

testthat::test_that("Changing velue of some columns", {
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
