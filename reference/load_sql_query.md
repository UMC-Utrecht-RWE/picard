# Load SQL file as a single query string with variable interpolation

Reads a .sql script from disk, normalises tabs to spaces, converts
full-line `-- ...` comments into `/* ... */`, and optionally
interpolates variables using `{var_name}` syntax.

## Usage

``` r
load_sql_query(file_path, encoding = "UTF-8", params = NULL)
```

## Arguments

- file_path:

  path to the .sql file

- encoding:

  file encoding passed to readLines(); default "UTF-8"

- params:

  named list of parameters to interpolate into the SQL. Use `{param}` in
  your SQL file to reference these.

## Value

character(1) containing the full SQL with interpolated values

## Examples

``` r
if (FALSE) { # \dontrun{
# SQL file content: SELECT * FROM {schema}.{table} WHERE id > {min_id}
query <- load_sql_query(
  "queries/my_query.sql",
  params = list(
    schema = "public",
    table = "users",
    min_id = 100
  )
)
} # }
```
