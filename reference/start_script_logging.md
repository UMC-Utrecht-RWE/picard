# Start script-level logging when available

Starts script timing and print capture when the PICARD logger has been
configured. When the script already runs inside a managed PICARD
context, the function becomes a no-op so the same incipit can be used
both standalone and inside the pipeline.

## Usage

``` r
start_script_logging(
  script_name = NULL,
  capture_prints = TRUE,
  capture_messages = TRUE,
  envir = parent.frame()
)
```

## Arguments

- script_name:

  Optional label for the script in the log. Defaults to the current
  sourced filename when available.

- capture_prints:

  Logical; if `TRUE` (default), capture printed output.

- capture_messages:

  Logical; if `TRUE` (default), also capture messages and warnings when
  capturing prints.

- envir:

  Environment used to store the ownership flag. Defaults to
  [`parent.frame()`](https://rdrr.io/r/base/sys.parent.html).

## Value

Invisibly returns `TRUE` when this call started logging, otherwise
`FALSE`.
