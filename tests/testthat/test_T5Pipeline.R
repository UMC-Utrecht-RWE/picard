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
  testthat::expect_named(t5$T5, c("T5", "substep", "cleanup"))
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


## test clean
testthat::test_that("Check if clean delete files in folder", {
  cfg <- create_substep_config(
    c("s1", "s2"),
    step_name = "T5", marker_path = tempfile()
  )
  yaml_path <- file.path(tempdir(), "config_T5.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t5 <- picard::t5_pipeline$new(config_t5 = yaml_path)

  dir_ <- fs::dir_create(fs::path(cfg$T5$root, cfg$T5$intermediate))
  file_1 <- fs::file_create(dir_, "file_1.txt")
  file_2 <- fs::file_create(dir_, "file_2.txt")
  writeLines("Ciao", con = file_1)
  writeLines("Mondo", con = file_2)

  t5$clean()

  testthat::expect_true(!file.exists(file_1))
  testthat::expect_true(!file.exists(file_2))
})
