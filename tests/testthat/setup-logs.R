withr::defer(
  base::unlink(testthat::test_path("logs"),
    recursive = TRUE, force = TRUE
  ),
  envir = testthat::teardown_env()
)
