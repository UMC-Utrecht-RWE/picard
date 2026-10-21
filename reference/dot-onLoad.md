# Package initialization hook

This file (named zzz.R by convention) contains the .onLoad hook that R
calls when the package is loaded. It initializes all registries used by
load(), save(), and plot_data_features().

## Usage

``` r
.onLoad(libname, pkgname)
```
