# Pipeline Class for RSV-1026 Project

Provides the common orchestration utilities:

- Loading YAML configs

- Running the full multi-step pipeline (T2, T3, T4...)

- Running substeps declared in a component config (shared method)

Subclasses (e.g., T2Pipeline) delegate their substep execution to
run_substeps().

## Public fields

- `config`:

  Configuration loaded from YAML

- `steps`:

  List of steps to execute, loaded from the config

## Methods

### Public methods

- [`Pipeline$new()`](#method-Pipeline-initialize)

- [`Pipeline$load_yaml()`](#method-Pipeline-load_yaml)

- [`Pipeline$clean()`](#method-Pipeline-clean)

- [`Pipeline$skip_step()`](#method-Pipeline-skip_step)

- [`Pipeline$run()`](#method-Pipeline-run)

- [`Pipeline$run_substeps()`](#method-Pipeline-run_substeps)

- [`Pipeline$delete_data()`](#method-Pipeline-delete_data)

- [`Pipeline$clone()`](#method-Pipeline-clone)

------------------------------------------------------------------------

### `Pipeline$new()`

Initialize the pipeline with a YAML configuration file.

#### Usage

    Pipeline$new(
      config_pipeline = file.path("configuration", "config_pipeline.yaml")
    )

#### Arguments

- `config_pipeline`:

  Path to the YAML configuration file

#### Returns

An instance of the class

------------------------------------------------------------------------

### `Pipeline$load_yaml()`

Load a YAML configuration file.

#### Usage

    Pipeline$load_yaml(path)

#### Arguments

- `path`:

  Path to the YAML file

#### Returns

Parsed YAML content as a list

------------------------------------------------------------------------

### `Pipeline$clean()`

Delete all files within a folder.

#### Usage

    Pipeline$clean(content_to_delete)

#### Arguments

- `content_to_delete`:

  Path to be deleted

#### Returns

NULL

------------------------------------------------------------------------

### `Pipeline$skip_step()`

Update substep flags when outputs already exist.

Take the configuration for a pipeline component, inspect its substeps,
and disable any substep whose expected outputs are already present.

#### Usage

    Pipeline$skip_step(config_file, project)

#### Arguments

- `config_file`:

  The content of YAML file as a list.

- `project`:

  loaded from YAML

#### Returns

Parsed YAML content as a list

------------------------------------------------------------------------

### `Pipeline$run()`

Run the full pipeline.

#### Usage

    Pipeline$run(step_subset = NULL)

#### Arguments

- `step_subset`:

  Optional vector of step names to run

#### Returns

NULL

------------------------------------------------------------------------

### `Pipeline$run_substeps()`

Run substeps defined in a configuration file.

#### Usage

    Pipeline$run_substeps(cfg, step_key)

#### Arguments

- `cfg`:

  Configuration list containing substeps

- `step_key`:

  Key for the step in the configuration, for example "T2"

#### Returns

NULL

------------------------------------------------------------------------

### `Pipeline$delete_data()`

Delete data for a supported specification.

#### Usage

    Pipeline$delete_data(spec, dry_run = TRUE)

#### Arguments

- `spec`:

  Specification of what to delete

- `dry_run`:

  Logical. If TRUE (default), do not delete anything; only compute and
  report which partition paths would be removed. If FALSE, the matching
  partition directories are actually deleted.

#### Returns

NULL

------------------------------------------------------------------------

### `Pipeline$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Pipeline$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
