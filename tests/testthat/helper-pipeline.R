create_temp_step_script <- function(label, marker_path) {
  script_path <- fs::path_norm(
    file.path(tempdir(), paste0("step_", label, ".R"))
  )

  # Convert to forward slashes for cross-platform compatibility
  marker_path_normalized <- gsub("\\\\", "/", marker_path)

  base::writeLines(
    paste0(
      "base::cat(\"", label, "\\n\", file = \"",
      marker_path_normalized, "\", append = TRUE)"
    ),
    con = script_path
  )
  script_path
}

create_temp_pipeline_yaml <- function(step_labels, marker_path) {
  step_scripts <- purrr::set_names(
    purrr::map(step_labels, create_temp_step_script, marker_path = marker_path),
    step_labels
  )

  yaml_path <- fs::path_norm(file.path(tempdir(), "config_pipeline.yaml"))
  yaml::write_yaml(list(steps = step_scripts), yaml_path)

  list(yaml_path = yaml_path, marker = marker_path)
}

create_substep_config <- function(
    substep_names,
    root = "T2root",
    src = "source_code",
    marker_path = NULL) {
  full_root <- fs::path_norm(base::file.path(base::tempdir(), root, src))
  base::dir.create(full_root, recursive = TRUE, showWarnings = FALSE)

  # Convert marker_path to forward slashes
  # marker_path_normalized <- gsub("\\\\", "/", marker_path)
  marker_path_normalized <- normalizePath(
    marker_path,
    winslash = "/", mustWork = FALSE
  )

  # Accept either:
  # - character vector: c("s1","s2")  -> all TRUE
  # - named logical vector: c(s1=TRUE, s2=FALSE)
  if (is.character(substep_names) && is.null(base::names(substep_names))) {
    flags <- base::rep(TRUE, base::length(substep_names))
    substep_list <- stats::setNames(as.list(flags), substep_names)
  } else {
    if (is.null(base::names(substep_names)) ||
      any(base::names(substep_names) == "")) {
      base::stop("substep_names must be named or character.")
    }
    substep_list <- stats::setNames(
      as.list(base::as.logical(substep_names)),
      base::names(substep_names)
    )
  }

  # Write scripts using the *names* of the substeps
  purrr::iwalk(
    substep_list,
    function(.flag, .name) {
      base::writeLines(
        base::paste0(
          "base::cat(\"", .name, "\\n\", file = \"",
          marker_path_normalized, "\", append = TRUE)"
        ),
        fs::path_norm(base::file.path(full_root, base::paste0(.name, ".R")))
      )
    }
  )

  list(
    T2 = list(
      root = fs::path_norm(base::file.path(base::tempdir(), root)),
      source_code = src
    ),
    substep = substep_list
  )
}
