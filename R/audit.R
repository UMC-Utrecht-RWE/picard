# A simple function to create audit files.
# We want to have a file that can be produced within the pipeline that
# saves the changes happening to the data, like:
# data A has 80 lines, after filtering 1 it has 70 etc.
# This is not a log, but a reader friendly way to monitor the content of the
# data and the results.

# Private environment to hold the state of the currently open audit file,
# so we don't need to store it in the user's session options().
.audit_state <- new.env(parent = emptyenv())

#' audit_start
#' @name audit_start
#' @description Start a new audit file, writing a header with the script
#' (and optional DEAP analysis) name and the start time. Must be called
#' before [audit_add()] or [audit_end()].
#' @param dir_output Character where to save the file
#' @param file_name With default NULL, the output file name will be the same
#' as the file in which the function is invoked.
#' @param deap_name Character, name of the DEAP analysis
#' @param delete_old Boolean, delete_old if file exist
#' @param format Default txt
#' @return Character, invisibly. The generated file name (without the
#' directory), i.e. what `dir_output` was joined with to create the file.
#' @examples
#' \dontrun{
#' # Typical usage inside a pipeline script:
#' picard::audit_start(
#'   dir_output = "data/audits",
#'   file_name = "create_studycohort",
#'   deap_name = "MyStudy"
#' )
#'
#' # Plain text line
#' picard::audit_add("Loaded ", nrow(my_data), " rows from D3_ELIGIBILITY")
#'
#' # A data.frame/data.table is rendered as a readable markdown table
#' summary_dt <- data.table::data.table(
#'   group = c("EXPOSED", "CONTROL"),
#'   n = c(120, 480)
#' )
#' picard::audit_add(summary_dt)
#'
#' # Always close the audit file at the end of the script
#' picard::audit_end()
#' }
#' @export
audit_start <- function(
  dir_output = "data/audits",
  file_name = NULL,
  deap_name = NULL,
  delete_old = TRUE,
  format = ".txt"
) {
  if (is.null(file_name)) {
    file_name <- scriptName::current_filename()
    file_name <- basename(tools::file_path_sans_ext(file_name))
  }

  file_name_sens <- file_name
  file_name <- paste0(
    base::format(base::Sys.time(), "%Y-%m-%d_%H%M%S_"), file_name
  )

  if (tools::file_ext(file_name) == "") {
    file_name <- paste0(file_name, format)
  }

  dir_output <- fs::path_norm(dir_output)
  if (!base::dir.exists(dir_output)) {
    base::dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)
    logger::log_info(base::paste("Created directory:", dir_output))
  }

  audit_file <- list.files(
    dir_output,
    pattern = file_name_sens, full.names = TRUE
  )
  # create a fresh file if none exists yet, or clear it if delete_old = TRUE
  if (
    length(audit_file) == 0 ||
      (all(base::file.exists(audit_file)) && delete_old)
  ) {
    if (delete_old && length(audit_file) > 0) {
      # remove old files with same name sens
      base::file.remove(audit_file)
    }
    # create new file
    audit_file <- file.path(dir_output, file_name)
    base::file.create(audit_file)
    logger::log_info(base::paste("Created audit file:", audit_file))
  }

  start_time <- base::Sys.time()
  if (!is.null(deap_name)) {
    header <- paste0(
      "=== Audit for ", file_name_sens, " (", deap_name, ")", " ===\n",
      sep = " "
    )
  } else {
    header <- paste0("=== Audit for ", file_name_sens, " ===\n")
  }
  base::cat(
    header,
    file = audit_file,
    append = TRUE,
    sep = ""
  )
  base::cat(
    "Started at: ", base::format(start_time, "%Y-%m-%d %H:%M:%S"), "\n\n",
    file = audit_file,
    append = TRUE,
    sep = ""
  )

  # store path in the internal state so audit_add() can find it
  .audit_state$current_audit_file <- audit_file
  .audit_state$current_start_time <- start_time

  base::invisible(file_name)
}


