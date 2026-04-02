#' Load SQL file as a single query string with variable interpolation
#'
#' @name load_sql_query
#' @description
#' Reads a .sql script from disk, normalises tabs to spaces,
#' converts full-line `-- ...` comments into `/* ... */`,
#' and optionally interpolates variables using \code{\{var_name\}} syntax.
#'
#' @param file_path path to the .sql file
#' @param encoding file encoding passed to readLines(); default "UTF-8"
#' @param params named list of parameters to interpolate into the SQL.
#'   Use \code{\{param\}} in your SQL file to reference these.
#'
#' @return character(1) containing the full SQL with interpolated values
#' @export
#'
#' @examples
#' \dontrun{
#' # SQL file content: SELECT * FROM {schema}.{table} WHERE id > {min_id}
#' query <- load_sql_query(
#'   "queries/my_query.sql",
#'   params = list(
#'     schema = "public",
#'     table = "users",
#'     min_id = 100
#'   )
#' )
#' }
load_sql_query <- function(
    file_path,
    encoding = "UTF-8",
    params = NULL) {
  # Validate file exists
  if (!file.exists(file_path)) {
    stop("SQL file not found: ", file_path, call. = FALSE)
  }

  con <- base::file(file_path, open = "r", encoding = encoding)
  on.exit(close(con), add = TRUE)

  lines <- readLines(con, warn = FALSE)

  # Normalize each line
  lines <- vapply(
    lines,
    FUN.VALUE = character(1),
    FUN = function(l) {
      # Replace tabs with single spaces
      l <- gsub("\\t", " ", l, fixed = FALSE)

      # If the line starts with `--` wrap the line as /* ... */
      if (grepl("^\\s*--", l)) {
        l_clean <- sub("^\\s*--\\s?", "", l)
        l <- paste0("/* ", l_clean, " */")
      }

      l
    }
  )

  # Collapse back to one string with newlines
  sql <- paste(lines, collapse = "\n")

  # Interpolate parameters if provided
  if (!is.null(params)) {
    sql <- interpolate_sql_params(
      sql,
      params
    )
  }

  sql
}


#' Interpolate parameters into SQL query
#'
#' @param sql character string containing SQL with \code{\{param\}} placeholders
#' @param params named list of parameters
#'
#' @return character string with interpolated values
#' @keywords internal
interpolate_sql_params <- function(sql, params) {
  if (!is.list(params) || is.null(names(params))) {
    stop("params must be a named list", call. = FALSE)
  }

  # Find all placeholders in the SQL
  placeholders <- unique(
    regmatches(sql, gregexpr("\\{[^}]+\\}", sql))[[1]]
  )

  # Extract parameter names from placeholders
  placeholder_names <- gsub("^\\{|\\}$", "", placeholders)

  # Check for missing parameters
  missing_params <- setdiff(placeholder_names, names(params))
  if (length(missing_params) > 0) {
    stop(
      "Missing required parameters: ",
      paste(missing_params, collapse = ", "),
      call. = FALSE
    )
  }

  # Replace each placeholder
  for (param in names(params)) {
    placeholder <- paste0("{", param, "}")
    value <- params[[param]]

    # Handle different value types
    if (is.character(value) && length(value) == 1) {
      # Single string - use as-is (caller should handle quoting if needed)
      replacement <- value
    } else if (is.numeric(value) && length(value) == 1) {
      # Single numeric - convert to string
      replacement <- as.character(value)
    } else if (is.character(value) && length(value) > 1) {
      # Multiple strings - join with comma (for IN clauses)
      replacement <- paste0("'", value, "'", collapse = ", ")
    } else if (is.numeric(value) && length(value) > 1) {
      # Multiple numerics - join with comma
      replacement <- paste(value, collapse = ", ")
    } else {
      stop(
        "Unsupported parameter type for '", param, "': ",
        class(value)[1],
        call. = FALSE
      )
    }

    sql <- gsub(placeholder, replacement, sql, fixed = TRUE)
  }
  sql
}


#' Execute SQL file with parameter interpolation
#'
#' @description
#' Convenience wrapper that loads and executes a SQL file in one step.
#'
#' @param sql A sql query string typically loaded via `load_sql_query()`
#' @param conn DBI connection object
#' @param execute logical; if TRUE (default), execute the query.
#'   If FALSE, return the interpolated SQL string.
#' @param ... additional arguments passed to DBI::dbExecute or DBI::dbGetQuery
#'
#' @return If execute = TRUE, returns result from DBI.
#' If FALSE, returns SQL string.
#' @export
#'
#' @examples
#' \dontrun{
#' # Execute SQL file with parameters
#' execute_sql_file(
#'   sql,
#'   conn = my_conn,
#'   file_path = "queries/create_table.sql",
#'   params = list(
#'     schema = "staging",
#'     table = "temp_data"
#'   )
#' )
#' }
execute_sql_file <- function(
    sql,
    conn,
    execute = TRUE,
    ...) {
  if (!execute) {
    return(sql)
  }

  # Determine if this is a SELECT query or modification query
  sql_trimmed <- trimws(toupper(sql))
  is_select <- grepl("^SELECT\\b", sql_trimmed) ||
    grepl("^WITH\\b", sql_trimmed)

  if (is_select) {
    DBI::dbGetQuery(conn, sql, ...)
  } else {
    DBI::dbExecute(conn, sql, ...)
  }
}
