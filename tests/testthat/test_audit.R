###############################
# Tests for audit_start
###############################
testthat::test_that("audit_start creates exactly one audit file", {
  tmp <- base::file.path(base::tempdir(), "blabla")
  testthat::expect_no_error(audit_start(tmp))

  base::unlink(tmp, recursive = TRUE, force = TRUE)

  tmp <- base::file.path(base::tempdir(), "blabla")
  base::unlink(tmp, recursive = TRUE, force = TRUE)

  created <- audit_start(dir_output = tmp, file_name = "unit")
  testthat::expect_true(base::dir.exists(tmp))
  testthat::expect_true(base::file.exists(base::file.path(tmp, created)))

  audit_start(dir_output = tmp, file_name = "bob")
  audit_start(dir_output = tmp, file_name = "bob")

  bob_files <- base::list.files(
    tmp,
    pattern = "bob.*\\.txt$", full.names = TRUE
  )
  testthat::expect_equal(length(bob_files), 1)

  base::unlink(tmp, recursive = TRUE, force = TRUE)
})

testthat::test_that("audit_start writes header with deap_name", {
  withr::local_tempdir()
  tmp <- base::file.path(base::tempdir(), "audit_hdr")
  base::unlink(tmp, recursive = TRUE, force = TRUE)

  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  audit_start(
    dir_output = tmp,
    file_name = "unit",
    deap_name = "DEAP_X"
  )

  audit_file <- base::getOption(".current_audit_file")
  testthat::expect_true(base::file.exists(audit_file))

  lines <- base::readLines(audit_file, warn = FALSE)
  testthat::expect_identical(lines[1], "=== Audit for unit (DEAP_X) ===")
})

testthat::test_that("audit_add errors if called before audit_start", {
  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  testthat::expect_error(
    audit_add("x"),
    "audit_add\\(\\) called before audit_start\\(\\)"
  )
})
###############################
# Tests for audit_add
###############################
testthat::test_that("audit_add appends text lines", {
  withr::local_tempdir()
  tmp <- base::file.path(base::tempdir(), "audit_add_txt")
  base::unlink(tmp, recursive = TRUE, force = TRUE)

  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  audit_start(dir_output = tmp, file_name = "unit")
  audit_file <- base::getOption(".current_audit_file")

  audit_add("Hello", " ", "World")

  lines <- base::readLines(audit_file, warn = FALSE)
  testthat::expect_true(any(lines == "Hello World"))
})

testthat::test_that("audit_add writes a data.table (overwrites file)", {
  withr::local_tempdir()
  tmp <- base::file.path(base::tempdir(), "audit_add_dt")
  base::unlink(tmp, recursive = TRUE, force = TRUE)

  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  audit_start(dir_output = tmp, file_name = "unit")
  audit_file <- base::getOption(".current_audit_file")

  dt <- data.table::data.table(id = 1L, n = 2L)
  audit_add(dt)

  lines <- base::readLines(audit_file, warn = FALSE)
  testthat::expect_identical(lines[1], "\"id\" \"n\"")
  testthat::expect_identical(lines[2], "1 2")
})
###############################
# Tests for .get_release_version
###############################
testthat::test_that(".get_release_version returns tag and time in a git repo", {
  testthat::skip_on_os("windows")
  if (!nzchar(base::Sys.which("git"))) {
    testthat::skip("git not available")
  }

  withr::local_tempdir()
  repo <- base::file.path(base::tempdir(), "audit_git_repo")
  base::unlink(repo, recursive = TRUE, force = TRUE)
  base::dir.create(repo, recursive = TRUE, showWarnings = FALSE)

  withr::with_dir(repo, {
    base::system2("git", "init", stdout = TRUE, stderr = TRUE)
    base::system2(
      "git",
      c("config", "user.email", "test@example.com"),
      stdout = TRUE, stderr = TRUE
    )
    base::system2(
      "git",
      c("config", "user.name", "Test User"),
      stdout = TRUE, stderr = TRUE
    )
    base::writeLines("x", "README.md")
    base::system2("git", c("add", "README.md"), stdout = TRUE, stderr = TRUE)
    base::system2(
      "git",
      c("commit", "-m", "init"),
      stdout = TRUE, stderr = TRUE
    )
    base::system2("git", c("tag", "v0.0.1"), stdout = TRUE, stderr = TRUE)

    ver <- .get_release_version()
    testthat::expect_true(is.character(ver))
    testthat::expect_equal(length(ver), 1)
    testthat::expect_true(grepl("v0\\.0\\.1", ver))
    testthat::expect_true(grepl("\\(", ver))
    testthat::expect_true(grepl("\\)", ver))
  })
})
###############################
# Tests for audit_end
###############################
testthat::test_that("audit_end writes footer and clears options", {
  testthat::skip_on_os("windows")
  if (!nzchar(base::Sys.which("git"))) {
    testthat::skip("git not available")
  }

  withr::local_tempdir()
  repo <- base::file.path(base::tempdir(), "audit_end_repo")
  out <- base::file.path(repo, "audits")
  base::unlink(repo, recursive = TRUE, force = TRUE)
  base::dir.create(repo, recursive = TRUE, showWarnings = FALSE)

  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  withr::with_dir(repo, {
    base::system2("git", "init", stdout = TRUE, stderr = TRUE)
    base::system2(
      "git",
      c("config", "user.email", "test@example.com"),
      stdout = TRUE, stderr = TRUE
    )
    base::system2(
      "git",
      c("config", "user.name", "Test User"),
      stdout = TRUE, stderr = TRUE
    )
    base::writeLines("x", "README.md")
    base::system2("git", c("add", "README.md"), stdout = TRUE, stderr = TRUE)
    base::system2(
      "git",
      c("commit", "-m", "init"),
      stdout = TRUE, stderr = TRUE
    )
    base::system2("git", c("tag", "v0.0.1"), stdout = TRUE, stderr = TRUE)

    audit_start(dir_output = out, file_name = "unit")
    audit_file <- base::getOption(".current_audit_file")

    audit_add("Step: ", "1")
    audit_end()

    testthat::expect_true(is.null(base::getOption(".current_audit_file")))
    testthat::expect_true(is.null(base::getOption(".current_start_time")))

    lines <- base::readLines(audit_file, warn = FALSE)
    testthat::expect_true(any(grepl("^Audit completed:", lines)))
    testthat::expect_true(any(grepl("^Generated by:", lines)))
    testthat::expect_true(any(grepl("^Finished at:", lines)))
  })
})

testthat::test_that("audit_add stops if called before audit_start", {
  withr::local_options(list(
    .current_audit_file = NULL,
    .current_start_time = NULL
  ))

  testthat::expect_error(
    audit_add("x"),
    regexp = "audit_add"
  )
})
