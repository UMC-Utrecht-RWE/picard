# Read multiple files and combine them

Read multiple files and combine them

## Usage

``` r
load_batch(file_paths, combine_method = "rbind", ...)
```

## Arguments

- file_paths:

  Character vector of file paths

- combine_method:

  How to combine: "rbind" (stack rows) or "list"

- ...:

  Additional arguments passed to load

## Value

Combined data.table or list of data.tables
