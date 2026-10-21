# Register a feature plotter

Register a feature plotter

## Usage

``` r
register_feature_plotter(name, fun)
```

## Arguments

- name:

  Unique plotter name (e.g., "dist")

- fun:

  Function that takes `dt` and `opts` and returns a named list of ggplot
  objects, one per column.

## Value

Invisibly returns TRUE
