# DEAPs might have saved the file with different case sensitivity. This function checks for case-insensitive matches and adjusts the file_path accordingly, issuing warnings or errors as needed.

DEAPs might have saved the file with different case sensitivity. This
function checks for case-insensitive matches and adjusts the file_path
accordingly, issuing warnings or errors as needed.

## Usage

``` r
case_sensitive_filename(file_path, file_name, dir_path, actual_files)
```

## Arguments

- file_path:

  Full path to the file

- file_name:

  Name of the file

- dir_path:

  Directory path containing the file

- actual_files:

  Vector of actual filenames in the directory

## Value

Corrected file_path if a case-insensitive match is found
