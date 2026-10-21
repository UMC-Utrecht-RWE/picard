# Loead configuration values used during the pipeline execution

This function reads configuration values from a fixed YAML file. It
checks for the existence of the file and ensures that all required keys
are present.

## Usage

``` r
load_config(
  file_path = NULL,
  config_dir = "configuration",
  envir = parent.frame()
)
```

## Arguments

- file_path:

  Path to the YAML configuration file. Default is
  "configuration/config_values.yaml".

- config_dir:

  Directory to look for YAML configuration files if file_path is NULL.

- envir:

  Environment in which to assign the loaded configuration values when
  `file_path` is NULL. Defaults to the caller's environment, which is
  the global environment when called from a top-level script.

## Value

A list of configuration values.
