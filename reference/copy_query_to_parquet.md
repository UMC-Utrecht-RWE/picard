# Copy a SELECT query's result directly to a Parquet file via DuckDB

Uses DuckDB's native `COPY ... TO ... (FORMAT PARQUET)` statement so the
result set streams straight from the query engine to disk, without ever
being materialised as an R data.frame first.

## Usage

``` r
copy_query_to_parquet(conn, sql, parquet_path, partition_by = NULL, ...)
```

## Arguments

- conn:

  a duckdb_connection

- sql:

  character(1) SELECT/WITH query to execute

- parquet_path:

  character; destination file (or directory, when `partition_by` is
  used)

- partition_by:

  vector of column names to partition the output by

- ...:

  additional arguments (e.g. bind parameters) passed to DBI::dbExecute

## Value

invisible(parquet_path)
