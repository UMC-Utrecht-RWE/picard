# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [V1.2.5]

### Added

- `analyze_pipeline_log()` (`R/post_run_analysis.R`): parses a pipeline log and produces run/level/alert/step/script/gap summary tables plus diagnostic plots (`level_summary`, `step_summary`, `script_summary`, `step_timeline`, `script_timeline`, `gap_summary`), written to an `analysis/<log_name>` folder next to the log.
- `start_script_logging()` / `stop_script_logging()` and exported `log_trace`/`log_debug`/`log_info`/`log_success`/`log_warn`/`log_error`/`log_fatal` wrappers (`R/logging_helpers.R`), so project scripts can log through `picard` without depending on `logger` directly. They become no-ops when the pipeline already owns the logging context.
- `track_file_changes()` gained `only_format`/`exclude_format` arguments to include or exclude files by extension when hashing (mutually exclusive).
- Colourised console log output, with a new `SUCCESS` log level used for the final "Pipeline completed successfully" message.
- `TUTORIAL.md`, a full walkthrough with a terminology section; `README.md` significantly expanded.

### Changed

- CSV reading now goes through `data.table::fread` (`R/load.R`) instead of base/utils readers.
- Reworked yaml/sql loading internals (`dispatch_reader`, `load_raw`, `prepare_load_request` in `R/load.R`/`R/load_sql_query.R`), replacing the old `get_tracked_files` path.
- `DESCRIPTION`: `License` switched from `file LICENSE` to the standard `GPL-3` specifier, `Depends` bumped to `R (>= 4.1.0)`, dropped the `here` dependency, cleaned up the Title/Description text, migrated to `Config/roxygen2/version` (roxygen2 8.0.0).
- General CRAN-compliance pass across `R/Pipeline.R`, `R/audit.R`, `R/run_logger.R`, `R/save.R`, `R/plot_data.R`, `R/delete_data.R`, `R/utils.R`, `.Rbuildignore`, `.gitignore`.
- `step_timeline`/`script_timeline` plots now order steps/scripts chronologically by their actual start time instead of alphabetically.

### Fixed

- `.parse_log_line()` (`R/post_run_analysis.R`): the "High" verbosity regex required a trailing `| <hash>` field; log lines with an empty message (e.g. a stray ANSI colour code) omitted that field and silently fell back to a mismatched pattern, corrupting the parsed `step` column. The hash field is now optional in the regex.
- CSV loading no longer raises a spurious row-count-mismatch error when `nrow`/`nrows`/`skip` are passed to limit the rows read.

### Removed

- Bundled `LICENSE` file text (674 lines), in favour of the standard `GPL-3` license specifier in `DESCRIPTION`.
- `man/cheatsheet/picard.pdf` and `man/figures/*.png` binary assets, removed from the package for CRAN size compliance.

## [V1.2.4]

### Changed

- Packaged pubblished in zenodo.org

## [V1.2.3]

### Changed

- Minor changes in `README.md` and cheatsheet file.
- CSV files read by `data.table` and not by `utils` package.

### Added

- Added `codemeta.json`

## [V1.2.2]

### Added

- Added `R/deprecated.R` for deprecated but still in use for now functions.

### Changed

- Simplyfied tag originations for `R/audit.R`.
- `R/read_data.R::read_data()` is now `R/load.R::load()` all other aspects of the function are unchanged.
- `R/save_data.R::save_data()` is now `R/save.R::save()` all other aspects of the function are unchanged.
- `R/load_sql_query.R::execute_sql_file()` can now save results in parquet.

### Future Work

- `R/load_sql_query.R::load_sql_query()` should be handle by `R/load.R::load()`.
- Fix warning in `R/audit.R` when `DESCRIPTION` not present.

## [V1.2.1]

### Fixed

- `R/audit.R:.get_release_version` kept giving us problems with the DEAPs, we decided to remove any call to git as not prosent in DEAPs'enviroment.
- Fixed bug with `save_data:save_data.R` it was not passing file name correctly to `plot_data`

### Added

- `save_data.R:prepare_output_path` handles all combinations of `file_path` and `file_name`. If `file_name` is present will overwrite the name in `file_path` (if that is present). If `file_name` has no extension, it will take the one in `file_path` (if that is present). If that is not possible, it will give an error.

## [V1.2.0]

### Added

- `R/delete_data.R`: File that deletes whetever path you pass to in not a dry run.

### Changed

- `R/audit.R`: Expanded and fixed but in `.get_release_version` that created a bug when git was not prosent. Infos are now also gathered from `DESCRIPTION`. It does not create errors if none if present.

### Fixed

- `DESCRIPTION`'s Version was not updated to 1.1.0, creating installation problems. It is now fixed with release 1.2.0.

## [V1.1.0]

### Added

- Testing: Created tests for every part of the code and brought test coverage >95% (Ubuntu only GitHub action check).
- `R/utils.R:read_yaml`: Validate if file is yaml or not.
- `R/zzz.R` added handle for global variable so R-CMD does not give errors for data.table and the plotting functions.
- `.lintr` to help with handling error messages.
- `r_cmd_check.yaml` for compatibility with CRAN and `pkgdown.yaml` for similar reasons.
- `test_coverage.yaml` to give a clear indication of what has been tested. It fails if coverage is less then 95%.
- `read_parquet` in `R/read_data.R` to read parquet files, that are now the default in our work.
- New file `R/delete_data.R` with functionality `delete_parquet_partition`. Such function (and potentially others) can be used by the pipeline class(es) to delete parquet files that are now the way we save intermidate data files.

### Changed

- `R/run_logger.R` refactoring of the code so to have a `global` and `step` log. The first captures all log messages from each step, the seconds contain also print message. The idea is the first gives a general overview the second more details. New functions:
  - `start_script/end_script`: For capturing logs on singular scripts.
  - `start_capturing_prints/stop_capturing_prints`: For capturing whatever is printed on terminal.
  - `start_step_logger/end_step_logger`: For capturing logs for the whole step (is not `init_step_logger` any longer)
  - `.layout_with_timers`: The system records turn-around-time of every interaction. User can select the verbose level of messaging.
  - SHA1 value for logging.
- `R/audit.R:audit_add`: It can save lists (thus data.table) into the txt files.
- `R/utils.R:load_config_values` is now `R/utils.R:load_config`.
- `code-quality.yaml` is now `code_quality.yaml` and it has been refactor.
- `testthat.yaml` now tests for every enviroment and

### Removed

- Removed `R/globals.R` and put its content in `R/zzz.R`

### Fixed

- A typo prevented Github action triggering
- All test files have the same nomenclature test_<name\>.R

## [V1.0.0]

- All major functions transfered here from the RSV-1026 repository.

# List of releases

- unreleased: https://github.com/UMC-Utrecht-RWE/RSV-1026/releases
- V1.2.5: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.5
- V1.2.4: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.4
- V1.2.3: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.3
- V1.2.2: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.2
- V1.2.1: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.1
- V1.2.0: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2.0
- V1.1.0: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.1
- V1.0.0: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1
