# Save data to file based on extension

This is the conceptual inverse of load().

## Usage

``` r
save(
  data,
  file_path,
  file_name = NULL,
  create_plot = FALSE,
  plot_path = "data/intermediate_plots",
  exclude_columns_from_plots = c("person_id", "pregnancy_id", "unique_id"),
  ...
)
```

## Arguments

- data:

  Object to save (data.table, list of tables, etc.)

- file_path:

  Path to the output file. The extension decides which writer will be
  used (.csv, .rds, .duckdb, etc.)

- file_name:

  Optional if not in file_path. Default NULL

- create_plot:

  Logical. If TRUE, create plots for the data

- plot_path:

  Optional path to save the plots. Default "data/D6_report"

- exclude_columns_from_plots:

  Optional character vector of column names to exclude from plots.
  Default: c("person_id", "pregnancy_id", "unique_id") Default will try
  to exclude this columns if present to avoid privacy issues. If NULL,
  no columns will be excluded.

- ...:

  Extra args passed to the specific writer

## Value

Invisibly returns file_path
