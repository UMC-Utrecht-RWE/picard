[![DOI](https://zenodo.org/badge/1095759057.svg)](https://doi.org/10.5281/zenodo.19554744)
# Pipeline Integration and Coordination for Automated R Dataflows <a href="https://github.com/UMC-Utrecht-RWE"><img src="man/figures/logo.png" align="right" height="188"/></a>

Pipeline Integration and Coordination for Automated R Dataflows (PICARD) is the internal orchestration engine developed by Real World Evidence (RWE) UMC Utrecht to manage and automate our multi-step data transformation pipelines used in clinical research.

It acts as the command bridge for R-based workflows, ensuring that each phase of the data journey — from harmonisation to statistical output — is executed consistently and transparently.

PICARD does not perform the transformations itself.
Instead, it organises, triggers, and monitors R scripts specific to each project and transformation step (T2, T3, T4 and T5), according to configuration files and logging rules.

# Design Philosophy
PICARD is inspired by principles of modular orchestration and transparency.

To address RWE’s peculiar pipeline needs, each ETL pipeline is divided into two parts: one stable and one flexible.

**Transformations**
The flexible part of each project is due to the fact that each project has different objectives and strategies to achieve them. This brings to the creation of *ad-hoc* scripts for every sub-step of each pipeline step. Each sub-step is contained in the correct sub-folder of the `transformations` folder of the project.

Each sub-step script must run independently and, given the instructions in the configuration file, produce an output (intermediate file).

## The pipeline package
We developed this pipeline orchestrator to run each sub-step.

Each step (T2, T3, T4 and T5) is defined by its respective class, all subclasses of a main `pipeline` class.
Given the configuration files, each class finds the sub-step to run (Configuration-Driven Execution).

Configuration files (YAML) live outside the code, defining structure and runtime parameters, promoting reproducibility and auditability.

This makes PICARD future-proof for integration with DAG-based frameworks (e.g., targets, Snakemake, or Airflow).

# Core Functionality
- `Pipeline.R:pipeline`: This is the mother class that contains the methods of the children classes.
  - Runs the subclasses with the method `run`.
  - `skip_step` skips sub-steps script if `intermediate file(s)` is present.
  - `load_yaml` load the config file that defines the whole pipeline.
- `T*Pipeline.R:t*_pipeline`:
  - The `run` method executes all sub-steps configured for the step.
  - `clean` method not yet fully implemented.

Each `t*_pipeline` is identical except for `t2_pipeline` that implements the `skip_step` method.

## Auxiliary functions
Besides orchestrating the pipeline, the package also provides I/O helpers and auditing utilities.
- I/O:
  - `load.R:load`: Unique function to load any kind of file given a path, returns a `data.table`.
  - `save.R:save`: Unique function to save any kind of file given a path and data.
  - `load_sql_query.R:load_sql_query` and `execute_sql_file`: Loads and execute SQL code.
  - `utils.R:load_config`: Load the YAML files used to configure the pipeline.
- Auditing:
  - `run_logger.R` Integrated Logging: full audit trail using the internal logger.R module.
  - `audit.R`: It creates a `.txt` with user defined information to monitor the script.
  - `plot_data.R:plot_data_features`: It plots each column of an `intermediate file(s)`

## Installation
```R
pak::pkg_install("github::UMC-Utrecht-RWE/picard@main")
# or
remotes::install_github("UMC-Utrecht-RWE/picard", ref = "main")
```
If the above does not work and the repository is private, this means that **R is not authenticated to GitHub**, do the following:
```R
install.packages(c("usethis", "gitcreds", "gh"))
usethis::create_github_token()
```
When prompted, approve the default option.
```R
gitcreds::gitcreds_set()
```
Double check results with
```R
gh::gh_whoami()
# {
#   "name": "XXX YYY",
#   "login": "zzzzz",
#   "html_url": "https://github.com/zzzzz",
#   "scopes": "read:user, repo, user:email, workflow",
#   "token": "xxxx...xxxx"
# }
```

## Example Usage
```R
library(picard)

# Load configuration
config <- picard::load_config("configuration/config_pipeline.yaml")

# Initialize and run the pipeline
pipeline <- picard::Pipeline$new(config)
pipeline$run_all()

# Logs and intermediates
# /intermediate_data_file/
# /logs/
```
## Cheatsheets
<a href="man/cheatsheet/picard.pdf"><img src="man/figures/cheatsheet.png" width="630" height="252"/></a>

# Governance and Security
PICARD aligns with UMC Utrecht’s and VAC4EU’s data protection principles:
- Designed for execution within the UMCU DRE secure environment
- Compliant with FAIR data principles
- Ensures consistent and auditable execution of ETL and analytical pipelines

🖖 “Make it run.”
