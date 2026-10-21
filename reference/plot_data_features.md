# Create feature analysis plots for data inspection

Create feature analysis plots for data inspection

## Usage

``` r
plot_data_features(
  data,
  file_name = NULL,
  plot_path = "data/intermediate_plots",
  exclude_columns_from_plots = c("person_id", "pregnancy_id", "unique_id"),
  chart_types = c("dist"),
  cols = NULL,
  show_stats = TRUE,
  ...
)
```

## Arguments

- data:

  A data.table to visualize

- file_name:

  Name of the data file (used for plot titles)

- plot_path:

  Optional path to save the plots. Default "data/D6_report"

- exclude_columns_from_plots:

  Optional character vector of column names to exclude from plots.
  Default: c("person_id", "pregnancy_id", "unique_id") Default will try
  to exclude this columns if present to avoid privacy issues. If NULL,
  no columns will be excluded.

- chart_types:

  Vector of chart types: "dist", "missing", "boxplot"

- cols:

  Optional vector of column names to plot (NULL = all columns)

- show_stats:

  Show summary statistics on plots (default: TRUE)

- ...:

  Additional arguments passed to plotters

## Value

Invisibly returns vector of saved file paths
