# File for ad-hoc functions that cannot be gathered in a single topic file.

#' Loead configuration values used during the pipeline execution
#'
#' @description
#' This function reads configuration values from a fixed YAML file.
#' It checks for the existence of the file and ensures
#' that all required keys are present.
#'
#' @param file_path Path to the YAML configuration file.
#' Default is "configuration/config_values.yaml".
#'
#' @return A list of configuration values.
#' @export
load_config <- function(file_path = NULL) {
  if (!base::is.null(file_path)) {
    if (base::file.exists(file_path)) {
      read_yaml(file_path)
    } else {
      stop("Configuration file not found at: ", file_path)
    }
  } else {
    # list all .yamls in the configuration folder
    yamls <- list.files(
      here::here("configuration"),
      pattern = "\\.yaml$",
      full.names = TRUE
    )
    if (length(yamls) == 0) {
      stop("No YAML configuration files found in 'configuration' folder.")
    }
    # load all files and add a new variable in the environment
    # for each file with the name of the file
    for (yaml in yamls) {
      base::assign(
        tolower(tools::file_path_sans_ext(basename(yaml))),
        read_yaml(yaml),
        envir = .GlobalEnv
      )
    }
  }
}

#' Ensure that a YAML file is valid and strictly formatted
#'
#' @description
#' This function reads a YAML file and ensures that it has a valid
#' structure. It checks that the file has a .yaml or .yml extension
#' and that it contains a mapping (list) at the top level.
#' @param file_path Path to the YAML file.
#' @return A list representing the YAML content if valid.
#' @keywords internal
read_yaml <- function(file_path) {
  ext <- tolower(tools::file_ext(file_path))
  if (!ext %in% c("yaml", "yml")) {
    stop("Config must be .yaml or .yml", call. = FALSE)
  }
  out <- tryCatch(
    yaml::read_yaml(file_path),
    error = function(e) stop("Invalid YAML: ", e$message, call. = FALSE)
  )
  if (!is.list(out)) {
    stop("Config must be a YAML mapping (top-level object).", call. = FALSE)
  }
  out
}

#' Get all files of interest
#'
#' @param path Character or NULL. Directory to scan. If NULL, uses current
#'   working directory.
#' @return list of all files
#' @keywords internal
get_tracked_files <- function(
  path = NULL
) {
  scan_path <- if (base::is.null(path)) "." else path

  # Validate path exists
  if (!base::dir.exists(scan_path)) {
    stop("Path does not exist: ", scan_path)
  }

  all_files <- base::list.files(
    path = scan_path,
    all.files = TRUE,
    full.names = TRUE,
    recursive = TRUE,
    no.. = TRUE
  )

  # remove directories (hidden and not)
  all_files <- all_files[!base::file.info(all_files)$isdir]
  all_files[!base::grepl("(^|/)\\.", all_files)]
}

#' Compute file hashes
#'
#' @param output_file Character or NULL. If NULL, a default file name is
#' generated in the specified log directory.
#' @param log_dir Character. Directory to store the registry when created.
#' @return Character vector of hashes
#' @keywords internal
get_hash_output <- function(output_file = NULL, log_dir = "logs") {
  if (base::is.null(output_file)) {
    file_path <- base::paste0(
      "registry",
      # "_", base::format(base::Sys.time(), "%Y%m%d_%H%M%S"),
      ".csv"
    )
    base::file.path(log_dir, file_path)
  } else {
    output_file
  }
}

#' Get all files of interest and get their has in a CSV file.
#'
#' @param file_path Single of list of file paths
#' @param algo Default sha1
#' @keywords internal
compute_hash <- function(file_path = NULL, algo = "sha1") {
  file_path |>
    purrr::map_vec(~ digest::digest(.x, algo = algo, file = TRUE))
}

#' Get all files of interest and get their has in a CSV file.
#'
#' @param log_dir Character. Directory to store the registry when
#'   \code{registry_path} is NULL.
#' @param path Character. Path to the file(s). Default NULL
#' @param output_file Output file Default NULL
#' @export
track_file_changes <- function(
  log_dir = "logs", path = NULL, output_file = NULL
) {
  # Validate inputs
  if (!is.null(path) && !dir.exists(path)) {
    stop("Specified path does not exist: ", path)
  }

  # Make log folder with error handling
  if (!base::dir.exists(log_dir)) {
    tryCatch({
      base::dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
    }, error = function(e) {
      stop("Failed to create log directory: ", e$message)
    })
  }

  # get the files
  file_paths <- get_tracked_files(path = path)

  if (length(file_paths) == 0) {
    warning("No files found to track")
    return(invisible(NULL))
  }
  # get the output file

  output_file <- get_hash_output(
    output_file = output_file, log_dir = log_dir
  )
  # get hashes from files
  hashes <- compute_hash(file_path = file_paths)

  # export the result
  dt <- data.table::data.table(file_path = file_paths, hash = hashes)
  picard::save(
    data = dt,
    file_path = output_file,
    create_plot = FALSE
  )
}

