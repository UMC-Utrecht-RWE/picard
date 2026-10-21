# Get all files of interest

Get all files of interest

## Usage

``` r
normalize_format_filter(formats, arg_name)
```

## Arguments

- formats:

  Character vector of file extensions to include or exclude, for example
  `c("R", "sql")`. If `NULL`, no filter is applied. Mutually exclusive
  with `exclude_format`.

- arg_name:

  Name of the argument for error messages.

## Value

Normalized character vector of file extensions or NULL if no valid
formats are provided.
