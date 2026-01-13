`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T2Pipeline initializes and loads config", {
  cfg <- create_substep_config(c("s1", "s2"), marker_path = tempfile())
  yaml_path <- file.path(tempdir(), "config_T2.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t2 <- picard::t2_pipeline$new(config_t2 = yaml_path, yaml_path)

  testthat::expect_type(t2$t2, "list")
  testthat::expect_named(t2$t2, c("T2", "substep"))
})

testthat::test_that("T2Pipeline run executes enabled substeps", {
  marker <- base::tempfile()

  cfg <- create_substep_config(
    substep_names = c(s1 = TRUE, s2 = FALSE),
    marker_path = marker
  )

  yaml_path <- base::file.path(base::tempdir(), "config_T2.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t2 <- picard::t2_pipeline$new(config_t2 = yaml_path, yaml_path)

  testthat::expect_no_error(t2$run())

  out <- if (base::file.exists(marker)) {
    base::readLines(marker)
  } else {
    character()
  }
  testthat::expect_equal(out, "s1")
})

testthat::test_that("T2Pipeline clean() is a no-op", {
  yaml_path <- file.path(tempdir(), "config_T2.yaml")
  t2 <- picard::t2_pipeline$new(
    config_t2 = yaml_path, yaml_path
  )

  testthat::expect_invisible(t2$clean())
})

testthat::test_that("T2Pipeline initializes and skip_substeps", {
  cfg <- create_substep_config(
    c(s1 = TRUE, s2 = TRUE),
    marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T2.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t2 <- picard::t2_pipeline$new(
    config_t2 = yaml_path,
    yaml_path,
    skip_substeps = TRUE
  )

  testthat::expect_type(t2$t2, "list")
  testthat::expect_named(t2$t2, c("T2", "substep"))
})