#' Ensure date columns are of Date type
#'
#' @description
#' This function takes a data.table and a vector of column names,
#' converting the specified columns to Date type if they are not already.
#' @param df A data.table containing the data.
#' @param date_cols A character vector of
#' column names to be converted to Date type.
#' @param date_format Add a possible date format to the defaults:
#' "%Y-%m-%d", "%Y/%m/%d", "%Y%m%d"
#' @param reference_date A string representing the origin date for numeric
#' conversions. Default is "1970-01-01".
#' @return The modified data.table with specified columns as Date type.
#' @import data.table
#' @export
set_dates <- function(
    df, date_cols, date_format = NULL, reference_date = "1970-01-01") {
  # Validate inputs
  if (!data.table::is.data.table(df)) {
    stop("df must be a data.table")
  }
  if (!length(date_cols)) {
    return(df)
  } # nothing to do
  if (!all(date_cols %in% names(df))) {
    missing_cols <- base::setdiff(date_cols, names(df))
    stop(
      "The following columns are not in the data.table: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  date_formats <- c("%Y-%m-%d", "%Y/%m/%d", "%Y%m%d")
  if (!is.null(date_format)) {
    date_formats <- c(date_formats, date_format)
  }
  # Validate reference_date
  tryCatch(
    {
      origin <- as.Date(reference_date)
    },
    error = function(e) {
      stop(
        "Invalid reference_date: '",
        reference_date,
        "'. Must be a valid date string."
      )
    }
  )
  if (is.na(origin)) {
    stop(
      "Invalid reference_date: '",
      reference_date,
      "'. Must be a valid date string."
    )
  }

  # Process each date column using data.table idiom
  for (col in date_cols) {
    col_class <- class(df[[col]])
    if (is.character(col_class) ||
        any(class(col_class) %in% c("numeric", "integer"))
    ) {
      # If character or numeric, convert via origin
      df <- data.table::setDT(df)
      df[, (col) := get_date_value(
        .SD[[1]],
        origin = origin,
        date_formats = date_formats
      ), .SDcols = col] # nolint
    }
  }

  df |> data.table::as.data.table() # ensure return type
}

#' Parse various date input formats into Date objects
#' @description
#' This function takes a date input in various formats
#' (character, numeric, Date) and attempts to parse it into a Date object.
#' It supports multiple date formats for character inputs and allows
#' specifying an origin date for numeric inputs.
#' @param date_input The date input to be parsed.
#' Can be of type character, numeric, or Date or a vactor.
#' @param origin The origin date for numeric inputs.
#' Default is "1970-01-01".
#' @param date_formats A vector of date formats to try for character inputs.
#' Default formats are "%Y-%m-%d", "%Y/%m/%d", and "%Y%m%d".
#' @return A Date object if parsing is successful, otherwise NA.
#' @examples
#' get_date_value("2023-10-05")
#' get_date_value(19685) # Numeric input representing days since 1970-01-01
#' get_date_value(c("20251119", "20251118"))
#' get_date_value(c("20251119", "20251118", "Ciao"))
#' @export
get_date_value <- function(
    date_input,
    origin = "1970-01-01",
    date_formats = c("%Y-%m-%d", "%Y/%m/%d", "%Y%m%d")) {
  # Already Date
  if (base::inherits(date_input, "Date")) {
    return(date_input)
  }

  # Turn POSIXt -> Date
  if (base::inherits(date_input, "POSIXt")) {
    return(base::as.Date(date_input))
  }

  # Numeric -> days since origin
  if (base::is.numeric(date_input)) {
    return(base::as.Date(date_input, origin = origin))
  }

  # Turn Factors -> characters
  if (base::is.factor(date_input)) {
    date_input <- base::as.character(date_input)
  }

  # Characters -> try multiple formats
  if (base::is.character(date_input)) {
    n <- base::length(date_input)
    out <- base::rep(base::as.Date(NA), n)

    remaining <- base::is.na(out)

    for (fmt in date_formats) {
      if (!base::any(remaining)) {
        break
      }
      idx <- base::which(remaining)
      parsed <- base::as.Date(date_input[idx], format = fmt)
      matched <- !base::is.na(parsed)

      if (base::any(matched)) {
        out[idx[matched]] <- parsed[matched]
        remaining <- base::is.na(out)
      }
    }

    if (base::any(base::is.na(out))) {
      base::warning(
        "Some date values could not be parsed and were set to NA."
      )
    }

    return(out)
  }

  base::warning("Unsupported date_input type; returning NA of class Date.")
  base::as.Date(NA)
}
