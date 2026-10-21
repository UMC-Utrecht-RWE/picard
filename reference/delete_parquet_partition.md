# Remove Hive-style parquet file partitions

Removes filesystem-level Hive-style parquet partitions (e.g.
`concept_id=123`) from one or more hive directories. This function
deletes entire partition directories and all files within them.

## Usage

``` r
delete_parquet_partition(
  dataset_dir,
  partition_ids,
  partition_col = "concept_id",
  dry_run = TRUE
)
```

## Arguments

- dataset_dir:

  Character vector of base hive paths containing partitioned parquet
  data.

- partition_ids:

  Vector of partition values to remove (typically concept IDs).

- partition_col:

  Name of the partition column. Default `"concept_id"`.

- dry_run:

  Logical; if `TRUE` (default), no files are deleted and the function
  only prints the paths that would be removed.

## Value

Invisibly returns `TRUE` after completion.

## Details

Each partition is assumed to be stored as a directory of the form
`partition_col=partition_id` directly under each hive path.

This function operates at the filesystem level and is intended for use
with external or unmanaged Hive tables. For managed Hive tables,
partitions should be removed using `ALTER TABLE ... DROP PARTITION` to
avoid metadata inconsistencies.

## Examples

``` r
if (FALSE) { # \dontrun{
delete_parquet_partition(
  dataset_dir = c(
    dir_parquet_concepts,
    dir_preprocessing_parquets
  ),
  partition_ids = c(
    events_of_interest,
    procedures_of_interest,
    list_new_preprocessing_concept
  ),
  dry_run = FALSE
)
} # }
```
