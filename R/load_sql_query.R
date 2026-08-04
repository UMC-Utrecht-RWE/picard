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
  params = NULL
) {
  sql <- tryCatch(
    load_raw(file_path, encoding = encoding),
    error = function(e) {
      msg <- conditionMessage(e)
      if (startsWith(msg, "File not found: ")) {
        stop(sub("^File not found:", "SQL file not found:", msg), call. = FALSE)
      }
      stop(msg, call. = FALSE)
    }
  )

  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]

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
#' @param save_as_parquet logical; if TRUE, saves the result of a SELECT query
#'   to Parquet. For DuckDB connections, the query result is streamed
#'   directly to disk via DuckDB's `COPY ... TO ... (FORMAT PARQUET)`,
#'   without materialising it as an R data.frame first. Other DBI backends
#'   fall back to `DBI::dbGetQuery()` + `arrow::write_dataset()`.
#' @param parquet_path character; file path to save the Parquet file if `save
#'  as_parquet` is TRUE. Required if `save_as_parquet` is TRUE.
#' @param partition_by vector of column names to partition the Parquet file
#' @param ... additional arguments passed to DBI::dbExecute or DBI::dbGetQuery
#'
#' @return If execute = TRUE and save_as_parquet = TRUE on a DuckDB
#'   connection, returns invisible(parquet_path). Otherwise, if execute =
#'   TRUE, returns the result from DBI. If FALSE, returns the SQL string.
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
  save_as_parquet = FALSE,
  parquet_path = NULL,
  partition_by = NULL,
  ...
) {
  if (!execute) {
    return(sql)
  }

  # Determine if this is a SELECT query or modification query
  sql_trimmed <- trimws(toupper(sql))
  is_select <- grepl("^SELECT\\b", sql_trimmed) ||
    grepl("^WITH\\b", sql_trimmed)

  if (is_select) {
    if (save_as_parquet) {
      if (is.null(parquet_path)) {
        stop(
          "parquet_path must be provided when save_as_parquet is TRUE",
          call. = FALSE
        )
      }

      if (inherits(conn, "duckdb_connection")) {
        return(
          copy_query_to_parquet(
            conn,
            sql,
            parquet_path = parquet_path,
            partition_by = partition_by,
            ...
          )
        )
      }

      # Non-DuckDB connections have no native "stream query to Parquet"
      # facility, so fall back to materialising the result in R first.
      result <- DBI::dbGetQuery(conn, sql, ...)
      arrow::write_dataset(
        result,
        path = parquet_path,
        format = "parquet",
        partitioning = partition_by
      )
      return(result)
    }

    DBI::dbGetQuery(conn, sql, ...)
  } else {
    DBI::dbExecute(conn, sql, ...)
  }
}


#' Copy a SELECT query's result directly to a Parquet file via DuckDB
#'
#' @description
#' Uses DuckDB's native `COPY ... TO ... (FORMAT PARQUET)` statement so the
#' result set streams straight from the query engine to disk, without ever
#' being materialised as an R data.frame first.
#'
#' @param conn a duckdb_connection
#' @param sql character(1) SELECT/WITH query to execute
#' @param parquet_path character; destination file (or directory, when
#'   `partition_by` is used)
#' @param partition_by vector of column names to partition the output by
#' @param ... additional arguments (e.g. bind parameters) passed to
#'   DBI::dbExecute
#'
#' @return invisible(parquet_path)
#' @keywords internal
copy_query_to_parquet <- function(
  conn,
  sql,
  parquet_path,
  partition_by = NULL,
  ...
) {
  inner_sql <- sub(";\\s*$", "", trimws(sql))

  copy_options <- "FORMAT PARQUET"
  if (!is.null(partition_by)) {
    partition_cols <- paste(
      vapply(
        partition_by,
        function(col) as.character(DBI::dbQuoteIdentifier(conn, col)),
        FUN.VALUE = character(1)
      ),
      collapse = ", "
    )
    copy_options <- paste0(
      copy_options,
      ", PARTITION_BY (", partition_cols, ")",
      ", FILENAME_PATTERN 'part-{i}'"
    )
  }

  DBI::dbExecute(
    conn,
    sprintf(
      "COPY (%s) TO %s (%s)",
      inner_sql,
      as.character(DBI::dbQuoteString(conn, parquet_path)),
      copy_options
    ),
    ...
  )

  invisible(parquet_path)
}
