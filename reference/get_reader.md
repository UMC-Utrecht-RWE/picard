# Get Reader by Extension

Internal: Retrieves the reader function associated with a file
extension. Not intended for end-user use.

## Usage

``` r
get_reader(extension)
```

## Arguments

- extension:

  File extension (e.g., "csv", "parquet")

## Value

The registered reader function or NULL if not found
