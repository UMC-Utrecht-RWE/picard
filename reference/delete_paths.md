# Delete one or more files (optionally expanding directories)

Deletes files from the filesystem with an optional dry run mode. Can
also accept directories and delete all files inside them (opt-in).

## Usage

``` r
delete_paths(paths, dry_run = FALSE, del_dir = FALSE)
```

## Arguments

- paths:

  Character vector or list of paths to delete. Elements may be files or
  directories.

- dry_run:

  Logical; if `TRUE` (default FALSE), no files are deleted.

- del_dir:

  Logical; if `TRUE` (default), delete directories as well as files.

## Examples

``` r
if (FALSE) { # \dontrun{
delete_paths("path/to/file.txt")
delete_paths(c("a.txt", "b.txt"), dry_run = FALSE)
delete_paths("data/", del_dir = TRUE)
} # }
```
