#' T2Pipeline Class
#'
#' @description
#' This class is responsible for managing the T2 pipeline, including loading
#' configuration files, executing steps, and cleaning up files.
#'
#' @details
#' The T2Pipeline class is designed to handle the T2 pipeline for semantic
#' harmonization. It loads configuration files, executes the steps defined in
#' the configuration, and cleans up files as needed.
#'
#' @export
t2_pipeline <- R6::R6Class(
  "T2Pipeline",
  inherit = pipeline,
  public = list(
    #' @field T2 Configuration for the T2 pipeline
    T2 = NULL,
    #' @field project Configuration for the whole pipeline
    project = NULL,

    #' Initialize the T2 pipeline with a YAML configuration file
    #' @param config_t2 Path to the YAML configuration file for T2
    #' @param config_project Path to the YAML configuration file of the run
    #' @param skip_substeps Logical indicating whether to skip substeps
    #'  with existing outputs
    #' @return An instance of T2Pipeline
    initialize = function(
      config_t2 = base::file.path("configuration", "config_T2.yaml"),
      config_project = file.path("configuration", "config_project.yaml"),
      skip_substeps = FALSE
    ) {
      logger::log_info("Initializing T2 class")
      self$T2 <- super$load_yaml(config_t2)
      self$project <- super$load_yaml(config_project)
      logger::log_debug("T2 config loaded")

      if (skip_substeps) {
        logger::log_info("Skipping substeps with existing outputs")
        self$T2 <- super$skip_step(self$T2, self$project)
      }
    },

    #' Clean up files related to the T2 pipeline
    #' @return NULL
    clean = function() {
      # Implement if you need to clear intermediates, etc.
      # Keep no-op to preserve current caller expectations.
      logger::log_debug("Removing T2 intermediate files")
      if (self$T2$cleanup$intermediate_data_file) {
        super$clean(content_to_delete = fs::path(
          self$T2$T2$root,
          self$T2$T2$intermediate
        ))
      }
      base::invisible(NULL)
    },

    #' Run the T2 pipeline
    #' @return NULL
    run = function() {
      logger::log_debug("Running T2 substeps via Pipeline engine")
      super$run_substeps(self$T2, step_key = "T2")
      base::invisible(NULL)
    },

    #' Delete files
    #' @param files Dictionary containing file to be deleted.
    #' @return NULL
    delete_data = function(files = NULL) {
      spec <- if (is.null(files)) self$T2$parquet_files
      logger::log_debug("Deleting files.")
      super$delete_data(spec = spec)
      base::invisible(NULL)
    }
  )
)
