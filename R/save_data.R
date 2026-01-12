# Private environment to hold the writer registry
.writer_registry <- new.env(parent = emptyenv())

#' Save data to file based on extension
#'
#' This is the conceptual inverse of read_data().
#'
#' @param data Object to save (data.table, list of tables, etc.)
#' @param file_path Path to the output file. The extension decides
#' which writer will be used (.csv, .rds, .duckdb, etc.)
#' @param file_name Optional if not in file_path. Default NULL
#' @param create_plot Logical. If TRUE, create plots for the data
#' @param plot_path Optional path to save the plots.
#' Default "data/D6_report"
#' @param exclude_columns_from_plots Optional character vector of column
#' names to exclude from plots.
#' Default: c("person_id", "pregnancy_id", "unique_id")
#' Default will try to exclude this columns if present to avoid privacy issues.
#' If NULL, no columns will be excluded.
#' @param ... Extra args passed to the specific writer
#'
#' @return Invisibly returns file_path
#' @export
save_data <- function(
    data,
    file_path,
    file_name = NULL,
    create_plot = FALSE,
    plot_path = "data/intermediate_plots",
    exclude_columns_from_plots = c(
      "person_id", "pregnancy_id", "unique_id"
    ),
    ...) {
  # Validate and prepare output path
  path_info <- prepare_output_path(file_path, file_name)
  file_path <- path_info$normalized_path

  # Extract extension
  ext <- tools::file_ext(file_path)
  if (ext == "") {
    stop(
      "File has no extension or extension could not be detected: ",
      file_path,
      "\nSupported extensions: ", paste(list_writers(), collapse = ", "),
      call. = FALSE
    )
  }

  # Normalize extension (lowercase)
  ext <- tolower(ext)

  writer_func <- get_writer(ext)
  if (is.null(writer_func)) {
    stop(
      "No writer registered for extension: '", ext, "'\n",
      "Supported extensions: ", paste(list_writers(), collapse = ", "), "\n",
      "Use register_writer() to add a custom writer.",
      call. = FALSE
    )
  }

  # Call the writer
  logger::log_info(paste0("Saving file: ", basename(file_path)))
  tryCatch(
    writer_func(data, file_path, ...),
    error = function(e) {
      stop(
        "Failed to save file: ", file_path, "\n",
        "Error: ", e$message,
        call. = FALSE
      )
    }
  )

  # Create feature analysis plots if requested
  if (create_plot) {
    data_to_plot <- data.table::copy(data)

    # Remove excluded columns if present
    if (!is.null(exclude_columns_from_plots) &&
        length(exclude_columns_from_plots) > 0
    ) {
      cols_to_remove <- intersect(
        exclude_columns_from_plots,
        names(data_to_plot)
      )
      if (length(cols_to_remove) > 0) {
        logger::log_debug(paste0(
          "Excluding columns from plots: ",
          paste(cols_to_remove, collapse = ", ")
        ))
        data_to_plot[, (cols_to_remove) := NULL]
      }
    }

    tryCatch(
      {
        picard::plot_data_features(
          data = data_to_plot,
          file_path = file_path,
          ...
        )
      },
      error = function(e) {
        logger::log_warn(paste0(
          "Failed to create plots: ", e$message
        ))
      }
    )
  }

  invisible(file_path)
}

