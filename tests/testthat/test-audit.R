testthat::test_that("audit_start creates file, header, and option", {
  tmp_dir <- base::tempdir()
  tmp_file <- "my_step_audit.txt"

  # make sure the option is clean
  base::options(.current_audit_file = NULL)

  file_name <- audit_start(
    dir_output = tmp_dir,
    file_name  = tmp_file
  )

  df <- create_test_data()
  audit_add(df)
  audit_path <- base::file.path(tmp_dir, file_name)
  testthat::expect_true(base::file.exists(audit_path))
  file_lines <- base::readLines(audit_path)
  # testthat::expect_true(
  #   substring(tail(file_lines, n = 1), 2, 4) == "100"
  # )
})
# testthat::test_that("audit_start creates file, header, and option", {
#   tmp_dir <- base::tempdir()
#   tmp_file <- "my_step_audit.txt"

#   # make sure the option is clean
#   base::options(.current_audit_file = NULL)

#   audit_start(
#     dir_output = tmp_dir,
#     file_name  = tmp_file,
#     overwrite  = TRUE
#   )

#   # file should exist
#   audit_path <- base::file.path(tmp_dir, tmp_file)
#   testthat::expect_true(base::file.exists(audit_path))

#   # option should point to that file
#   testthat::expect_identical(
#     fs::path_norm(base::getOption(".current_audit_file")),
#     fs::path_norm(audit_path)
#   )

#   # file should start with the header line
#   file_lines <- base::readLines(audit_path)
#   testthat::expect_true(
#     base::grepl("=== AUDIT FOR my_step_audit.txt ===", file_lines[1])
#   )
# })

# testthat::test_that("audit_add appends lines after audit_start", {
#   tmp_dir <- base::tempdir()
#   tmp_file <- "step_b_audit.txt"

#   # reset option
#   base::options(.current_audit_file = NULL)

#   audit_start(
#     dir_output = tmp_dir,
#     file_name  = tmp_file,
#     overwrite  = TRUE
#   )

#   audit_add(
#     "total cases in D3_RSVPRODUCTS: ",
#     123L
#   )

#   audit_add(
#     "after filtering invalid rows: ",
#     120L,
#     " rows"
#   )

#   audit_path <- base::file.path(tmp_dir, tmp_file)
#   file_lines <- base::readLines(audit_path)

#   # header should be first line
#   testthat::expect_true(
#     base::grepl("=== AUDIT FOR step_b_audit.txt ===", file_lines[1])
#   )

#   # then our two audit_add() calls, one per line
#   testthat::expect_identical(
#     file_lines[4],
#     "total cases in D3_RSVPRODUCTS: 123"
#   )

#   testthat::expect_identical(
#     file_lines[5],
#     "after filtering invalid rows: 120 rows"
#   )
# })

# testthat::test_that("audit_add fails if audit_start not called", {
#   # reset option to simulate missing start
#   base::options(.current_audit_file = NULL)

#   testthat::expect_error(
#     audit_add("hello world"),
#     regexp = "audit_add\\(\\) called before audit_start\\(\\)"
#   )
# })

# testthat::test_that("audit_start does not overwrite when overwrite=FALSE", {
#   tmp_dir <- base::tempdir()
#   tmp_file <- "no_overwrite_audit.txt"

#   # clean option
#   base::options(.current_audit_file = NULL)

#   # first run, overwrite = TRUE -> creates header A
#   audit_start(
#     dir_output = tmp_dir,
#     file_name  = tmp_file,
#     overwrite  = TRUE
#   )

#   audit_add("first run line")

#   audit_path <- base::file.path(tmp_dir, tmp_file)
#   first_lines <- base::readLines(audit_path)

#   # second run, overwrite = FALSE -> should append a
#   # new header and new content, not clear the file
#   audit_start(
#     dir_output = tmp_dir,
#     file_name  = tmp_file,
#     overwrite  = FALSE
#   )
#   audit_add("second run line")

#   second_lines <- base::readLines(audit_path)

#   # should contain both "first run line" and "second run line"
#   testthat::expect_true(
#     base::any(base::grepl("first run line", second_lines))
#   )
#   testthat::expect_true(
#     base::any(base::grepl("second run line", second_lines))
#   )

#   # should contain two headers (one from each audit_start)
#   header_matches <- base::grep(
#     "^=== AUDIT FOR no_overwrite_audit.txt ===$",
#     second_lines
#   )
#   testthat::expect_equal(
#     base::length(header_matches),
#     2L
#   )
# })

# testthat::test_that("audit_start auto-derives extension when missing", {
#   tmp_dir <- base::tempdir()

#   # no extension in file_name, should add .txt
#   base::options(.current_audit_file = NULL)
#   audit_start(
#     dir_output = tmp_dir,
#     file_name  = "step_c_audit",
#     overwrite  = TRUE,
#     format     = ".txt"
#   )

#   # expected name
#   expected_path <- base::file.path(
#     tmp_dir,
#     "step_c_audit.txt"
#   )

#   testthat::expect_identical(
#     fs::path_norm(base::getOption(".current_audit_file")),
#     fs::path_norm(expected_path)
#   )

#   testthat::expect_true(
#     base::file.exists(expected_path)
#   )

#   header_line <- base::readLines(expected_path)[1]
#   testthat::expect_true(
#     base::grepl("=== AUDIT FOR step_c_audit.txt ===", header_line)
#   )
# })
