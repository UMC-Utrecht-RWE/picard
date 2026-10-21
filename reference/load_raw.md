# Read a file using the registered reader without coercing its output

Read a file using the registered reader without coercing its output

## Usage

``` r
load_raw(file_path, file_name = NULL, ...)
```

## Arguments

- file_path:

  Path to the file

- file_name:

  Optional filename to append to file_path

- ...:

  Additional arguments passed to the reader function

## Value

The native object returned by the registered reader
