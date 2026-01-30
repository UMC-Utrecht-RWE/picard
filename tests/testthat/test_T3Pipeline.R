`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T3Pipeline initializes and loads config", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T3", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T3.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t3 <- picard::t3_pipeline$new(config_t3 = yaml_path)

  testthat::expect_type(t3$T3, "list")
  testthat::expect_named(t2$T2, c("T2", "substep", "cleanup", "parquet_files"))
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


## test clean
testthat::test_that("Check if clean delete files in folder", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T3", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T3.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t3 <- picard::t3_pipeline$new(config_t3 = yaml_path)

  dir_ <- fs::dir_create(fs::path(cfg$T3$root, cfg$T3$intermediate))
  file_1 <- fs::file_create(dir_, "file_1.txt")
  file_2 <- fs::file_create(dir_, "file_2.txt")
  writeLines("Ciao", con = file_1)
  writeLines("Mondo", con = file_2)

  t3$clean()

  testthat::expect_true(!file.exists(file_1))
  testthat::expect_true(!file.exists(file_2))
})

testthat::test_that("Test with dry_run TRUE", {
  cfg <- create_substep_config(
    c(s1 = TRUE, s2 = TRUE),
    marker_path = tempfile(), step_name = "T3"
  )
  yaml_path <- file.path(tempdir(), "config_t3.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t3 <- picard::t3_pipeline$new(
    config_t3 = yaml_path
  )

  testthat::expect_message(
    t3$delete_data(),
    regexp = "[DRY RUN] Would delete:",
    fixed = TRUE
  )
})
