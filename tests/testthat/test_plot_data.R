# Helper to create test data
create_test_data <- function() {
  data.table::data.table(
    num = stats::rnorm(100),
    int = base::sample.int(50, 100, replace = TRUE),
    logi = base::sample(c(TRUE, FALSE, NA), 100,
      replace = TRUE,
      prob = c(0.45, 0.45, 0.10)
    ),
    fct = base::factor(base::sample(LETTERS[1:4], 100, replace = TRUE)),
    chr = base::sample(c(letters[1:3], NA), 100, replace = TRUE),
    date = as.Date("2023-01-01") + base::sample.int(365, 100, replace = TRUE),
    time = as.POSIXct("2023-01-01", tz = "UTC") +
      base::sample.int(86400, 100, replace = TRUE)
  )
}

# Test: Registry initialization
testthat::test_that("plotter registry initializes with built-in plotters", {
  # Force re-initialization
  .init_plotter_registry()

  testthat::expect_true(
    !is.null(get_feature_plotter("dist"))
  )
  testthat::expect_true(
    !is.null(get_feature_plotter("missing"))
  )
  testthat::expect_true(
    !is.null(get_feature_plotter("boxplot"))
  )
})

testthat::test_that("get_feature_plotter returns NULL for unknown plotter", {
  testthat::expect_null(
    get_feature_plotter("unknown_plotter")
  )
})

# Test: register_feature_plotter
testthat::test_that("register_feature_plotter adds custom plotter", {
  custom_plotter <- function(dt, opts) {
    list(test_plot = ggplot2::ggplot())
  }

  result <- register_feature_plotter("custom", custom_plotter)

  testthat::expect_true(result)
  testthat::expect_true(
    !is.null(get_feature_plotter("custom"))
  )
})

testthat::test_that("register_feature_plotter validates inputs", {
  testthat::expect_error(
    register_feature_plotter(123, function(x) x),
    "is.character\\(name\\) is not TRUE"
  )

  testthat::expect_error(
    register_feature_plotter("test", "not_a_function"),
    "is.function\\(fun\\) is not TRUE"
  )
})

# Test: .col_buckets
testthat::test_that(".col_buckets correctly categorizes columns", {
  dt <- create_test_data()
  buckets <- .col_buckets(dt)

  testthat::expect_equal(
    sort(buckets$numeric),
    sort(c("num", "int"))
  )
  testthat::expect_equal(buckets$logical, "logi")
  testthat::expect_equal(
    sort(buckets$date),
    sort(c("date", "time"))
  )
  testthat::expect_equal(buckets$factor, "fct")
  testthat::expect_equal(buckets$char, "chr")
})

testthat::test_that(".col_buckets respects column selection", {
  dt <- create_test_data()
  buckets <- .col_buckets(dt, cols = c("num", "fct"))

  testthat::expect_equal(buckets$numeric, "num")
  testthat::expect_equal(buckets$factor, "fct")
  testthat::expect_length(buckets$logical, 0)
  testthat::expect_length(buckets$char, 0)
})

# Test: .top_n_factor
testthat::test_that(".top_n_factor limits levels correctly", {
  x <- c(
    rep("A", 50), rep("B", 30), rep("C", 10),
    rep("D", 5), rep("E", 3), rep("F", 2)
  )

  result <- .top_n_factor(x, n = 3)

  testthat::expect_s3_class(result, "factor")
  testthat::expect_equal(levels(result), c("A", "B", "C", "Other"))
  testthat::expect_equal(sum(result == "Other"), 10) # D, E, F
})

testthat::test_that(".top_n_factor handles n larger than unique values", {
  x <- c("A", "B", "C")
  result <- .top_n_factor(x, n = 10)

  testthat::expect_equal(levels(result), c("A", "B", "C", "Other"))
  testthat::expect_equal(sum(result == "Other"), 0)
})

# Test: .summary_stats
testthat::test_that(".summary_stats generates correct output for numeric", {
  x <- c(1, 2, 3, NA, 5)
  result <- .summary_stats(x)

  testthat::expect_match(result, "n=5")
  testthat::expect_match(result, "NA=1")
  testthat::expect_match(result, "mean=2.75")
  testthat::expect_match(result, "median=2.5")
})

testthat::test_that(".summary_stats generates correct output for character", {
  x <- c("a", "b", "a", NA, "c")
  result <- .summary_stats(x)

  testthat::expect_match(result, "n=5")
  testthat::expect_match(result, "NA=1")
  testthat::expect_match(result, "unique=3")
})

