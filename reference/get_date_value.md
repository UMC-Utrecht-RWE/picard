# Parse various date input formats into Date objects

This function takes a date input in various formats (character, numeric,
Date) and attempts to parse it into a Date object. It supports multiple
date formats for character inputs and allows specifying an origin date
for numeric inputs.

## Usage

``` r
get_date_value(
  date_input,
  origin = "1970-01-01",
  date_formats = c("%Y-%m-%d", "%Y/%m/%d", "%Y%m%d")
)
```

## Arguments

- date_input:

  The date input to be parsed. Can be of type character, numeric, or
  Date or a vactor.

- origin:

  The origin date for numeric inputs. Default is "1970-01-01".

- date_formats:

  A vector of date formats to try for character inputs. Default formats
  are "%Y-%m-%d", "%Y/%m/%d", and "%Y%m%d".

## Value

A Date object if parsing is successful, otherwise NA.

## Examples

``` r
get_date_value("2023-10-05")
#> [1] "2023-10-05"
get_date_value(19685) # Numeric input representing days since 1970-01-01
#> [1] "2023-11-24"
get_date_value(c("20251119", "20251118"))
#> [1] "2025-11-19" "2025-11-18"
get_date_value(c("20251119", "20251118", "Ciao"))
#> Warning: Some date values could not be parsed and were set to NA.
#> [1] "2025-11-19" "2025-11-18" NA          
```
