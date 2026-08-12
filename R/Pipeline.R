#' Pipeline Class for Picard
#' @name Pipeline
#' @aliases Pipeline pipeline
#' @description
#' Provides the common orchestration utilities:
#'  - Loading YAML configs
#'  - Running the full multi-step pipeline (T2, T3, T4...)
#'  - Running substeps declared in a component config (shared method)
#'
#' Subclasses (e.g., T2Pipeline) delegate their substep execution to
#' run_substeps().
#'
#' @export
pipeline <- R6::R6Class(
  "Pipeline",
  public = list(
    #' @field config Configuration loaded from YAML
    config = NULL,
    #' @field steps List of steps to execute, loaded from the config
    steps = NULL,

    #' @description Initialize the pipeline with a YAML configuration file.
    #' @param config_pipeline Path to the YAML configuration file
    #' @return An instance of the class
    initialize = function(config_pipeline = file.path("configuration", "config_pipeline.yaml")) { # nolint
      logger::log_info("Initializing Pipeline")
      self$config <- self$load_yaml(config_pipeline)
      self$steps <- self$config$steps
    },

    #' @description Load a YAML configuration file.
    #' @param path Path to the YAML file
    #' @return Parsed YAML content as a list
    load_yaml = function(path) {
      logger::log_debug(base::paste("Loading YAML:", path))
      if (!base::file.exists(path)) {
        logger::log_error(base::paste("Config not found:", path))
        base::stop("Missing configuration file")
      }
      read_yaml(path)
    },

    #' @description Delete all contents within a folder.
    #' @param content_to_delete Path whose contents should be deleted.
    #' @param dry_run Logical. If `TRUE` (the default), report what would be
    #'   deleted without changing the filesystem.
    #' @return Invisibly, the paths found in `content_to_delete`.
    clean = function(content_to_delete, dry_run = TRUE) {
      if (!base::is.character(content_to_delete) ||
          base::length(content_to_delete) != 1L ||
          base::is.na(content_to_delete) ||
          !base::nzchar(content_to_delete)) {
        base::stop("`content_to_delete` must be one non-empty path.",
          call. = FALSE
        )
      }

      target <- fs::path_norm(fs::path_abs(content_to_delete))
      root <- target
      repeat {
        parent <- base::dirname(root)
        if (base::identical(parent, root)) {
          break
        }
        root <- parent
      }
      protected_paths <- base::unique(fs::path_norm(c(
        root,
        fs::path_abs("~"),
        fs::path_abs(base::tempdir()),
        fs::path_abs(base::getwd())
      )))

      if (target %in% protected_paths) {
        base::stop("Refusing to clean protected path: ", target,
          call. = FALSE
        )
      }
      if (!fs::dir_exists(target)) {
        base::stop("Directory does not exist: ", target, call. = FALSE)
      }

      contents <- fs::dir_ls(target, all = TRUE, fail = FALSE)
      if (base::length(contents) == 0L) {
        logger::log_info(base::paste0("Nothing to clean in: ", target))
        return(base::invisible(contents))
      }

      if (base::isTRUE(dry_run)) {
        msg <- base::paste0(
          "[DRY RUN] Would delete contents of ", target, ":\n",
          base::paste(contents, collapse = "\n")
        )
        base::message(msg)
        logger::log_info(msg)
        return(base::invisible(contents))
      }

      logger::log_info(base::paste0("Deleting contents of: ", target))
      directories <- contents[fs::is_dir(contents)]
      files <- contents[!fs::is_dir(contents)]
      if (base::length(files) > 0L) {
        fs::file_delete(files)
      }
      if (base::length(directories) > 0L) {
        fs::dir_delete(directories)
      }
      base::invisible(contents)
    },

    #' @description Update substep flags when outputs already exist.
    #'
    #' Take the configuration for a pipeline component, inspect its substeps,
    #' and disable any substep whose expected outputs are already present.
    #' @param config_file The content of YAML file as a list.
    #' @param project loaded from YAML
    #' @return Parsed YAML content as a list
    skip_step = function(config_file, project) {
      substeps <- config_file$substep
      for (substep in names(substeps)) {
        logger::log_info(paste0("checking ", substep))
        if (substep %in% names(project)) {
          output_match <- grepl("^output", names(project[[substep]]))
          output_paths <- unlist(unname(project[[substep]][output_match]))
          if (!is.null(output_paths)) {
            if (all(file.exists(output_paths))) {
              config_file$substep[[substep]] <- FALSE
              logger::log_info(base::paste0(
                "SKIPPED: ", substep, ", result(s) already present."
              ))
            }
          }
        }
      }
      config_file
    },

    #' @description Run the full pipeline.
    #' @param step_subset Optional vector of step names to run
    #' @return NULL
    run = function(step_subset = NULL) {
      logger::log_info("Starting full pipeline")
      steps_to_run <- self$steps
      if (!base::is.null(step_subset)) {
        steps_to_run <- steps_to_run[names(steps_to_run) %in% step_subset]
      }

      purrr::iwalk(steps_to_run, function(script_path, step_name) {
        logger::log_info(base::paste("Starting step:", step_name))
        base::tryCatch(
          expr = {
            base::source(fs::path_norm(script_path), local = TRUE)
            logger::log_info(base::paste("Completed", step_name))
          },
          error = function(e) {
            logger::log_error(
              base::paste(
                "Failed at", step_name, "with error:", e
              )
            )
            base::stop(
              base::paste("Pipeline aborted at step:", step_name, ". ", e)
            )
          }
        )
      })

      logger::log_success("Pipeline completed successfully")
      base::invisible(NULL)
    },

    #' @description Run substeps defined in a configuration file.
    #' @param cfg Configuration list containing substeps
    #' @param step_key Key for the step in the configuration, for example "T2"
    #' @return NULL
    run_substeps = function(cfg, step_key) {
      # Shared engine for all subclasses (T2/T3/T4) that follow the same
      # schema as config_T2.yaml: a top-level "<step_key>" section with
      # paths, and a sibling "substep" list of booleans. Ex: step_key = "T2"
      if (base::is.null(cfg[[step_key]])) {
        base::stop(
          base::paste("Missing section in config:", step_key)
        )
      }
      if (base::is.null(cfg$substep)) {
        base::stop("Missing 'substep' section in config")
      }

      root_dir <- cfg[[step_key]]$root
      src_dir <- cfg[[step_key]]$source_code

      purrr::iwalk(cfg$substep, function(should_run, sub_name) {
        logger::log_debug(
          base::paste("Checking sub-step:", sub_name)
        )
        if (base::isTRUE(should_run)) {
          script_path <- base::file.path(
            root_dir,
            src_dir,
            base::paste0(sub_name, ".R")
          )
          logger::log_info(
            base::paste("Executing step:", sub_name)
          )
          logger::log_debug(
            base::paste("from path:", script_path)
          )
          # where the script is expected to be
          base::source(
            script_path,
            local = TRUE
          )
        } else {
          logger::log_info(
            base::paste("Skipping step:", sub_name)
          )
        }
      })

      base::invisible(NULL)
    },

    #' @description Delete data for a supported specification.
    #'
    #' @param spec Specification of what to delete
    #' @param dry_run Logical. If TRUE (default), do not delete anything;
    #' only compute and report which partition paths would be removed.
    #' If FALSE, the matching partition directories are actually deleted.
    #'
    #' @return NULL
    delete_data = function(spec, dry_run = TRUE) {
      if (spec$type == "parquet_partition") {
        partition_col <- self$config$partition_col
        if (is.null(partition_col)) {
          msg <- "partition_col not specified in config; usually: 'concept_id'"
          logger::log_error(msg)
          base::stop(msg)
        }

        delete_parquet_partition(
          dataset_dir = spec$dataset_dir,
          partition_ids = spec$partition_ids,
          partition_col = partition_col,
          dry_run = dry_run
        )
      } else {
        stop("Unknown delete spec type: ", spec$type)
      }
    }
  )
)