#' audit_add
#' @name audit_add
#' @description Append content to the currently open audit file. The
#' behavior depends on what is passed in `...`:
#' * A single data.frame/data.table is rendered as a readable markdown
#'   table.
#' * Anything else is pasted together (as in `paste0(...)`) and appended
#'   as a single text line.
#' @param ... Objects to be added to the audit file. See description for
#' how each type is handled.
#' @return NULL, invisibly.
#' @export
audit_add <- function(...) {
  audit_file <- .audit_state$current_audit_file
  if (base::is.null(audit_file)) {
    stop(
      "audit_add() called before audit_start()",
      call. = FALSE
    )
  }

  args <- list(...)
  if (length(args) == 1 && base::is.data.frame(args[[1]])) {
    base::cat(
      .format_markdown_table(args[[1]]), "\n\n",
      file = audit_file,
      append = TRUE,
      sep = ""
    )
  } else {
    msg <- base::paste0(...)

    base::cat(
      msg, "\n",
      file = audit_file,
      append = TRUE,
      sep = ""
    )
  }

  base::invisible(NULL)
}


#' Format a data.frame/data.table as a padded markdown pipe table
#' @param dt data.frame or data.table to format
#' @return Character, a single string with the formatted table
#' @keywords internal
.format_markdown_table <- function(dt) {
  dt <- base::as.data.frame(dt)
  header <- base::vapply(base::names(dt), base::format, character(1))
  body <- base::vapply(dt, base::format, character(base::nrow(dt)))
  body <- base::matrix(body, nrow = base::nrow(dt))

  cells <- base::rbind(header, body)
  widths <- base::apply(cells, 2, function(col) base::max(base::nchar(col)))
  pad <- function(row) {
    base::vapply(
      base::seq_along(row),
      function(i) base::formatC(row[i], width = -widths[i]),
      character(1)
    )
  }

  rows <- base::apply(cells, 1, function(row) {
    base::paste0("| ", base::paste(pad(row), collapse = " | "), " |")
  })
  sep <- base::paste0(
    "| ",
    base::paste(base::strrep("-", base::pmax(widths, 3L)), collapse = " | "),
    " |"
  )

  base::paste(c(rows[1], sep, rows[-1]), collapse = "\n")
}

#' Get release version
#' @return Character string with version info
#' @keywords internal
.get_release_version <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("picard")),
    error = function(e) NULL
  )

  if (!is.null(version)) {
    latest_tag <- version
    tag_origin <- "installed package version"
  } else {
    latest_tag <- "unknown"
    tag_origin <- "unknown tag origin"
  }

  tag_time <- tryCatch(
    base::Sys.time(),
    error = function(e) "unknown time"
  )

  paste0(
    latest_tag, " (", tag_origin, ").\n",
    "Time of creation of this file: ", tag_time
  )
}

#' audit_end
#' @name audit_end
#' @description Close the audit file with summary and version stamp
#' @return NULL
#' @export
audit_end <- function() {
  audit_file <- .audit_state$current_audit_file
  start_time <- .audit_state$current_start_time
  if (base::is.null(audit_file)) {
    stop("audit_end() called before audit_start()", call. = FALSE)
  }
  release <- .get_release_version()

  base::cat(
    "\n", "Audit completed: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
    "\n",
    "Generated by: ", format(release), "\n",
    file = audit_file,
    append = TRUE,
    sep = ""
  )

  end_time <- base::Sys.time()
  duration <- difftime(end_time, start_time)

  base::cat(
    "Finished at: ",
    base::format(end_time, "%Y-%m-%d %H:%M:%S"), " mins\n",
    " Duration: ", round(duration, 2),
    "\n\n",
    file = audit_file,
    append = TRUE,
    sep = ""
  )

  # Clear internal state
  .audit_state$current_audit_file <- NULL
  .audit_state$current_start_time <- NULL

  logger::log_info(paste("Audit file saved:", audit_file))
  base::invisible(NULL)
}
