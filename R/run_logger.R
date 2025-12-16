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
    #' @field global_log_file Path to the global log file.
    global_log_file = NULL,
    #' @field global_appender Function for appending logs to console and file.
    global_appender = NULL,
    #' @field step_log_file Path to the step-specific log file.
    step_log_file = NULL,

    #' Initialize the LoggerManager
    #'
    #' Sets up the logging directory, global log file, and log appenders.
    #' Cleans up old logs and configures the global logger.
    #'
    #' @param log_dir Directory where logs will be stored. Defaults to "logs".
    initialize = function(log_dir = "logs") {
      self$log_dir <- log_dir
      if (!dir.exists(self$log_dir)) dir.create(self$log_dir, recursive = TRUE)

      self$global_log_file <- file.path(
        self$log_dir,
        paste0("pipeline_", Sys.Date(), ".log")
      )

      self$cleanup_old_logs()

      # Create console and file appenders
      app_console <- function(line) cat(line, "\n")
      app_file <- logger::appender_file(self$global_log_file)

      # Store the true global appender here
      self$global_appender <- function(line) {
        app_console(line)
        app_file(line)
      }

      # Set global logger
      logger::log_appender(self$global_appender)

      logger::log_threshold(logger::INFO)
    },

    #' Cleanup Old Logs
    #'
    #' Deletes log files older than a specified number of days.
    #'
    #' @param days_to_keep Number of days to retain logs. Defaults to 30 days.
    cleanup_old_logs = function(days_to_keep = 30) {
      old_logs <- list.files(self$log_dir, full.names = TRUE, recursive = TRUE)
      old_logs_dates <- file.mtime(old_logs)
      cutoff_date <- as.POSIXct(Sys.Date() - days_to_keep)
      file.remove(old_logs[old_logs_dates < cutoff_date])
    },

    #' Create Dual Appender
    #'
    #' Creates an appender that logs to both the global log file and
    #' a step-specific log file.
    #'
    #' @param step_log_path Path to the step-specific log file.
    #' @return A function that appends logs to both the global and
    #' step-specific log files.
    create_dual_appender = function(step_log_path) {
      step_appender <- logger::appender_tee(step_log_path)
      function(line) {
        self$global_appender(line)
        step_appender(line)
      }
    },

    #' Initialize Step Logger
    #'
    #' Sets up a step-specific logger that logs only to the log file.
    #'
    #' @param step_name Name of the step for which the log is being initialized.
    init_step_logger = function(step_name) {
      step_log_dir <- file.path(self$log_dir, step_name)
      if (!dir.exists(step_log_dir)) dir.create(step_log_dir, recursive = TRUE)

      self$step_log_file <- file.path(
        step_log_dir,
        paste0("step_log_", Sys.Date(), ".log")
      )

      # Create a step-specific appender
      step_appender <- logger::appender_tee(self$step_log_file)

      # Replace the global appender with the step-specific appender
      logger::log_appender(function(line) {
        step_appender(line) # Log only to the step-specific appender
      })
      logger::log_threshold(logger::DEBUG)
      logger::log_info("Logger initialized for step: {step_name}")
    },

    #' Start Capturing Print Statements
    #'
    #' Redirects all `stdout` output (e.g., print statements)
    #' to the global log file.
    #'
    #' @return None
    start_capturing_prints = function() {
      if (!is.null(self$step_log_file)) {
        sink(self$step_log_file, append = TRUE, type = "output")
      }
    },

    #' Stop Capturing Print Statements
    #'
    #' Stops redirecting `stdout` output to the global log file.
    #'
    #' @return None
    stop_capturing_prints = function() {
      sink(type = "output")
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