# Test: .dist_plotter
testthat::test_that(".dist_plotter creates plots for all column types", {
  dt <- create_test_data()
  opts <- .default_opts()

  plots <- .dist_plotter(dt, opts)

  testthat::expect_type(plots, "list")
  testthat::expect_true(length(plots) > 0)

  # Check that we have plots for each column type
  testthat::expect_true("num" %in% names(plots))
  testthat::expect_true("logi" %in% names(plots))
  testthat::expect_true("fct" %in% names(plots))
  testthat::expect_true("chr" %in% names(plots))
  testthat::expect_true("date" %in% names(plots))
})

testthat::test_that(".dist_plotter returns ggplot objects", {
  dt <- create_test_data()
  opts <- .default_opts()

  plots <- .dist_plotter(dt, opts)

  testthat::expect_s3_class(plots[[1]], "ggplot")
})

testthat::test_that(".dist_plotter respects column selection", {
  dt <- create_test_data()
  opts <- .default_opts(cols = c("num", "fct"))

  plots <- .dist_plotter(dt, opts)

  testthat::expect_equal(sort(names(plots)), sort(c("num", "fct")))
})

testthat::test_that(".dist_plotter respects sampling", {
  dt <- create_test_data()
  opts <- .default_opts(sample_n = 50, seed = 42)

  # Should not error with sampling
  testthat::expect_no_error({
    plots <- .dist_plotter(dt, opts)
  })
})

# Test: .missing_plotter
testthat::test_that(".missing_plotter creates missing data plot", {
  dt <- create_test_data()
  opts <- .default_opts()

  plots <- .missing_plotter(dt, opts)

  testthat::expect_type(plots, "list")
  testthat::expect_true("missing_data" %in% names(plots))
  testthat::expect_s3_class(plots$missing_data, "ggplot")
})

testthat::test_that(".missing_plotter returns empty list for no columns", {
  dt <- data.table::data.table(x = 1:10)
  opts <- .default_opts(cols = character(0))

  plots <- .missing_plotter(dt, opts)

  testthat::expect_length(plots, 0)
})

# Test: .boxplot_plotter
testthat::test_that(".boxplot_plotter creates plots for numeric columns", {
  dt <- create_test_data()
  opts <- .default_opts()

  plots <- .boxplot_plotter(dt, opts)

  testthat::expect_type(plots, "list")
  testthat::expect_true("num" %in% names(plots))
  testthat::expect_true("int" %in% names(plots))
  testthat::expect_s3_class(plots$num, "ggplot")
})

testthat::test_that(".boxplot_plotter ignores non-numeric columns", {
  dt <- create_test_data()
  opts <- .default_opts()

  plots <- .boxplot_plotter(dt, opts)

  # Should only have numeric columns
  testthat::expect_false("chr" %in% names(plots))
  testthat::expect_false("fct" %in% names(plots))
  testthat::expect_false("logi" %in% names(plots))
})

testthat::test_that("plot_data_features saves PNG files", {
  # Option A: write to a temp file
  tmp_log <- base::tempfile(fileext = ".log")
  logger::log_appender(logger::appender_file(tmp_log),
    namespace = "picard"
  )

  # Option B: silence logging (no I/O)
  # logger::log_appender(function(...) invisible(NULL),
  #                      namespace = "picard")

  dt <- create_test_data()
  temp_file <- base::tempfile(fileext = ".csv")

  paths <- plot_data_features(
    data = dt,
    file_name = tools::file_path_sans_ext(basename(temp_file)),
    chart_types = "dist",
    ncol = 2,
    nrow = 2
  )

  testthat::expect_type(paths, "character")
  testthat::expect_true(base::length(paths) > 0L)
  testthat::expect_true(base::all(base::file.exists(paths)))
  testthat::expect_true(base::all(base::grepl("\\.png$", paths)))

  base::unlink(paths)
  # If Option A used:
  base::unlink(tmp_log)
})


testthat::test_that("plot_data_features handles multiple chart types", {
  dt <- create_test_data()
  temp_file <- tempfile(fileext = ".csv")

  paths <- plot_data_features(
    data = dt,
    file_path = temp_file,
    chart_types = c("dist", "missing", "boxplot"),
    ncol = 2,
    nrow = 2
  )

  # Should have files for each chart type
  testthat::expect_true(any(grepl("dist", paths)))
  testthat::expect_true(any(grepl("missing", paths)))
  testthat::expect_true(any(grepl("boxplot", paths)))

  # Cleanup
  unlink(paths)
})

