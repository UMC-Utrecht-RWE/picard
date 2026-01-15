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
load_config_values <- function(file_path = NULL) {
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

#' Run an R script and log its execution details
#'
#' @description
#' This function executes an R script, computes its SHA1 hash,
#' and logs the execution details (timestamp, filename, SHA1 hash)
#' to a specified log directory. If no registry path is provided,
#' a new log file is created with a timestamped name.
#' @param file_path Path to the R script to be executed.
#' @param log_dir Directory where the log file will be stored.
#' Default is "log".
#' @param registry_path Optional path to an existing log file.
#' If NULL, a new log file will be created.
#' @param quiet If TRUE, suppresses return value. Default is TRUE.
#' @return A list containing:
#' - file: The path to the executed R script.
#' - sha1: The SHA1 hash of the executed script.
#' - registry: The path to the log file.
#' - timing: The time taken to execute the script.ß
#' - env: The environment in which the script was executed.
#' @importFrom digest digest
#' @export
run_script <- function(
    file_path,
    log_dir = "logs",
    registry_path = NULL,
    quiet = TRUE) {
  file_path <- fs::path_norm(file_path)
  file_path <- base::normalizePath(file_path, mustWork = TRUE)

  if (!base::dir.exists(log_dir)) {
    base::dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # If no registry path is provided, create a new log file
  if (base::is.null(registry_path)) {
    # If a valid registry_path is already in log_dir, use it
    existing_logs <- base::list.files(
      path = log_dir,
      pattern = "^registry_\\d{8}_\\d{6}\\.log$"
    )
    if (length(existing_logs) > 0) { # use the most recent one
      registry_path <- base::file.path(log_dir, utils::tail(existing_logs, 1))
    } else {
      reg_name <- base::paste0(
        "registry_",
        base::format(base::Sys.time(), "%Y%m%d_%H%M%S"),
        ".log"
      )
      registry_path <- base::file.path(log_dir, reg_name)
    }
  }

  sha1 <- digest::digest(file = file_path, algo = "sha1")

  con <- base::file(registry_path, open = "a", encoding = "UTF-8")
  base::on.exit(base::close(con), add = TRUE)

  line <- base::paste(
    "Date:",
    base::format(base::Sys.time(), "%Y-%m-%d %H:%M:%S"),
    "- File:",
    base::basename(file_path),
    "- SHA1:",
    sha1
  )
  base::writeLines(line, con = con, useBytes = TRUE)

  env <- base::new.env(parent = base::globalenv())
  timing <- base::system.time(
    base::sys.source(file = file_path, envir = env, chdir = TRUE)
  )

  logger::log_debug(
    base::paste0(base::basename(file_path), ": ", sha1)
  )

  if (quiet) {
    invisible(NULL)
  } else {
    list(
      file = file_path,
      sha1 = sha1,
      registry = registry_path,
      timing = timing,
      env = env
    )
  }
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
