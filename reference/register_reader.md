# Register a reader for a file extension

Register a reader for a file extension

## Usage

``` r
register_reader(extension, reader_func)
```

## Arguments

- extension:

  File extension (e.g., "csv", "parquet")

- reader_func:

  Function that accepts a file path and optional extra arguments, and
  returns data.
