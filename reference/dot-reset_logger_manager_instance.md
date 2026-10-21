# Reset LoggerManager Singleton (for tests) This is only for testing, ignore it.

Clears the singleton's configuration state in place. It deliberately
never replaces the underlying object: the exported `logger_manager`
binding is fixed to the original instance for the life of the session,
so anything short of an in-place reset would leave that binding (and any
reference already grabbed from it) permanently out of sync.

## Usage

``` r
.reset_logger_manager_instance()
```
