testthat::test_that("read_data() warns and forwards arguments to load()", {
  testthat::local_mocked_bindings(
    load = function(file_path, file_name = NULL, col_types = NULL, ...) {
      list(
        file_path = file_path,
        file_name = file_name,
        col_types = col_types,
        dots = list(...)
      )
    }
  )

  testthat::expect_warning(
    result <- read_data(
      file_path = "data",
      file_name = "test.csv",
      col_types = list(a = "character"),
      sep = ";"
    ),
    "deprecated"
  )

  testthat::expect_equal(result$file_path, "data")
  testthat::expect_equal(result$file_name, "test.csv")
  testthat::expect_equal(result$col_types, list(a = "character"))
  testthat::expect_equal(result$dots, list(sep = ";"))
})

testthat::test_that("save_data() warns and forwards arguments to save()", {
  testthat::local_mocked_bindings(
    save = function(data,
                    file_path,
                    file_name = NULL,
                    create_plot = FALSE,
                    plot_path = "data/intermediate_plots",
                    exclude_columns_from_plots = c(
                      "person_id", "pregnancy_id", "unique_id"
                    ),
                    ...) {
      list(
        data = data,
        file_path = file_path,
        file_name = file_name,
        create_plot = create_plot,
        plot_path = plot_path,
        exclude_columns_from_plots = exclude_columns_from_plots,
        dots = list(...)
      )
    }
  )

  x <- data.frame(a = 1:3)

  testthat::expect_warning(
    result <- save_data(
      data = x,
      file_path = "out",
      file_name = "test.csv",
      create_plot = TRUE,
      plot_path = "plots",
      exclude_columns_from_plots = "a",
      compress = TRUE
    ),
    "deprecated"
  )

  testthat::expect_equal(result$data, x)
  testthat::expect_equal(result$file_path, "out")
  testthat::expect_equal(result$file_name, "test.csv")
  testthat::expect_true(result$create_plot)
  testthat::expect_equal(result$plot_path, "plots")
  testthat::expect_equal(result$exclude_columns_from_plots, "a")
  testthat::expect_equal(result$dots, list(compress = TRUE))
})
