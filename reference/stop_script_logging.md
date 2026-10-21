# Stop script-level logging when owned by the current script

Counterpart to
[`start_script_logging()`](https://umc-utrecht-rwe.github.io/picard/reference/start_script_logging.md).
If the current script did not start logging itself, this function is a
no-op.

## Usage

``` r
stop_script_logging(envir = parent.frame())
```

## Arguments

- envir:

  Environment that holds the ownership flag. Defaults to
  [`parent.frame()`](https://rdrr.io/r/base/sys.parent.html).

## Value

Invisibly returns `TRUE` when this call stopped logging, otherwise
`FALSE`.
