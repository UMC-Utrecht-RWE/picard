`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T5Pipeline initializes and loads config", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T5", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T5.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t5 <- picard::t5_pipeline$new(config_t5 = yaml_path)

  testthat::expect_type(t5$T5, "list")
  testthat::expect_named(t5$T5, c("T5", "substep", "parquet_files"))
})

testthat::test_that("T5Pipeline run executes enabled substeps", {
  marker <- base::tempfile()

  cfg <- create_substep_config(
    substep_names = c(s1 = TRUE, s2 = FALSE), step_name = "T5",
    marker_path = marker
  )

  yaml_path <- base::file.path(base::tempdir(), "config_T5.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t5 <- picard::t5_pipeline$new(config_t5 = yaml_path)

  testthat::expect_no_error(t5$run())

  out <- if (base::file.exists(marker)) {
    base::readLines(marker)
  } else {
    character()
  }
  testthat::expect_equal(out, "s1")
})

testthat::test_that("T5Pipeline clean() is a no-op", {
  yaml_path <- file.path(tempdir(), "config_T5.yaml")
  t5 <- picard::t5_pipeline$new(
    config_t5 = yaml_path
  )

  testthat::expect_invisible(t5$clean())
})

testthat::test_that("Test with dry_run TRUE", {
  cfg <- create_substep_config(
    c(s1 = TRUE, s2 = TRUE),
    marker_path = tempfile(), step_name = "T5"
  )
  yaml_path <- file.path(tempdir(), "config_t5.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t5 <- picard::t5_pipeline$new(
    config_t5 = yaml_path
  )

  testthat::expect_message(
    t5$delete_data(),
    regexp = "[DRY RUN] Would delete:",
    fixed = TRUE
  )
})
