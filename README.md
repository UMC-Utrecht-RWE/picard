<div class="img-label-wrapper">
<img src="man/figures/logo.png" width=200 height=203 style="float:right">
</div>
<!-- <img src="man/figures/logo.png" width=125 height=128 align='right'> -->
# Pipeline Integration and Coordination for Automated R Dataflows

# Overview
Pipeline Integration and Coordination for Automated R Dataflows (PICARD) is the internal orchestration engine developed by UMC Utrecht to manage and automate multi-step data transformation pipelines used in clinical research.

It acts as the command bridge for R-based workflows, ensuring that each phase of the data journey — from harmonisation to statistical output — is executed consistently and transparently.

PICARD does not perform the transformations itself.
Instead, it organises, triggers, and monitors R scripts specific to each project and transformation step (T2, T3, T4 and T5), according to configuration files and logging rules.

# Core Functionality
- Dynamic Step Discovery: automatically detects available transformation scripts and executes only those defined in the configuration.
- Configuration-Driven Execution: YAML-based control of pipeline structure and runtime parameters.
- Integrated Logging: full audit trail using the internal logger.R module.
- Reproducible Orchestration: ensures ordered and documented execution across study pipelines.
- Project Flexibility: supports multiple clinical data pipelines, each aligned with the ConcePTION Common Data Model and VAC4EU ETL framework.

# Design Philosophy
PICARD is inspired by principles of modular orchestration and transparency:

Each step defines a self-contained `run()` function.

The pipeline discovers and executes substeps dynamically.

Every action is logged.

Configurations live outside the code, promoting reproducibility and auditability.

This makes PICARD future-proof for integration with DAG-based frameworks (e.g., targets, Snakemake, or Airflow).

## Example Usage
```R
library(picard)

# Load configuration
config <- picard::load_config_values("configuration/config_pipeline.yaml")

# Initialize and run the pipeline
pipeline <- picard::Pipeline$new(config)
pipeline$run_all()

# Logs and intermediates
# /intermediate_data_file/
# /logs/
```

# Governance and Security
PICARD aligns with UMC Utrecht’s and VAC4EU’s data protection principles:
- Designed for execution within the UMCU DRE secure environment
- Compliant with FAIR data principles
- Ensures consistent and auditable execution of ETL and analytical pipelines

🖖 “Make it run.”