# Ensure date columns are of Date type

This function takes a data.table and a vector of column names,
converting the specified columns to Date type if they are not already.

## Usage

``` r
set_dates(df, date_cols, date_format = NULL, reference_date = "1970-01-01")
```

## Arguments

- df:

  A data.table containing the data.

- date_cols:

  A character vector of column names to be converted to Date type.

- date_format:

  Add a possible date format to the defaults: "%Y-%m-%d", "%Y/%m/%d",
  "%Y%m%d"

- reference_date:

  A string representing the origin date for numeric conversions. Default
  is "1970-01-01".

## Value

The modified data.table with specified columns as Date type.
