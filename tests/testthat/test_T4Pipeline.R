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
  testthat::expect_named(
    t4$T4,
    c("T4", "substep", "cleanup", "parquet_files", "partition_col")
  )
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


## test clean
testthat::test_that("Check if clean delete files in folder", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T4", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T4.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t4 <- picard::t4_pipeline$new(config_t4 = yaml_path)

  dir_ <- fs::dir_create(fs::path(cfg$T4$root, cfg$T4$intermediate))
  file_1 <- fs::file_create(dir_, "file_1.txt")
  file_2 <- fs::file_create(dir_, "file_2.txt")
  writeLines("Ciao", con = file_1)
  writeLines("Mondo", con = file_2)

  t4$clean()

  testthat::expect_true(!file.exists(file_1))
  testthat::expect_true(!file.exists(file_2))
})

testthat::test_that("Test with dry_run TRUE", {
  cfg <- create_substep_config(
    c(s1 = TRUE, s2 = TRUE),
    marker_path = tempfile(), step_name = "T4"
  )
  yaml_path <- file.path(tempdir(), "config_t4.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t4 <- picard::t4_pipeline$new(
    config_t4 = yaml_path
  )

  testthat::expect_message(
    t4$delete_data(),
    regexp = "[DRY RUN] Would delete:",
    fixed = TRUE
  )
})
