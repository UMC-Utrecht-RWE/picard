# LoggerManager Class

A class for managing logging functionality in a pipeline. It supports
logging to both console and files, cleaning up old logs, and creating
step-specific loggers.

## Public fields

- `log_dir`:

  Directory where logs are stored.

- `verbose`:

  Verbosity level for logging. Options are "Normal", "Low", or "High".

- `run_id`:

  Unique identifier for the current run.

- `global_log_file`:

  Path to the global log file.

- `step_log_file`:

  Path to the step-specific log file.

- `step_appender`:

  Function for appending logs to step-specific file.

- `registry`:

  A registry of hash values

- `run_start_time`:

  Timestamp when the run started.

- `step_start_time`:

  Timestamp when the current step started.

- `script_start_time`:

  Timestamp when the current script started.

- `last_log_time`:

  Timestamp of the last log entry.

- `current_step`:

  Name of the current step being executed.

- `current_script`:

  Name of the current script being executed.

- `output_con`:

  Connection for capturing stdout.

- `message_con`:

  Connection for capturing messages/warnings.

- `capture_active`:

  Whether capturing of print statements is active.

- `capture_target`:

  Target log file for captured prints.

## Methods

### Public methods

- [`LoggerManager$new()`](#method-LoggerManager-initialize)

- [`LoggerManager$reset()`](#method-LoggerManager-reset)

- [`LoggerManager$is_configured()`](#method-LoggerManager-is_configured)

- [`LoggerManager$configure()`](#method-LoggerManager-configure)

- [`LoggerManager$cleanup_old_logs()`](#method-LoggerManager-cleanup_old_logs)

- [`LoggerManager$start_step_logger()`](#method-LoggerManager-start_step_logger)

- [`LoggerManager$end_step_logger()`](#method-LoggerManager-end_step_logger)

- [`LoggerManager$start_script()`](#method-LoggerManager-start_script)

- [`LoggerManager$end_script()`](#method-LoggerManager-end_script)

- [`LoggerManager$start_capturing_prints()`](#method-LoggerManager-start_capturing_prints)

- [`LoggerManager$stop_capturing_prints()`](#method-LoggerManager-stop_capturing_prints)

- [`LoggerManager$clone()`](#method-LoggerManager-clone)

------------------------------------------------------------------------

### `LoggerManager$new()`

Initialize the LoggerManager instance.

#### Usage

    LoggerManager$new()

#### Returns

NULL

------------------------------------------------------------------------

### `LoggerManager$reset()`

Reset the instance back to its unconfigured state.

Stops any active print capture, clears all configuration fields, and
undoes the
[`logger::log_appender()`](https://daroczig.github.io/logger/reference/log_appender.html)/`log_layout()`/`log_threshold()`
registrations that `configure()` sets up for the "global"/"picard"
namespaces. Those registrations live in the `logger` package's own
global state, not on this object, so they would otherwise survive a
reset and keep pointing at a stale (possibly deleted) log file. Used to
keep the exported singleton clean between test runs.

#### Usage

    LoggerManager$reset()

#### Returns

NULL Check whether the logger has been configured

------------------------------------------------------------------------

### `LoggerManager$is_configured()`

#### Usage

    LoggerManager$is_configured()

#### Returns

Logical scalar. TRUE when configure() has been called. configure the
LoggerManager

Sets up the logging directory, global log file, and log appenders.
Cleans up old logs and configures the global logger.

------------------------------------------------------------------------

### `LoggerManager$configure()`

#### Usage

    LoggerManager$configure(log_dir = "logs", verbose = c("Normal", "High", "Low"))

#### Arguments

- `log_dir`:

  Directory where logs will be stored. Defaults to "logs".

- `verbose`:

  Verbosity level.

------------------------------------------------------------------------

### `LoggerManager$cleanup_old_logs()`

Delete log files older than a specified number of days.

#### Usage

    LoggerManager$cleanup_old_logs(days_to_keep = 30)

#### Arguments

- `days_to_keep`:

  Number of days to retain logs. Defaults to 30 days.

------------------------------------------------------------------------

### `LoggerManager$start_step_logger()`

Initialize a step-specific logger.

Sets up a step-specific logger that logs only to the log file.

#### Usage

    LoggerManager$start_step_logger(step_name)

#### Arguments

- `step_name`:

  Name of the step for which the log is being initialized.

------------------------------------------------------------------------

### `LoggerManager$end_step_logger()`

Reset the step-specific logger.

#### Usage

    LoggerManager$end_step_logger()

#### Returns

None

------------------------------------------------------------------------

### `LoggerManager$start_script()`

Start the timer for a script within the current step.

#### Usage

    LoggerManager$start_script(script_name)

#### Arguments

- `script_name`:

  Name of the script being started.

------------------------------------------------------------------------

### `LoggerManager$end_script()`

Reset the current script timer.

#### Usage

    LoggerManager$end_script()

#### Returns

None

------------------------------------------------------------------------

### `LoggerManager$start_capturing_prints()`

Start capturing print statements.

Redirect `stdout` output, such as print statements, to a log file.

#### Usage

    LoggerManager$start_capturing_prints(
      target = c("step", "global"),
      capture_messages = TRUE
    )

#### Arguments

- `target`:

  Target log file to capture prints. Options are "global" or "step".

- `capture_messages`:

  Whether to also capture messages/warnings.

#### Returns

None

------------------------------------------------------------------------

### `LoggerManager$stop_capturing_prints()`

Stop capturing print statements.

Stop redirecting `stdout` output to the active log file.

#### Usage

    LoggerManager$stop_capturing_prints()

#### Returns

None

------------------------------------------------------------------------

### `LoggerManager$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LoggerManager$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
