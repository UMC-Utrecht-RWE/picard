# Ensure that a YAML file is valid and strictly formatted

This function reads a YAML file and ensures that it has a valid
structure. It checks that the file has a .yaml or .yml extension and
that it contains a mapping (list) at the top level.

## Usage

``` r
read_yaml(file_path)
```

## Arguments

- file_path:

  Path to the YAML file.

## Value

A list representing the YAML content if valid.