testthat::test_that("plot_data_features warns on unknown chart type", {
  dt <- create_test_data()
  temp_file <- tempfile(fileext = ".csv")

  # Should still return character(0) invisibly
  result <- suppressWarnings(
    plot_data_features(
      data = dt,
      file_path = temp_file,
      chart_types = "nonexistent_type"
    )
  )
  testthat::expect_length(result, 0)
})

testthat::test_that("plot_data_features respects column selection", {
  dt <- create_test_data()
  temp_file <- tempfile(fileext = ".csv")

  paths <- plot_data_features(
    data = dt,
    file_path = temp_file,
    chart_types = "dist",
    cols = c("num", "fct"),
    ncol = 2,
    nrow = 2
  )

  testthat::expect_true(length(paths) > 0)

  # Cleanup
  unlink(paths)
})

# testthat::test_that("plot_data_features validates file_path", {
#   dt <- create_test_data()

#   testthat::expect_error(
#     plot_data_features(data = dt, file_path = NULL),
#     "is.character\\(file_path\\) is not TRUE"
#   )

#   testthat::expect_error(
#     plot_data_features(data = dt, file_path = c("a", "b")),
#     "length\\(file_path\\) == 1 is not TRUE"
#   )
# })

testthat::test_that("plot_data_features creates multi-page output", {
  # Create data with many columns to force pagination
  dt <- data.table::data.table(
    col1 = rnorm(100), col2 = rnorm(100), col3 = rnorm(100),
    col4 = rnorm(100), col5 = rnorm(100), col6 = rnorm(100),
    col7 = rnorm(100), col8 = rnorm(100), col9 = rnorm(100),
    col10 = rnorm(100), col11 = rnorm(100), col12 = rnorm(100)
  )

  temp_file <- tempfile(fileext = ".csv")

  paths <- plot_data_features(
    data = dt,
    file_path = temp_file,
    chart_types = "dist",
    ncol = 2,
    nrow = 2 # 4 plots per page, 12 columns = 3 pages
  )

  # Should have multiple pages
  testthat::expect_true(length(paths) >= 3)
  testthat::expect_true(any(grepl("page1", paths)))
  testthat::expect_true(any(grepl("page2", paths)))
  testthat::expect_true(any(grepl("page3", paths)))

  # Cleanup
  unlink(paths)
})

# Test: .default_opts
testthat::test_that(".default_opts returns correct defaults", {
  opts <- .default_opts()

  testthat::expect_equal(opts$ncol, 3)
  testthat::expect_equal(opts$nrow, 3)
  testthat::expect_equal(opts$width, 12)
  testthat::expect_equal(opts$height, 9)
  testthat::expect_equal(opts$max_levels, 15)
  testthat::expect_equal(opts$sample_n, 0)
  testthat::expect_true(is.na(opts$seed))
  testthat::expect_equal(opts$title_prefix, "Features")
  testthat::expect_true(opts$show_stats)
  testthat::expect_null(opts$cols)
})

testthat::test_that(".default_opts merges custom options", {
  opts <- .default_opts(ncol = 5, custom_param = "test")

  testthat::expect_equal(opts$ncol, 5)
  testthat::expect_equal(opts$nrow, 3) # default
  testthat::expect_equal(opts$custom_param, "test")
})

# Test: .path_pngs
# testthat::test_that(".path_pngs creates directory if missing", {
#   temp_dir <- file.path(tempdir(), "test_plot_dir", "subdir")
#   temp_file <- file.path(temp_dir, "data.csv")

#   # Directory shouldn't exist yet
#   testthat::expect_false(dir.exists(temp_dir))

#   # Calling .path_pngs should create it
#   result <- .path_pngs(temp_file, "test")

#   testthat::expect_true(dir.exists(temp_dir))

#   # Cleanup
#   unlink(file.path(tempdir(), "test_plot_dir"), recursive = TRUE)
# })

# testthat::test_that(".path_pngs builds path and ensures dir", {
#   tmp_root <- base::tempfile(pattern = "pathpngs_")
#   base::on.exit(base::unlink(tmp_root, recursive = TRUE, force = TRUE))
#   out_dir <- base::file.path(tmp_root, "lvl1", "lvl2")
#   in_path <- base::file.path(out_dir, "table.csv")

#   out <- .path_pngs(in_path, "dist_page1")

#   testthat::expect_true(base::dir.exists(out_dir))

#   exp_base <- tools::file_path_sans_ext(in_path)
#   exp <- base::paste0(exp_base, "_features_dist_page1.png")
#   testthat::expect_identical(out, exp)
# })
