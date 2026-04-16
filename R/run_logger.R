#' LoggerManager Class
#'
#' A class for managing logging functionality in a pipeline.
#' It supports logging to both console and files,
#' cleaning up old logs, and creating step-specific loggers.
#'
#' @import R6
#' @import logger
#' @export
LoggerManager <- R6::R6Class( # nolint
  classname = "LoggerManager",
  public = list(
    #' @field log_dir Directory where logs are stored.
    log_dir = NULL,
    #' @field verbose Verbosity level for logging.
    #' Options are "Normal", "Low", or "High".
    verbose = NULL,
    #' @field run_id Unique identifier for the current run.
    run_id = NULL,
    #' @field global_log_file Path to the global log file.
    global_log_file = NULL,
    #' @field step_log_file Path to the step-specific log file.
    step_log_file = NULL,
    #' @field step_appender Function for appending logs to step-specific file.
    step_appender = NULL,
    #' @field registry A registry of hash values
    registry = NULL,

    #' @field run_start_time Timestamp when the run started.
    run_start_time = NULL,
    #' @field step_start_time Timestamp when the current step started.
    step_start_time = NULL,
    #' @field script_start_time Timestamp when the current script started.
    script_start_time = NULL,
    #' @field last_log_time Timestamp of the last log entry.
    last_log_time = NULL,

    #' @field current_step Name of the current step being executed.
    current_step = NULL,
    #' @field current_script Name of the current script being executed.
    current_script = NULL,
    #' @field output_con Connection for capturing stdout.
    output_con = NULL,
    #' @field message_con Connection for capturing messages/warnings.
    message_con = NULL,
    #' @field capture_active Whether capturing of print statements is active.
    capture_active = FALSE,
    #' @field capture_target Target log file for captured prints.
    capture_target = NULL,

    #' Initialize LoggerManager
    #' Constructor for the LoggerManager class.
    #' @return NULL
    initialize = function() {
      invisible(self)
    },

    #' configure the LoggerManager
    #'
    #' Sets up the logging directory, global log file, and log appenders.
    #' Cleans up old logs and configures the global logger.
    #'
    #' @param log_dir Directory where logs will be stored. Defaults to "logs".
    #' @param verbose Verbosity level.
    configure = function(log_dir = "logs",
                         verbose = c("Normal", "High", "Low")) {
      self$log_dir <- log_dir
      if (!base::dir.exists(self$log_dir)) {
        base::dir.create(self$log_dir, recursive = TRUE)
      }

      self$run_id <- base::format(base::Sys.time(), "%Y%m%d_%H%M%S")
      self$run_start_time <- base::Sys.time()
      self$last_log_time <- self$run_start_time

      self$global_log_file <- base::file.path(
        self$log_dir,
        base::paste0("pipeline_", self$run_id, ".log")
      )
      # If verbose not provided, set to "Normal"
      self$verbose <- base::match.arg(verbose)

      self$cleanup_old_logs()

      # Ensure the global log file exists
      if (!base::file.exists(self$global_log_file)) {
        base::file.create(self$global_log_file)
      }

      # Create console and file appenders
      app_console <- function(line) base::cat(line, "\n")
      app_main <- logger::appender_file(self$global_log_file)

      # Configure logger for global and package namespaces.
      namespaces <- c("global", "picard")
      logger::log_layout(self$.layout_with_timers, namespace = namespaces)
      logger::log_threshold(logger::TRACE, namespace = namespaces)

      logger::log_appender(function(line) {
        app_console(line)

        if (!(isTRUE(self$capture_active) &&
          base::identical(self$capture_target, "global"))) {
          app_main(line)
        }

        if (!base::is.null(self$step_appender)) {
          if (!(isTRUE(self$capture_active) &&
            base::identical(self$capture_target, "step"))) {
            self$step_appender(line)
          }
        }
      }, namespace = namespaces)

      self$registry <- tryCatch(
        {
          picard::load(picard:::get_hash_output(log_dir = self$log_dir))
        },
        error = function(e) {
          NULL
        }
      )
      if (is.null(self$registry) & self$verbose == "High") {
        logger::log_error("Registry file necessary!")
        stop("Registry file necessary!")
      }

      logger::log_info("Pipeline configured. run_id={self$run_id}")
      invisible(self)
    },

    #' Cleanup Old Logs
    #'
    #' Deletes log files older than a specified number of days.
    #'
    #' @param days_to_keep Number of days to retain logs. Defaults to 30 days.
    cleanup_old_logs = function(days_to_keep = 30) {
      old_logs <- base::list.files(
        self$log_dir,
        full.names = TRUE,
        recursive = TRUE
      )

      if (length(old_logs) == 0) {
        return(invisible(NULL))
      }

      old_logs_dates <- base::file.mtime(old_logs)
      cutoff_date <- base::as.POSIXct(base::Sys.Date() - days_to_keep)

      base::file.remove(old_logs[old_logs_dates < cutoff_date])

      invisible(NULL)
    },

    #' Initialize Step Logger
    #'
    #' Sets up a step-specific logger that logs only to the log file.
    #'
    #' @param step_name Name of the step for which the log is being initialized.
    start_step_logger = function(step_name) {
      self$current_step <- step_name
      self$step_start_time <- base::Sys.time()
      self$current_script <- NULL
      self$script_start_time <- NULL

      step_log_dir <- base::file.path(self$log_dir, step_name)
      if (!base::dir.exists(step_log_dir)) {
        base::dir.create(step_log_dir, recursive = TRUE)
      }

      self$step_log_file <- base::file.path(
        step_log_dir,
        base::paste0("step_", step_name, "_", self$run_id, ".log")
      )

      self$step_appender <- logger::appender_file(self$step_log_file)

      logger::log_info("Step started: {step_name}")

      invisible(self)
    },

    #' End Step Logger
    #'
    #' Reset the step-specific logger.
    #' @return None
    end_step_logger = function() {
      if (!base::is.null(self$current_step)) {
        logger::log_info("Step ended: {self$current_step}")
      }

      self$current_step <- NULL
      self$step_start_time <- NULL
      self$current_script <- NULL
      self$script_start_time <- NULL
      self$step_log_file <- NULL
      self$step_appender <- NULL

      invisible(self)
    },

    #' Start Script Timer
    #'
    #' As for start_step_logger, but for scripts within steps.
    #' @param script_name Name of the script being started.
    start_script = function(script_name) {
      self$current_script <- script_name
      self$script_start_time <- base::Sys.time()
      logger::log_info("Script started: {script_name}")
      invisible(self)
    },

    #' End Script Timer
    #'
    #' Resets the script timer.
    #' @return None
    end_script = function() {
      if (!base::is.null(self$current_script)) {
        logger::log_info("Script ended: {self$current_script}")
      }
      self$current_script <- NULL
      self$script_start_time <- NULL
      invisible(self)
    },

    #' Layout with Timers
    #'
    #' Custom log layout function that includes timing information.
    #' @param record Log record.
    #' @param level Log level.
    #' @param msg Log message.
    #' @param namespace Namespace of the log message.
    #' @param .logcall Call information.
    #' @param .topcall Top-level call information.
    #' @param .topenv Top-level environment.
    #' @param ... Additional arguments.
    #' @return Formatted log message string.
    .layout_with_timers = function(level,
                                   msg = NULL,
                                   namespace = NULL,
                                   .logcall = NULL,
                                   .topcall = NULL,
                                   .topenv = NULL,
                                   ...) {
      if (base::is.list(level) && !base::is.null(level$msg)) {
        record <- level
        lvl <- record$level
        message <- record$msg
      } else {
        lvl <- level
        message <- msg
      }

      lvl_txt <- lvl
      if (base::is.numeric(lvl)) {
        lvl_map <- c(
          "TRACE" = 600,
          "DEBUG" = 500,
          "INFO" = 400,
          "SUCCESS" = 350,
          "WARN" = 300,
          "ERROR" = 200,
          "FATAL" = 100
        )
        rev_map <- stats::setNames(names(lvl_map), as.character(lvl_map))
        lvl_txt <- rev_map[as.character(lvl_txt)]
        if (base::is.na(lvl_txt)) {
          lvl_txt <- base::as.character(lvl)
        }
      }

      now <- base::Sys.time()

      run_s <- base::as.numeric(
        base::difftime(now, self$run_start_time, units = "secs")
      )

      step_s <- NA_real_
      if (!base::is.null(self$step_start_time)) {
        step_s <- base::as.numeric(
          base::difftime(now, self$step_start_time, units = "secs")
        )
      }

      script_s <- NA_real_
      if (!base::is.null(self$script_start_time)) {
        script_s <- base::as.numeric(
          base::difftime(now, self$script_start_time, units = "secs")
        )
      }

      delta_s <- base::as.numeric(
        base::difftime(now, self$last_log_time, units = "secs")
      )
      self$last_log_time <- now

      step <- if (is.null(self$current_step)) "-" else self$current_step
      scr <- if (is.null(self$current_script)) "-" else self$current_script

      step_txt <- if (is.na(step_s)) "NA" else base::sprintf("%.2f", step_s)
      scr_txt <- if (is.na(script_s)) "NA" else base::sprintf("%.2f", script_s)

      # Be sure current_script is an existing file (not a directory)
      # Not all log messages are connected with a file.
      hash <- ""
      if (self$verbose == "High" && !is.null(self$current_script) &&
        file_test("-f", self$current_script)) {
        hash <- picard:::compute_hash(self$current_script)

        if (!is.null(self$registry) &&
          nrow(self$registry[file_path == self$current_script]) == 1 &&
          hash != self$registry[file_path == self$current_script]$hash) {
          hash <- paste0(hash, "\nScript modified by user\n")
        }
      }

      # Change the color of the message based on message level,
      # using crayon package. The mapping is as follows:
      # Level	 Colour
      # Trace	Purple
      # Debug	Blue
      # Info	No change
      # Success	Green
      # Warning	Yellow
      # Error	Red
      # Fatal	Dark Red (bold)
      line <- if (self$verbose == "Low") {
        base::sprintf(
          "%s | %-5s | %s",
          base::format(now, "%Y-%m-%d %H:%M:%S"),
          lvl_txt,
          message
        )
      } else if (self$verbose == "Normal") {
        base::sprintf(
          "%s | %-5s | run+%8.2fs | scr+%8ss | %s/%s | %s",
          base::format(now, "%Y-%m-%d %H:%M:%S"),
          lvl_txt,
          run_s,
          scr_txt,
          step,
          scr,
          message
        )
      } else if (self$verbose == "High") {
        base::sprintf( # Original with step and script times
          "%s | %-5s | run+%8.2fs | step+%8ss | scr+%8ss | d+%7.2fs | %s/%s | %s | %s", # nolint
          base::format(now, "%Y-%m-%d %H:%M:%S"),
          lvl_txt,
          run_s,
          step_txt,
          scr_txt,
          delta_s,
          step,
          scr,
          message,
          hash
        )
      } else {
        ""
      }

      if (requireNamespace("crayon", quietly = TRUE)) {
        color_fun <- switch(lvl_txt,
          "TRACE" = crayon::magenta,
          "DEBUG" = crayon::blue,
          "INFO" = identity,
          "SUCCESS" = crayon::green,
          "WARN" = crayon::yellow,
          "ERROR" = crayon::red,
          "FATAL" = crayon::red$bold,
          identity
        )
        line <- color_fun(line)
      }

      line
    },

    #' Start Capturing Print Statements
    #'
    #' Redirects all `stdout` output (e.g., print statements)
    #' to the global log file.
    #' @param target Target log file to capture prints.
    #'  Options are "global" or "step".
    #' @param capture_messages Whether to also capture messages/warnings.
    #' @return None
    start_capturing_prints = function(target = c("step", "global"),
                                      capture_messages = TRUE) {
      target <- base::match.arg(target)

      sink_file <- if (target == "global") {
        self$global_log_file
      } else {
        self$step_log_file
      }

      self$stop_capturing_prints()

      self$capture_active <- TRUE
      self$capture_target <- target

      sink_path <- base::as.character(sink_file)

      self$output_con <- base::file(sink_path, open = "at", encoding = "UTF-8")
      base::sink(self$output_con, type = "output", split = TRUE)

      if (isTRUE(capture_messages)) {
        self$message_con <- file(sink_path, open = "at", encoding = "UTF-8")

        ok <- TRUE
        tryCatch(
          base::sink(self$message_con, type = "message", split = TRUE),
          error = function(e) ok <<- FALSE
        )

        if (!ok) {
          # fallback: capture messages to file only
          base::sink(self$message_con, type = "message")
        }
      }
      invisible(TRUE)
    },

    #' Stop Capturing Print Statements
    #'
    #' Stops redirecting `stdout` output to the global log file.
    #'
    #' @return None
    stop_capturing_prints = function() {
      if (!isTRUE(self$capture_active)) {
        return(invisible(TRUE))
      }

      self$capture_active <- FALSE
      self$capture_target <- NULL

      if (sink.number(type = "message") > 0 && !is.null(self$message_con)) {
        base::sink(type = "message")
      }
      if (sink.number(type = "output") > 0 && !is.null(self$output_con)) {
        base::sink(type = "output")
      }

      if (!base::is.null(self$message_con)) {
        base::close(self$message_con)
        self$message_con <- NULL
      }
      if (!base::is.null(self$output_con)) {
        base::close(self$output_con)
        self$output_con <- NULL
      }
      invisible(TRUE)
    }
  )
)

#' Get LoggerManager Instance
#'
#' Returns a singleton instance of the LoggerManager class.
#'
#' @return A singleton instance of the LoggerManager class.
#' @keywords internal
.get_logger_manager_instance <- local({
  instance <- NULL
  function() {
    if (is.null(instance)) {
      instance <<- LoggerManager$new()
    }
    instance
  }
})

#' Logger Manager Singleton
#'
#' A singleton instance of the LoggerManager class
#' for managing logging in the pipeline.
#'
#' @export
logger_manager <- .get_logger_manager_instance()

#' Reset LoggerManager Singleton (for tests)
#' This is only for testing, ignore it.
#' @keywords internal
.reset_logger_manager_instance <- function() {
  env <- base::environment(.get_logger_manager_instance)
  env$instance <- NULL
  invisible(NULL)
}
