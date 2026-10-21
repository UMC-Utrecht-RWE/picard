# Register a writer for a file extension

Register a writer for a file extension

## Usage

``` r
register_writer(extension, writer_func)
```

## Arguments

- extension:

  File extension (e.g. "csv", "parquet")

- writer_func:

  Function that accepts data, an output path, and optional extra
  arguments, then writes the data to that path.
