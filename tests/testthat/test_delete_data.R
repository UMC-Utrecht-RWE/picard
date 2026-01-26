##################################
# Tests delete_parquet_partition #
##################################
testthat::test_that("Test with dry_run TRUE", {
  dataset_dir <- testthat::test_path("data", "parquet_hives")

  testthat::expect_message(
    delete_parquet_partition(
      dataset_dir = dataset_dir,
      partition_ids = c("B_COAGDEF_AESI", "B_COAGDEF_COV")
    ),
    regexp = "[DRY RUN] Would delete:",
    fixed = TRUE
  )
})

testthat::test_that("Test with input errors", {

  testthat::expect_error(
    delete_parquet_partition(),
    regexp = "argument \"dataset_dir\" is missing, with no default",
    fixed = TRUE
  )

  dataset_dir <- testthat::test_path("data", "parquet_hives")
  testthat::expect_error(
    delete_parquet_partition(dataset_dir = dataset_dir),
    regexp = "argument \"partition_ids\" is missing, with no default",
    fixed = TRUE
  )
})

testthat::test_that("Test with dry_run FALSE", {
  temp_dir <- withr::local_tempdir()
  dataset_dir <- testthat::test_path("data", "parquet_hives")

  fs::dir_copy(
    dataset_dir,
    temp_dir
  )

  delete_parquet_partition(
    dataset_dir = fs::path(temp_dir, "parquet_hives"),
    partition_ids = c("B_COAGDEF_AESI", "B_COAGDEF_COV"),
    dry_run = FALSE
  )

  testthat::expect_false(
    fs::dir_exists(
      fs::path(temp_dir, "parquet_hives", "concept_id=B_COAGDEF_AESI")
    )
  )
  testthat::expect_false(
    fs::dir_exists(
      fs::path(temp_dir, "parquet_hives", "concept_id=B_COAGDEF_COV")
    )
  )

})