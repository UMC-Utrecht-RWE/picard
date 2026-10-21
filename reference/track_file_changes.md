# Get all files of interest and get their has in a CSV file.

Get all files of interest and get their has in a CSV file.

## Usage

``` r
track_file_changes(
  log_dir = "logs",
  path = NULL,
  output_file = NULL,
  only_format = NULL,
  exclude_format = NULL
)
```

## Arguments

- log_dir:

  Character. Directory to store the registry when `registry_path` is
  NULL.

- path:

  Character. Path to the file(s). Default NULL

- output_file:

  Output file Default NULL

- only_format:

  Character vector of file extensions to include, for example
  `c("R", "sql")`. If `NULL`, no inclusion filter is applied. Mutually
  exclusive with `exclude_format`.

- exclude_format:

  Character vector of file extensions to exclude, for example
  `c("csv", "txt", "parquet")`. If `NULL`, no exclusion filter is
  applied. Mutually exclusive with `only_format`.
