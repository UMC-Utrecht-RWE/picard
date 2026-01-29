`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("T2Pipeline initializes and loads config", {
  cfg <- create_substep_config(c("s1", "s2"), marker_path = tempfile())
  yaml_path <- file.path(tempdir(), "config_T2.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t2 <- picard::t2_pipeline$new(config_t2 = yaml_path, yaml_path)

  testthat::expect_type(t2$T2, "list")
  testthat::expect_named(t2$T2, c("T2", "substep", "cleanup"))
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

  testthat::expect_type(t2$T2, "list")
  testthat::expect_named(t2$T2, c("T2", "substep", "cleanup"))
})


## test clean
testthat::test_that("Check if clean delete files in folder", {
  cfg <- create_substep_config(c("s1", "s2"), marker_path = tempfile())
  yaml_path <- file.path(tempdir(), "config_T2.yaml")
  yaml::write_yaml(cfg, yaml_path)

  t2 <- picard::t2_pipeline$new(config_t2 = yaml_path, yaml_path)

  dir_ <- fs::dir_create(fs::path(cfg$T2$root, cfg$T2$intermediate))
  file_1 <- fs::file_create(dir_, "file_1.txt")
  file_2 <- fs::file_create(dir_, "file_2.txt")
  writeLines("Ciao", con = file_1)
  writeLines("Mondo", con = file_2)

  t2$clean()

  testthat::expect_true(!file.exists(file_1))
  testthat::expect_true(!file.exists(file_2))
})