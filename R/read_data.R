# This file contains all the scripts to load a return the content of data files.
# You can add more type of option in .init_reader_registry as a register_reader
# For now the return is not always a data.table.
# Maybe this is something that can be changed.

#' Read data from file  based on extension
#'
#' @param file_path Path to the file
#' @param file_name Optional if not in file_path. Default NULL
#' @param col_types Optional, define the column type in output per column.
#' It requires a list.
#' @param ... Additional arguments passed to the reader function
#' @return Data data.table
#' @export
read_data <- function(file_path, file_name = NULL, col_types = NULL, ...) {
  # Validate and normalize path
  path_info <- validate_and_normalize_path(file_path, file_name)

  # Handle case sensitivity
  file_path <- case_sensitive_filename(
    file_path = path_info$normalized_path,
    file_name = path_info$file_name,
    dir_path = path_info$dir_path,
    actual_files = path_info$actual_files
  )

  # Extract extension
  ext <- tools::file_ext(file_path)
  if (ext == "") {
    stop(
      "File has no extension: ", file_path, "\n",
      call. = FALSE
    )
  }

  # Normalize extension (lowercase)
  ext <- tolower(ext)

  reader_func <- get_reader(ext)
  if (is.null(reader_func)) {
    stop(
      "No reader registered for extension: '", ext, "'\n",
      "Supported extensions: ", paste(list_readers(), collapse = ", "), "\n",
      "Use register_reader() to add a custom reader.",
      call. = FALSE
    )
  }
  # Call the reader
  logger::log_info(paste0("Reading file: ", basename(file_path)))
  result <- tryCatch(
    reader_func(file_path, ...),
    error = function(e) {
      stop(
        "Failed to read file: ", file_path, "\n",
        "Error: ", e$message,
        call. = FALSE
      )
    }
  )

  result <- data.table::as.data.table(result)
  define_column_types(result, col_types = col_types)
}

#' Validate and normalize file path
#'
#' @param file_path Path to the file or directory
#' @param file_name Optional filename to append to file_path
#' @return Named list with normalized_path, dir_path, file_name, and
#' actual_files
#' @keywords internal
validate_and_normalize_path <- function(file_path, file_name = NULL) {
  # Validate file_path
  if (is.null(file_path)) {
    stop("file_path cannot be NULL", call. = FALSE)
  }

  if (!is.character(file_path)) {
    stop(
      "file_path must be a character string, not ",
      class(file_path)[1],
      call. = FALSE
    )
  }

  # Trim whitespace
  file_path <- trimws(file_path)

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

  # Extract directory and filename components
  dir_path <- dirname(file_path)
  file_name <- basename(file_path)

  # List actual files in directory
  actual_files <- list.files(dir_path)

  # Return normalized components
  list(
    normalized_path = file_path,
    dir_path = dir_path,
    file_name = file_name,
    actual_files = actual_files
  )
}

#' DEAPs might have saved the file with different case sensitivity.
#' This function checks for case-insensitive matches and adjusts the file_path
#' accordingly, issuing warnings or errors as needed.
#' @param file_path Full path to the file
#' @param file_name Name of the file
#' @param dir_path Directory path containing the file
#' @param actual_files Vector of actual filenames in the directory
#' @return Corrected file_path if a case-insensitive match is found
#' @keywords internal
case_sensitive_filename <- function(
    file_path, file_name, dir_path, actual_files) {
  # In read_data(), replace the file finding logic:
  if (!file_name %in% actual_files) {
    similar_files <- actual_files[tolower(actual_files) == tolower(file_name)]

    if (length(similar_files) == 1) {
      logger::log_warn(paste0(
        "File '", file_name, "' not found. ",
        "Using case-insensitive match '", similar_files, "'"
      ))
      file_path <- file.path(dir_path, similar_files)
    } else if (length(similar_files) > 1) {
      stop(
        "Multiple case-insensitive matches found for '", file_name, "':\n  ",
        paste(similar_files, collapse = "\n  "),
        "\nPlease specify the exact filename.",
        call. = FALSE
      )
    } else {
      # Provide helpful suggestions
      suggestion <- agrep(
        file_name, actual_files,
        value = TRUE, max.distance = 0.3
      )
      if (length(suggestion) > 0) {
        stop(
          "File not found: ", file_path, "\n",
          "Did you mean: ", paste(suggestion, collapse = ", "), "?",
          call. = FALSE
        )
      } else {
        stop("File not found: ", file_path, call. = FALSE)
      }
    }
  }
  file_path
}


#' Fix and define the value of columns within a data.table
#'
#' @param df A data.table
#' @param col_types Optional, define the column type in output per column.
#' It requires a list.
#' @return Data data.table
#' @keywords internal
define_column_types <- function(df, col_types) {
  if (is.null(col_types) || length(col_types) == 0) {
    return(df)
  }

  if (!is.list(col_types) || is.null(names(col_types))) {
    stop("col_types must be a named list", call. = FALSE)
  }

  for (col in names(col_types)) {
    if (col %in% names(df)) {
      type <- col_types[[col]]

      tryCatch(
        {
          # Handle both function and character input
          converter <- if (is.function(type)) {
            type
          } else {
            get(paste0("as.", type))
          }

          data.table::set(df, j = col, value = converter(df[[col]]))
          logger::log_debug(
            paste0("Converted column '", col, "' to type: ", type)
          )
        },
        error = function(e) {
          warning(paste0(
            "Failed to convert column '", col, "': ", e$message
          ))
        }
      )
    } else {
      warning(paste0("Column '", col, "' not present in data"))
    }
  }

  df
}


