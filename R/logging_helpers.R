#' PICARD logging wrappers
#'
#' @description
#' Convenience wrappers around the corresponding `logger` functions.
#' They let project substeps depend only on `picard`, while still using the
#' logger configuration currently active for the `picard` namespace.
#'
#' @param ... Arguments passed through to `logger`.
#'
#' @return Invisibly returns the result of the underlying `logger` call.
#' @name picard-logging
NULL

#' @rdname picard-logging
#' @export
log_trace <- function(...) {
  logger::log_trace(...)
}

#' @rdname picard-logging
#' @export
log_debug <- function(...) {
  logger::log_debug(...)
}

#' @rdname picard-logging
#' @export
log_info <- function(...) {
  logger::log_info(...)
}

#' @rdname picard-logging
#' @export
log_success <- function(...) {
  logger::log_success(...)
}

#' @rdname picard-logging
#' @export
log_warn <- function(...) {
  logger::log_warn(...)
}

#' @rdname picard-logging
#' @export
log_error <- function(...) {
  logger::log_error(...)
}

#' @rdname picard-logging
#' @export
log_fatal <- function(...) {
  logger::log_fatal(...)
}

#' Start script-level logging when available
#'
#' @description
#' Starts script timing and print capture when the PICARD logger has been
#' configured. When the script already runs inside a managed PICARD context,
#' the function becomes a no-op so the same incipit can be used both
#' standalone and inside the pipeline.
#'
#' @param script_name Optional label for the script in the log.
#'   Defaults to the current sourced filename when available.
#' @param capture_prints Logical; if `TRUE` (default), capture printed output.
#' @param capture_messages Logical; if `TRUE` (default), also capture
#'   messages and warnings when capturing prints.
#' @param envir Environment used to store the ownership flag.
#'   Defaults to `parent.frame()`.
#'
#' @return Invisibly returns `TRUE` when this call started logging,
#'   otherwise `FALSE`.
#' @export
start_script_logging <- function(
  script_name = NULL,
  capture_prints = TRUE,
  capture_messages = TRUE,
  envir = parent.frame()
) {
  if (!is.environment(envir)) {
    stop("envir must be an environment", call. = FALSE)
  }

  lm <- picard::logger_manager
  owner_flag <- ".picard_script_logging_owner"

  if (is.null(script_name)) {
    script_name <- tryCatch(
      scriptName::current_source_filename(),
      error = function(e) NULL
    )
    if (is.null(script_name) || !nzchar(script_name)) {
      script_name <- tryCatch(
        scriptName::current_filename(),
        error = function(e) NULL
      )
    }
    if (is.null(script_name) || !nzchar(script_name)) {
      script_name <- "script"
    }
    script_name <- basename(script_name)
  }

  if (!base::isTRUE(lm$is_configured()) ||
    !is.null(lm$current_script)) {
    assign(owner_flag, FALSE, envir = envir)
    return(invisible(FALSE))
  }

  started_script <- isTRUE(lm$start_script(script_name))
  started_capture <- FALSE

  if (isTRUE(capture_prints)) {
    capture_target <- if (is.null(lm$step_log_file)) "global" else "step"
    started_capture <- isTRUE(
      lm$start_capturing_prints(
        target = capture_target,
        capture_messages = capture_messages
      )
    )
  }

  assign(owner_flag, started_script || started_capture, envir = envir)
  invisible(started_script || started_capture)
}

#' Stop script-level logging when owned by the current script
#'
#' @description
#' Counterpart to `start_script_logging()`. If the current script did not start
#' logging itself, this function is a no-op.
#'
#' @param envir Environment that holds the ownership flag.
#'   Defaults to `parent.frame()`.
#'
#' @return Invisibly returns `TRUE` when this call stopped logging,
#'   otherwise `FALSE`.
#' @export
stop_script_logging <- function(envir = parent.frame()) {
  if (!is.environment(envir)) {
    stop("envir must be an environment", call. = FALSE)
  }

  owner_flag <- ".picard_script_logging_owner"
  is_owner <- isTRUE(
    base::get0(
      owner_flag,
      envir = envir,
      inherits = FALSE,
      ifnotfound = FALSE
    )
  )

  if (base::exists(owner_flag, envir = envir, inherits = FALSE)) {
    base::rm(list = owner_flag, envir = envir)
  }

  if (!is_owner) {
    return(invisible(FALSE))
  }

  lm <- picard::logger_manager
  lm$stop_capturing_prints()
  lm$end_script()
  invisible(TRUE)
}
