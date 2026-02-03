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
          msg <- paste0("[DRY RUN] Would delete: ", partition_path)
          message(msg)
          logger::log_info(msg)
        } else {
          fs::dir_delete(partition_path)
          msg <- paste0("Deleted: ", partition_path)
          message(msg)
          logger::log_info(msg)
        }
      } else {
        msg <- paste0("Not found: ", partition_path)
        message(msg)
        logger::log_error(msg)
      }
    }
  }

  invisible(TRUE)
}

#' Delete one or more files (optionally expanding directories)
#'
#' Deletes files from the filesystem with an optional dry run mode.
#' Can also accept directories and delete all files inside them (opt-in).
#'
#' @param paths Character vector or list of paths to delete.
#'   Elements may be files or directories.
#' @param dry_run Logical; if `TRUE` (default FALSE), no files are deleted.
#' @param del_dir Logical; if `TRUE` (default), delete directories as well
#' as files.
#' @param stop_on_error Logical; if `TRUE`, stops on first delete error.
#'
#' @return NULL
#'
#' @examples
#' \dontrun{
#'    delete_paths("path/to/file.txt")
#'    delete_paths(c("a.txt", "b.txt"), dry_run = FALSE)
#'    delete_paths("data/", del_dir = TRUE)
#' }
#' @export
delete_paths <- function(
  paths,
  dry_run = FALSE,
  del_dir = FALSE,
  stop_on_error = FALSE
) {
  if (base::missing(paths)) {
    base::stop("`paths` is required.")
  }

  if (base::is.list(paths)) {
    paths <- base::unlist(paths, use.names = FALSE)
  }

  if (!base::is.character(paths)) {
    base::stop("`paths` must be a character vector or list of character.")
  }

  paths <- fs::path_expand(paths)
  paths <- fs::path_norm(paths)

  # make outcomes data.table, start with column names
  outcomes <- data.table::data.table(
    path = character(),
    exists = logical(),
    type = character()
  )

  for (path in paths) {
    type_ <- NA_character_
    if (fs::is_dir(path)) {
      type_ = "directory"
    } else if (fs::is_file(path)) {
      type_ = "file"
    }
    if (type_ == "directory") {
      exists <- as.logical(fs::dir_exists(path))
    } else if (type_ == "file") {
      exists <- as.logical(fs::file_exists(path))
    } else {
      exists <- FALSE
    }
    outcomes <- rbind(
      outcomes,
      data.table::data.table(
        path = path,
        exists = exists,
        type = type_
      )
    )
  }

  outcomes <- outcomes[exists == TRUE]
  if (dry_run) {
    msg <- paste0(
      "[DRY RUN] The following paths would be deleted:\n",
      paste0(outcomes$path, collapse = "\n ")
    )
    message(msg)
    logger::log_info(msg)
  } else {
    purrr::map2(
      outcomes$path,
      outcomes$type,
      function(path, type_) {
        tryCatch(
          {
            if (type_ == "directory") {
              if (del_dir) {
                fs::dir_delete(path)
              } else {
                fs::dir_delete(fs::dir_ls(path))
              }
            } else if (type_ == "file") {
              fs::file_delete(path)
            } else {
              stop(paste0("Path is neither file nor directory: ", path))
            }
          },
          error = function(e) {
            msg <- paste0("Error deleting ", path, ": ", e$message)
            message(msg)
            logger::log_error(msg)
            if (stop_on_error) {
              stop(e)
            }
          }
        )
      }
    )
    msg <- paste0(
      "Deleted the following paths:\n",
      paste0(outcomes$path, collapse = "\n ")
    )
    message(msg)
    logger::log_info(msg)
  }
  # outcomes
}