# Private environment to hold the registry
.reader_registry <- new.env(parent = emptyenv())


# Initialize with default readers
.init_reader_registry <- function() {
  # Clear existing
  rm(list = ls(envir = .reader_registry), envir = .reader_registry)

  # Register built-in formats
  register_reader("csv", function(path, ...) {
    # Read the data
    dt <- utils::read.csv(
      file = path,
      check.names = FALSE,
      ...
    )

    # Identify columns that look like dates in the format YYYYMMDD
    date_cols <- sapply(dt, function(col) {
      is.integer(col) &&
        any(grepl("^\\d{8}$", col[!is.na(col)]))
    })

    # Convert these columns to Date
    for (col in names(dt)[date_cols]) {
      dt[[col]] <- as.Date(as.character(dt[[col]]), format = "%Y%m%d")
    }

    # Return as data.table
    data.table::as.data.table(dt)
  })

  register_reader("rdata", function(path, ...) {
    load_rdata(path)
  })

  register_reader("rds", function(path, ...) {
    base::readRDS(path, ...)
  })

  register_reader("xlsx", function(path, ...) {
    readxl::read_xlsx(path, ...)
  })

  register_reader("fst", function(path, ...) {
    fst::read_fst(path, ...)
  })

  register_reader(
    "duckdb",
    function(path, load_only_table = NULL, ...) {
      con <- DBI::dbConnect(duckdb::duckdb(), path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      tables <- DBI::dbListTables(con)

      # Only load a specific table if requested
      if (!is.null(load_only_table)) {
        if (load_only_table %in% tables) {
          return(DBI::dbReadTable(conn = con, name = load_only_table, ...))
        } else {
          stop("Input known_table does not match any table in the DuckDB file.")
        }
      }

      # If only one table, return it directly
      if (length(tables) == 1) {
        return(DBI::dbReadTable(con, tables, ...))
      } else { # Multiple tables, return a named list
        result <- base::lapply(tables, function(tbl) {
          DBI::dbReadTable(con, tbl, ...)
        })
        names(result) <- tables
        return(result)
      }
    }
  )
}


#' Register a reader for a file extension
#'
#' @param extension File extension (e.g., "csv", "parquet")
#' @param reader_func Function that takes `path, ...` and returns data
#' @export
register_reader <- function(extension, reader_func) {
  if (!is.function(reader_func)) {
    stop("reader_func must be a function", call. = FALSE)
  }
  .reader_registry[[extension]] <- reader_func
  invisible(NULL)
}

#' Get Reader by Extension
#'
#' Internal: Retrieves the reader function associated with a file extension.
#' Not intended for end-user use.
#'
#' @param extension File extension (e.g., "csv", "parquet")
#' @return The registered reader function or NULL if not found
#' @keywords internal
get_reader <- function(extension) {
  .reader_registry[[extension]]
}


#' List all registered readers
#' @return Character vector of supported extensions
#' @export
list_readers <- function() {
  sort(ls(envir = .reader_registry))
}


#' R data file loader
#' @description It loads an RData file, and returns its content as an object.
#' NB is only designed for RData files with one object inside.
#' @param file_path argument name
#' @return A data frame
#' @export
load_rdata <- function(file_path) {
  load(file_path)
  objects <- ls()[ls() != "file_path"]
  if (length(objects) > 1) {
    warning(
      "The RData file ", file_path,
      " contains more than one object. Only the first object will be returned."
    )
  }
  get(objects[1])
}


#' Get summary statistics for a data file
#' @param file_path Path to the file
#' @param ... Additional arguments passed to read_data
#' @return List with file info and data summary
#' @export
summarize_data_file <- function(file_path, ...) {
  data <- read_data(file_path, ...)

  summary <- list(
    file = file_path,
    size_mb = file.size(file_path) / 1024^2,
    n_rows = nrow(data),
    n_cols = ncol(data),
    columns = names(data),
    col_types = sapply(data, function(x) class(x)[1]),
    missing = sapply(data, function(x) sum(is.na(x))),
    memory_mb = as.numeric(utils::object.size(data)) / 1024^2
  )
  # return data and summary as two separate elements
  list(data = data, summary = summary)
}

#' Read multiple files and combine them
#' @param file_paths Character vector of file paths
#' @param combine_method How to combine: "rbind" (stack rows) or "list"
#' @param ... Additional arguments passed to read_data
#' @return Combined data.table or list of data.tables
#' @export
read_data_batch <- function(file_paths, combine_method = "rbind", ...) {
  if (length(file_paths) == 0) {
    stop("file_paths cannot be empty", call. = FALSE)
  }

  logger::log_info(paste0("Reading ", length(file_paths), " files"))

  data_list <- lapply(file_paths, function(fp) {
    logger::log_debug(paste0("Reading: ", basename(fp)))
    read_data(fp, ...)
  })

  if (combine_method == "rbind") {
    data.table::rbindlist(data_list, fill = TRUE)
  } else if (combine_method == "list") {
    names(data_list) <- basename(file_paths)
    data_list
  } else {
    stop("combine_method must be 'rbind' or 'list'", call. = FALSE)
  }
}
