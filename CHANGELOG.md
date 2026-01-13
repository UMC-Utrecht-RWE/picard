# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Testing: Created tests for every part of the code and brought test coverage >95% (Ubuntu only GitHub action check).
- `R/utils.R:read_yaml`: Validate if file is yaml or not.

### Changed
- `R/run_logger.R` refactoring of the code so to have a `global` and `step` log. The first captures all log messages from each step, the seconds contain also print message. The idea is the first gives a general overview the second more details. New functions:
    - `start_script/end_script`: For capturing logs on singular scripts.
    - `start_capturing_prints/stop_capturing_prints`: For capturing whatever is printed on terminal.
    - `start_step_logger/end_step_logger`: For capturing logs for the whole step.
    - `.layout_with_timers`: The system records turn-around-time of every interaction. User can select the verbose level of messaging.
- `R/audit.R:audit_add`: It can save lists (thus data.table) into the txt files.

### Removed
-

### Fixed
- A typo prevented Github action triggering
- All test files have the same nomenclature test_<name\>.R

## [V1.0.0]
- All major functions transfered here from the RSV-1026 repository.

[unreleased]: https://github.com/UMC-Utrecht-RWE/RSV-1026/releases
[V1.0.0]: https://github.com/UMC-Utrecht-RWE/picard/releases/tag/v1

