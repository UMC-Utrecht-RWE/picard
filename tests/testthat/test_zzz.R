test_that("Test .onLoad", {
  expect_silent(picard:::.onLoad(libname = "picard", pkgname = "picard"))
})
