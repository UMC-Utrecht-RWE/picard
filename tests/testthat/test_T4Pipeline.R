`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T4Pipeline initializes and loads config", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T4", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T4.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t4 <- picard::t4_pipeline$new(config_t4 = yaml_path)

  testthat::expect_type(t4$T4, "list")
  testthat::expect_named(t4$T4, c("T4", "substep"))
})

testthat::test_that("T4Pipeline run executes enabled substeps", {
  marker <- base::tempfile()

  cfg <- create_substep_config(
    substep_names = c(s1 = TRUE, s2 = FALSE), step_name = "T4",
    marker_path = marker
  )

  yaml_path <- base::file.path(base::tempdir(), "config_T4.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t4 <- picard::t4_pipeline$new(config_t4 = yaml_path)

  testthat::expect_no_error(t4$run())

  out <- if (base::file.exists(marker)) {
    base::readLines(marker)
  } else {
    character()
  }
  testthat::expect_equal(out, "s1")
})

testthat::test_that("T4Pipeline clean() is a no-op", {
  yaml_path <- file.path(tempdir(), "config_T4.yaml")
  t4 <- picard::t4_pipeline$new(
    config_t4 = yaml_path
  )

  testthat::expect_invisible(t4$clean())
})
