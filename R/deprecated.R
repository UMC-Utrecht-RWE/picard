#' Deprecated wrapper for load()
#' @param file_path Path to the file
#' @param file_name Optional if not in file_path. Default NULL
#' @param col_types Optional, define the column type in output per column
#' @param ... Extra args passed to the specific writer
#' @export
read_data <- function(file_path, file_name = NULL, col_types = NULL, ...) {
  .Deprecated(
    new = "load",
    package = utils::packageName(),
    msg = "'read_data()' is deprecated as version 1.2.1; use 'load()' instead."
  )

  picard::load(
    file_path = file_path,
    file_name = file_name,
    col_types = col_types,
    ...
  )
}

#' Deprecated wrapper for save()
#' @param data Object to save (data.table, list of tables, etc.)
#' @param file_path Path to the output file. The extension decides
#' which writer will be used (.csv, .rds, .duckdb, etc.)
#' @param file_name Optional if not in file_path. Default NULL
#' @param create_plot Logical. If TRUE, create plots for the data
#' @param plot_path Optional path to save the plots.
#' Default "data/D6_report"
#' @param exclude_columns_from_plots Optional character vector of column
#' names to exclude from plots.
#' Default: c("person_id", "pregnancy_id", "unique_id")
#' Default will try to exclude this columns if present to avoid privacy issues.
#' If NULL, no columns will be excluded.
#' @param ... Extra args passed to the specific writer
#' @export
save_data <- function(
  data,
  file_path,
  file_name = NULL,
  create_plot = FALSE,
  plot_path = "data/intermediate_plots",
  exclude_columns_from_plots = c(
    "person_id", "pregnancy_id", "unique_id"
  ),
  ...
) {
  .Deprecated(
    new = "save",
    package = utils::packageName(),
    msg = "'save_data()' is deprecated as version 1.2.1; use 'save()' instead."
  )

  picard::save(
    data = data,
    file_path = file_path,
    file_name = file_name,
    create_plot = create_plot,
    plot_path = plot_path,
    exclude_columns_from_plots = exclude_columns_from_plots,
    ...
  )
}
