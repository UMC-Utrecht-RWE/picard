#' T4Pipeline Class
#'
#' @description
#' This class is responsible for managing the T4 pipeline, including loading
#' configuration files, executing steps, and cleaning up files.
#'
#' @details
#' The T4Pipeline class is designed to handle the T4 pipeline for semantic
#' harmonization. It loads configuration files, executes the steps defined in
#' the configuration, and cleans up files as needed.
#'
#' @export
t4_pipeline <- R6::R6Class(
  "T4Pipeline",
  inherit = pipeline,
  public = list(
    #' @field T4 Configuration for the T4 pipeline
    T4 = NULL,

    #' Initialize the T4 pipeline with a YAML configuration file
    #' @param config_t4 Path to the YAML configuration file for T4
    #' @return An instance of T4Pipeline
    initialize = function(
      config_t4 = base::file.path("configuration", "config_T4.yaml")
    ) {
      logger::log_info("Initializing T4 class")
      self$T4 <- super$load_yaml(config_t4)
      logger::log_debug("T4 config loaded")
    },

    #' Clean up files related to the T4 pipeline
    #' @return NULL
    clean = function() {
      # Implement if you need to clear intermediates, etc.
      # Keep no-op to preserve current caller expectations.
      logger::log_info("Removing T4 intermediate files")
      if (self$T4$cleanup$intermediate_data_file) {
        super$clean(content_to_delete = fs::path(
          self$T4$T4$root,
          self$T4$T4$intermediate
        ))
      }
      base::invisible(NULL)
    },

    #' Run the T4 pipeline
    #' @return NULL
    run = function() {
      logger::log_info("Running T4 substeps via Pipeline engine")
      super$run_substeps(self$T4, step_key = "T4")
      logger::log_success("Step T4 completed successfully")
      base::invisible(NULL)
    },

    #' Delete files
    #' @param files Dictionary containing file to be deleted.
    #' @return NULL
    delete_data = function(files = NULL) {
      spec <- if (is.null(files)) self$T4$parquet_files
      logger::log_info("Deleting files.")
      super$delete_data(spec = spec)
      base::invisible(NULL)
    }
  )
)
