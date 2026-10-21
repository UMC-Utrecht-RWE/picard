# Dispatch a prepared file request to its reader

Dispatch a prepared file request to its reader

## Usage

``` r
dispatch_reader(request, ...)
```

## Arguments

- request:

  Named list created by prepare_load_request()

- ...:

  Additional arguments passed to the reader function

## Value

The native object returned by the registered reader
