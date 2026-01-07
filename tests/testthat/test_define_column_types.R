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
