# test list_readers function
testthat::test_that("list_readers returns correct output", {
  # Assuming list_readers is a function that lists available readers
  readers <- picard::list_readers()

  # Check that the output is a character vector
  testthat::expect_type(readers, "character")
  testthat::expect_true(is.vector(readers))

  # Check that the output is not empty
  testthat::expect_gt(length(readers), 0)
})
