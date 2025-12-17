## Name and description of the tests present in the file 
unlink("temp", recursive = TRUE) ## Create a temporary folder where to test  

if (!file.exists("temp")) {
  dir.create("temp")
}

setwd("temp")

# load("../data-.../*.csv") ## Load what you need #nolint

## Test correct result 
testthat::test_that("I'm a long and clear description of the test", {
  testthat::expect_true(1 == 1)
})

## We conclude by exiting the file
setwd("../")
unlink("temp", recursive = TRUE)
