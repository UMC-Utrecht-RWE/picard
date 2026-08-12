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

testthat::test_that("Testing skip step function", {
  config_step <- tempfile(fileext = ".yaml")
  config_project <- tempfile(fileext = ".yaml")
  output_a <- tempfile(fileext = ".txt")
  output_b <- tempfile(fileext = ".txt")
  on.exit(unlink(c(config_step, config_project, output_a, output_b)))
  yaml::write_yaml(
    list(substep = list(
      A = TRUE,
      B = TRUE
    )),
    config_step
  )
  yaml::write_yaml(
    list(
      A = list(
        input = "file_A.txt",
        output = output_a
      ),
      B = list(
        input = "file_B.txt",
        output = output_b
      ),
      partition_col = "concept_id"
    ),
    config_project
  )
  # Create output file for step A to simulate existing output
  file.create(output_a)

  pl <- picard::pipeline$new(config_pipeline = config_project)
  config_file_input <- yaml::read_yaml(config_step)
  config_file_output <- pl$skip_step(
    config_file = config_file_input,
    project = yaml::read_yaml(config_project)
  )

  testthat::expect_false(
    config_file_output$substep$A
  )
  testthat::expect_true(
    config_file_output$substep$B
  )
})

testthat::test_that("clean previews and deletes only dedicated folder contents", {
  files <- create_temp_pipeline_yaml(c("A", "B"), marker_path = tempfile())
  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)

  clean_dir <- tempfile("picard-clean-")
  dir.create(clean_dir)
  on.exit(unlink(clean_dir, recursive = TRUE), add = TRUE)

  file_1 <- file.path(clean_dir, "file_1.txt")
  file_2 <- file.path(clean_dir, "file_2.txt")
  nested_dir <- file.path(clean_dir, "nested")
  dir.create(nested_dir)
  writeLines("Ciao", con = file_1)
  writeLines("Mondo", con = file_2)
  writeLines("Nested", con = file.path(nested_dir, "file_3.txt"))
  expected_contents <- fs::path_norm(c(file_1, file_2, nested_dir))

  testthat::expect_message(
    preview <- pl$clean(clean_dir),
    "[DRY RUN]",
    fixed = TRUE
  )
  testthat::expect_setequal(preview, expected_contents)
  testthat::expect_true(all(file.exists(c(file_1, file_2, nested_dir))))

  deleted <- pl$clean(clean_dir, dry_run = FALSE)

  testthat::expect_setequal(deleted, expected_contents)
  testthat::expect_false(any(file.exists(c(file_1, file_2, nested_dir))))
  testthat::expect_true(dir.exists(clean_dir))
})

testthat::test_that("clean refuses shared and dangerous directories", {
  files <- create_temp_pipeline_yaml(c("A"), marker_path = tempfile())
  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)

  testthat::expect_error(pl$clean(tempdir()), "protected path")
  testthat::expect_error(pl$clean(getwd()), "protected path")
  testthat::expect_error(pl$clean(""), "one non-empty path")
})

##################################
# Tests delete_parquet_partition #
##################################
testthat::test_that("Test with dry_run TRUE", {
  files <- create_temp_pipeline_yaml(c("A", "B"), marker_path = tempfile())
  pl <- picard::pipeline$new(config_pipeline = files$yaml_path)

  dataset_dir <- testthat::test_path("data", "parquet_hives")

  config_step <- tempfile(fileext = ".yaml")
  on.exit(unlink(config_step))
  yaml::write_yaml(
    list(spec = list(
      type = "parquet_partition",
      dataset_dir = dataset_dir,
      partition_ids = c("B_COAGDEF_AESI", "B_COAGDEF_COV")
    )),
    config_step
  )
  config_file_input <- yaml::read_yaml(config_step)

  testthat::expect_message(
    pl$delete_data(
      spec = config_file_input$spec
    ),
    regexp = "[DRY RUN] Would delete:",
    fixed = TRUE
  )
})
