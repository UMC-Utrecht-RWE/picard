# Execute SQL file with parameter interpolation

Convenience wrapper that loads and executes a SQL file in one step.

## Usage

``` r
execute_sql_file(
  sql,
  conn,
  execute = TRUE,
  save_as_parquet = FALSE,
  parquet_path = NULL,
  partition_by = NULL,
  ...
)
```

## Arguments

- sql:

  A sql query string typically loaded via
  [`load_sql_query()`](https://umc-utrecht-rwe.github.io/picard/reference/load_sql_query.md)

- conn:

  DBI connection object

- execute:

  logical; if TRUE (default), execute the query. If FALSE, return the
  interpolated SQL string.

- save_as_parquet:

  logical; if TRUE, saves the result of a SELECT query to Parquet. For
  DuckDB connections, the query result is streamed directly to disk via
  DuckDB's `COPY ... TO ... (FORMAT PARQUET)`, without materialising it
  as an R data.frame first. Other DBI backends fall back to
  [`DBI::dbGetQuery()`](https://dbi.r-dbi.org/reference/dbGetQuery.html) +
  [`arrow::write_dataset()`](https://arrow.apache.org/docs/r/reference/write_dataset.html).

- parquet_path:

  character; file path to save the Parquet file if `save as_parquet` is
  TRUE. Required if `save_as_parquet` is TRUE.

- partition_by:

  vector of column names to partition the Parquet file

- ...:

  additional arguments passed to DBI::dbExecute or DBI::dbGetQuery

## Value

If execute = TRUE and save_as_parquet = TRUE on a DuckDB connection,
returns invisible(parquet_path). Otherwise, if execute = TRUE, returns
the result from DBI. If FALSE, returns the SQL string.

## Examples

``` r
if (FALSE) { # \dontrun{
# Execute SQL file with parameters
execute_sql_file(
  sql,
  conn = my_conn,
  file_path = "queries/create_table.sql",
  params = list(
    schema = "staging",
    table = "temp_data"
  )
)
} # }
```
