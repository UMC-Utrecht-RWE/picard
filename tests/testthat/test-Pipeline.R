# tiny infix to keep lines short and readable
`%+%` <- function(a, b) base::paste0(a, b)

testthat::test_that("Pipeline initializes with YAML config", {
  files <- create_temp_pipeline_yaml(c("A", "B"), marker_path = tempfile())
  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)

  testthat::expect_type(pl$config, "list")
  testthat::expect_equal(names(pl$steps), c("A", "B"))
})

testthat::test_that("Pipeline runs all steps in correct order", {
  marker <- tempfile()
  files <- create_temp_pipeline_yaml(c("A", "B"), marker)

  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)
  pl$run()

  out <- readLines(marker)
  testthat::expect_equal(out, c("A", "B"))
})

testthat::test_that("Pipeline runs only selected step subset", {
  marker <- tempfile()
  files <- create_temp_pipeline_yaml(c("A", "B", "C"), marker)

  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)
  pl$run(step_subset = c("B"))

  out <- readLines(marker)
  testthat::expect_equal(out, "B")
})

testthat::test_that("Pipeline stops on step error", {
  marker <- tempfile()
  ok_path <- create_temp_step_script("OK", marker)
  bad_path <- file.path(tempdir(), "bad_step.R")

  writeLines("stop('boom')", con = bad_path)

  yaml_path <- file.path(tempdir(), "config_error.yaml")
  yaml::write_yaml(list(steps = list(OK = ok_path, FAIL = bad_path)), yaml_path)

  pl <- picard::pipeline$new(config_pipeline = yaml_path)

  testthat::expect_error(pl$run(), regexp = "Pipeline aborted at step: FAIL")

  out <- readLines(marker)
  testthat::expect_equal(out, "OK")
})

testthat::test_that("run_substeps executes selected substeps", {
  marker <- tempfile()
  cfg <- create_substep_config(c("step_a", "step_b"), marker_path = marker)
  cfg$substep[["step_b"]] <- FALSE # skip step_b

  yaml_path <- file.path(tempdir(), "config_error.yaml")
  pl <- picard::pipeline$new(config_pipeline = yaml_path) # dummy

  pl$run_substeps(cfg, step_key = "T2")

  if (!file.exists(marker)) {
    file.create(marker)
  }
  out <- readLines(marker)
  testthat::expect_equal(out, "step_a")
})

testthat::test_that("run_substeps validates config keys", {
  yaml_path <- file.path(tempdir(), "config_error.yaml")
  pl <- picard::pipeline$new(config_pipeline = yaml_path)

  bad1 <- list(substep = list(x = TRUE))
  bad2 <- list(T2 = list(root = "a", source_code = "b"))

  testthat::expect_error(
    pl$run_substeps(bad1, "T2"), "Missing section in config: T2"
  )
  testthat::expect_error(
    pl$run_substeps(bad2, "T2"),
    "Missing 'substep' section"
  )
})

testthat::test_that("load_yaml throws error on missing file", {
  yaml_path <- file.path(tempdir(), "config_error.yaml")
  pl <- picard::pipeline$new(config_pipeline = yaml_path)
  testthat::expect_error(
    pl$load_yaml("nope.yaml"),
    "Missing configuration file"
  )
})
