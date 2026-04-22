# PICARD Tutorial

This tutorial shows how to set up and run a PICARD pipeline from scratch.

## What You Will Build

You will create:
- a minimal project layout,
- one full pipeline config,
- one step config (T2),
- a few sample substep scripts,
- and execute the pipeline end to end.

## 1. Create a Minimal Project Structure

```text
my_project/
  configuration/
    config_pipeline.yaml
    config_T2.yaml
    config_project.yaml
    run_t2.R
  transformations/
    T2/
      import_source.R
      map_codes.R
      derive_outcomes.R
  data/
  logs/
```

## 2. Create Pipeline Configuration

Create `configuration/config_pipeline.yaml`:

```yaml
steps:
  T2: "configuration/run_t2.R"
```

This file defines the top-level steps and the script to execute for each step.

Now create `configuration/run_t2.R`:

```r
library(picard)

t2 <- picard::t2_pipeline$new(
  config_t2 = "configuration/config_T2.yaml",
  config_project = "configuration/config_project.yaml",
  skip_substeps = TRUE
)

t2$run()
```

## 3. Create Step Configuration (T2)

Create `configuration/config_T2.yaml`:

```yaml
T2:
  root: "."
  source_code: "transformations/T2"
  intermediate: "data/intermediate_data_file"

substep:
  import_source: true
  map_codes: true
  derive_outcomes: false

cleanup:
  intermediate_data_file: false

parquet_files:
  type: parquet_partition
  dataset_dir: "data/parquet_hives"
  partition_ids:
    - "B_COAGDEF_AESI"
    - "B_COAGDEF_COV"
```

Create `configuration/config_project.yaml` (used by `skip_substeps`):

```yaml
import_source:
  output: "data/intermediate_data_file/import_source.parquet"

map_codes:
  output: "data/intermediate_data_file/map_codes.parquet"

derive_outcomes:
  output: "data/intermediate_data_file/derive_outcomes.parquet"

partition_col: "concept_id"
```

## 4. Create Substep Scripts

Create `transformations/T2/import_source.R`:

```r
library(picard)
library(data.table)

dt <- data.table(person_id = 1:5, code = c("A", "B", "A", "C", "B"))
picard::save(dt, "data/intermediate_data_file/import_source.parquet")
```

Create `transformations/T2/map_codes.R`:

```r
library(picard)

dt <- picard::load("data/intermediate_data_file/import_source.parquet")
dt[, mapped_code := paste0("MAP_", code)]
picard::save(dt, "data/intermediate_data_file/map_codes.parquet")
```

Create `transformations/T2/derive_outcomes.R`:

```r
library(picard)

dt <- picard::load("data/intermediate_data_file/map_codes.parquet")
dt[, outcome := mapped_code %in% c("MAP_A", "MAP_B")]
picard::save(dt, "data/intermediate_data_file/derive_outcomes.parquet")
```

Because `derive_outcomes` is set to `false`, this script will be skipped.

## 5. Run the Pipeline

In R:

```r
library(picard)

pl <- picard::pipeline$new("configuration/config_pipeline.yaml")
pl$run()
```

Expected behavior:
- PICARD runs `run_t2.R` as the T2 step.
- T2 executes enabled substeps from `config_T2.yaml`.
- `derive_outcomes.R` is skipped.

## 6. Selective Execution

Run only specific top-level steps:

```r
pl$run(step_subset = c("T2"))
```

## 7. Use Built-In I/O Utilities

```r
library(picard)

# Read input
x <- picard::load("data/intermediate_data_file/map_codes.parquet")

# Save output
picard::save(x, "data/final_output.csv")

# Discover available handlers
picard::list_readers()
picard::list_writers()
```

## 8. Add Simple Auditing

```r
library(picard)

dt <- picard::load("data/intermediate_data_file/map_codes.parquet")

picard::audit_start(dir_output = "data/audits", file_name = "map_codes")
picard::audit_add("Rows: ", nrow(dt))
picard::audit_add("Unique person_id: ", length(unique(dt$person_id)))
picard::audit_end()
```

## 9. SQL Workflow Example

```r
library(picard)
library(DBI)
library(duckdb)

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit(DBI::dbDisconnect(con), add = TRUE)

sql <- picard::load_sql_query(
  file_path = "sql/example.sql",
  params = list(schema = "main", table = "my_table")
)

result <- picard::execute_sql_file(sql = sql, conn = con)
```

## 10. Troubleshooting Checklist

- `Missing configuration file`:
  - Check relative paths and current working directory.
- `Missing section in config: T2`:
  - Ensure the top-level `T2:` key exists in `config_T2.yaml`.
- `Missing 'substep' section in config`:
  - Ensure `substep:` exists and contains named booleans.
- `No reader/writer registered for extension`:
  - Check file extension or add custom handlers with `register_reader()` / `register_writer()`.
- Substep unexpectedly skipped:
  - If `skip_substeps = TRUE`, verify outputs listed in `config_project.yaml`.

## Next Steps

- Add T3/T4/T5 by following the same pattern as T2.
- Keep each substep script independent and testable.
- Keep configuration files version-controlled to preserve reproducibility.