#' Validate and prepare output path for saving
#'
#' @param file_path Path to save the file
#' @param file_name Optional filename to append
#' @param create_dir Whether to create directory if missing (default TRUE)
#' @return Named list with normalized_path
#' @keywords internal
prepare_output_path <- function(
    file_path,
    file_name = NULL,
    create_dir = TRUE) {
  # Trim whitespace
  file_path <- trimws(file_path)

  # Validate file_path
  if (is.null(file_path)) {
    stop("file_path cannot be NULL", call. = FALSE)
  }

  if (length(file_path) != 1) {
    stop(
      "file_path must be a single string, not a vector of length ",
      length(file_path),
      call. = FALSE
    )
  }

  if (nzchar(file_path) == 0) {
    stop("file_path cannot be an empty string", call. = FALSE)
  }

  # Normalize path
  file_path <- fs::path_norm(file_path)

  # Handle optional file_name parameter
  if (!is.null(file_name)) {
    if (!is.character(file_name)) {
      stop(
        "file_name must be a character string, not ",
        class(file_name)[1],
        call. = FALSE
      )
    }

    if (length(file_name) != 1) {
      stop(
        "file_name must be a single string, not a vector of length ",
        length(file_name),
        call. = FALSE
      )
    }

    file_name <- trimws(file_name)

    if (nzchar(file_name) == 0) {
      stop("file_name cannot be an empty string", call. = FALSE)
    }

    file_path <- file.path(file_path, file_name)
  }

  # Extract directory
  out_dir <- dirname(file_path)

  # Create directory if needed
  if (!dir.exists(out_dir)) {
    if (create_dir) {
      logger::log_info(paste0("Creating directory: ", out_dir))
      tryCatch(
        dir.create(out_dir, recursive = TRUE, showWarnings = FALSE),
        error = function(e) {
          stop(
            "Failed to create directory: ", out_dir, "\n",
            "Error: ", e$message,
            call. = FALSE
          )
        }
      )
    } else {
      stop(
        "Output directory does not exist: ", out_dir, "\n",
        "Set create_dir = TRUE to create it automatically.",
        call. = FALSE
      )
    }
  }

  # Check write permissions
  if (!file.access(out_dir, mode = 2) == 0) {
    logger::log_warn(paste0(
      "May not have write permission for directory: ", out_dir
    ))
  }

  # Return normalized path
  list(
    normalized_path = file_path
  )
}

#' Register a writer for a file extension
#'
#' @param extension File extension (e.g. "csv", "parquet")
#' @param writer_func Function(data, path, ...) that writes data to path
#' @export
register_writer <- function(extension, writer_func) {
  if (!base::is.function(writer_func)) {
    base::stop("writer_func must be a function", call. = FALSE)
  }
  .writer_registry[[extension]] <- writer_func
  base::invisible(NULL)
}

#' Internal helper to get the writer for an extension
#'
#' @keywords internal
#' @return writer function or NULL
get_writer <- function(extension) {
  .writer_registry[[extension]]
}

#' List all registered writers
#' @return Character vector of supported extensions
#' @export
list_writers <- function() {
  sort(ls(envir = .writer_registry))
}


#' Initialise writer registry with built-in writers
#'
#' This mirrors .init_reader_registry()
.init_writer_registry <- function() {
  # clear existing
  base::rm(
    list = base::ls(envir = .writer_registry),
    envir = .writer_registry
  )

  # CSV WRITER
  register_writer("csv", function(data, path, ...) {
    # data.table::fwrite() wants data.frame/data.table
    if (!data.table::is.data.table(data)) {
      data <- data.table::as.data.table(data)
    }

    # We standardise NA handling: empty string "" instead of NA?
    # For now we keep NA as NA. Could expose na = "" via ...
    data.table::fwrite(
      data,
      file = path,
      na = "NA",
      ...
    )

    base::invisible(path)
  })

  # RDS WRITER
  register_writer("rds", function(data, path, ...) {
    base::saveRDS(data, file = path, ...)
    base::invisible(path)
  })

  # RDATA WRITER
  # saves object with a fixed name "data" inside the .RData
  register_writer("rdata", function(data, path, ...) {
    data_to_save <- data
    base::save(data_to_save,
      file = path,
      envir = base::environment(),
      ...
    )
    base::invisible(path)
  })

  # FST WRITER
  register_writer("fst", function(data, path, ...) {
    if (!data.table::is.data.table(data)) {
      data <- data.table::as.data.table(data)
    }
    fst::write_fst(data, path, ...)
    base::invisible(path)
  })

  # TXT WRITER
  register_writer("txt", function(data, path, ...) {
    utils::write.table(
      x = data,
      file = path,
      ...
    )
    base::invisible(path)
  })

  # PARQUET WRITER
  register_writer("parquet", function(data, path, ...) {
    arrow::write_parquet(data, path, ...)
    base::invisible(path)
  })

  # EXCEL WRITER
  register_writer("xlsx", function(data, path, ...) {
    openxlsx::write.xlsx(data, path, ...)
    base::invisible(path)
  })
}
