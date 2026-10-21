# audit_start

Started of the audit file

## Usage

``` r
audit_start(
  dir_output = "data/audits",
  file_name = NULL,
  deap_name = NULL,
  delete_old = TRUE,
  format = ".txt"
)
```

## Arguments

- dir_output:

  Character where to save the file

- file_name:

  With default null, the output file name witll be the same of the file
  in which function is invoked.

- deap_name:

  Character, name of the DEAP analysis

- delete_old:

  Boolean, delete_old if file exist

- format:

  Default txt
