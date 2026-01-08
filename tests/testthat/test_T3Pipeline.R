`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T3Pipeline initializes and loads config", {
  cfg <- create_substep_config(
    c("s1", "s2"), step_name = "T3", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T3.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t3 <- picard::t3_pipeline$new(config_t3 = yaml_path)

  testthat::expect_type(t3$T3, "list")
  testthat::expect_named(t3$T3, c("T3", "substep"))
})

testthat::test_that("T3Pipeline run executes enabled substeps", {
  marker <- base::tempfile()

  cfg <- create_substep_config(
    substep_names = c(s1 = TRUE, s2 = FALSE), step_name = "T3",
    marker_path = marker
  )

  yaml_path <- base::file.path(base::tempdir(), "config_T3.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t3 <- picard::t3_pipeline$new(config_t3 = yaml_path)

  testthat::expect_no_error(t3$run())

  out <- if (base::file.exists(marker)) {
    base::readLines(marker)
  } else {
    character()
  }
  testthat::expect_equal(out, "s1")
})

testthat::test_that("T3Pipeline clean() is a no-op", {
  yaml_path <- file.path(tempdir(), "config_T3.yaml")
  t3 <- picard::t3_pipeline$new(
    config_t3 = yaml_path
  )

  testthat::expect_invisible(t3$clean())
})
