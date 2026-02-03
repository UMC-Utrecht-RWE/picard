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

testthat::test_that("Test with dry_run TRUE", {
  dataset_dir <- testthat::test_path("data", "parquet_hives")

  testthat::expect_message(
    delete_parquet_partition(
      dataset_dir = dataset_dir,
      partition_ids = c("B_COAGDEF_COV_xxx")
    ),
    regexp = "Not found:",
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

######################
# Tests delete_paths #
######################
testthat::test_that("Test delete_paths with paths", {
  temp_dir <- withr::local_tempdir()
  file_1 <- fs::file_create(fs::path(temp_dir, "file_1.txt"))
  file_2 <- fs::file_create(fs::path(temp_dir, "file_2.txt"))

  testthat::expect_error(
    delete_paths(),
    regexp = "`paths` is required.",
    fixed = TRUE
  )

  testthat::expect_error(
    delete_paths(list(1, 2)),
    regexp = "`paths` must be a character vector or list of character.",
    fixed = TRUE
  )

  testthat::expect_message(
    delete_paths(
      paths = list(file_1, file_2),
      dry_run = TRUE
    ),
    regexp = "[DRY RUN] The following paths would be deleted:",
    fixed = TRUE
  )

  testthat::expect_message(
    delete_paths(
      paths = list(file_1, file_2),
      dry_run = FALSE
    ),
    regexp = "Deleted the following paths:",
    fixed = TRUE
  )

  testthat::expect_false(fs::file_exists(file_1))
  testthat::expect_false(fs::file_exists(file_2))
  testthat::expect_true(fs::dir_exists(temp_dir))
})

testthat::test_that("Test delete_paths with dirs", {
  temp_dir <- withr::local_tempdir()
  file_1 <- fs::file_create(fs::path(temp_dir, "file_1.txt"))
  file_2 <- fs::file_create(fs::path(temp_dir, "file_2.txt"))

  testthat::expect_message(
    delete_paths(
      paths = temp_dir,
      dry_run = FALSE,
      del_dir = TRUE
    ),
    regexp = "Deleted the following paths:",
    fixed = TRUE
  )

  testthat::expect_false(fs::file_exists(file_1))
  testthat::expect_false(fs::file_exists(file_2))
  testthat::expect_false(fs::dir_exists(temp_dir))
})

# testthat::test_that("Test delete_paths with dirs", {
#   temp_dir <- withr::local_tempdir()
#   file_1 <- fs::file_create(fs::path(temp_dir, "file_1.txt"))
#   file_2 <- fs::file_create(fs::path(temp_dir, "file_2.txt"))

#   testthat::expect_message(
#     delete_paths(
#       paths = list(temp_dir, file_1, file_2),
#       dry_run = FALSE,
#       del_dir = FALSE
#     ),
#     regexp = "Deleted the following paths:",
#     fixed = TRUE
#   )

#   testthat::expect_false(fs::file_exists(file_1))
#   testthat::expect_false(fs::file_exists(file_2))
#   testthat::expect_true(fs::dir_exists(temp_dir))
# })
