# PICARD logging wrappers

Convenience wrappers around the corresponding `logger` functions. They
let project substeps depend only on `picard`, while still using the
logger configuration currently active for the `picard` namespace.

## Usage

``` r
log_trace(...)

log_debug(...)

log_info(...)

log_success(...)

log_warn(...)

log_error(...)

log_fatal(...)
```

## Arguments

- ...:

  Arguments passed through to `logger`.

## Value

Invisibly returns the result of the underlying `logger` call.
