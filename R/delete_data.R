#' Remove Hive-style parquet file partitions
#'
#' Removes filesystem-level Hive-style parquet partitions (e.g.
#' `concept_id=123`) from one or more hive directories. This function deletes
#' entire partition directories and all files within them.
#'
#' @param dataset_dir Character vector of base hive paths containing partitioned
#'   parquet data.
#' @param partition_ids Vector of partition values to remove (typically
#'   concept IDs).
#' @param partition_col Name of the partition column. Default `"concept_id"`.
#' @param dry_run Logical; if `TRUE` (default), no files are deleted and the
#'   function only prints the paths that would be removed.
#'
#' @details
#' Each partition is assumed to be stored as a directory of the form
#' `partition_col=<partition_id>` directly under each hive path.
#'
#' This function operates at the filesystem level and is intended for use with
#' external or unmanaged Hive tables. For managed Hive tables, partitions should
#' be removed using `ALTER TABLE ... DROP PARTITION` to avoid metadata
#' inconsistencies.
#'
#' @return Invisibly returns `TRUE` after completion.
#'
#' @examples
#' \dontrun{
# ' delete_parquet_partition(
# '   dataset_dir = c(
# '     dir_parquet_concepts,
# '     dir_preprocessing_parquets
# '   ),
# '   partition_ids = c(
# '     events_of_interest,
# '     procedures_of_interest,
# '     list_new_preprocessing_concept
# '   ),
# '   dry_run = FALSE
# ' )
#' }
#'
#' @export
delete_parquet_partition <- function(
  dataset_dir,
  partition_ids, # Generally concept_id
  partition_col = "concept_id",
  dry_run = TRUE
) {
  stopifnot(is.character(dataset_dir))
  stopifnot(length(dataset_dir) > 0)
  stopifnot(length(partition_ids) > 0)

  dataset_dir <- unique(fs::path_norm(dataset_dir))
  partition_ids <- unique(as.character(partition_ids))

  for (dir in dataset_dir) {
    for (pid in partition_ids) {
      partition_path <- fs::path(
        dir, paste0(partition_col, "=", pid)
      )

      if (dir.exists(partition_path)) {
        if (dry_run) {
          message("[DRY RUN] Would delete: ", partition_path)
        } else {
          fs::dir_delete(partition_path)
          message("Deleted: ", partition_path)
        }
      } else {
        message("Not found: ", partition_path)
      }
    }
  }

  invisible(TRUE)
}
