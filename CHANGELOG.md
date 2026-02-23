# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/UMC-Utrecht-RWE/RSV-1026/releases
[V1.2.0]: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.2
[V1.1.0]: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1.1
[V1.0.0]: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1

