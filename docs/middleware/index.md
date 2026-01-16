# Middleware

The middleware is the "glue" around Senzing that make the system work. There are
three middleware applications:

- [Consumer]
- [Redoer]
- [Exporter]

Each middleware app imports the Senzing SDK as a set of Python libraries.

Each piece of middleware is a stand-alone Python application running in its own
Docker container:

- Consumer and Redoer are meant to be continually-running.
  - There can be multiple instances of Consumer.
- On the other hand, Exporter is meant to be fired up, do its thing, and then
  shut down.

Each middleware app physically consists of, basically, two files:

- a Python module
- a Dockerfile

## Supporting modules

Along with the three main middleware applications, there are several supporting
modules that provide shared functionality.

### db.py

This module provides the "API" to the export_tracker table. This is the only
place where the database should be accessed directly.

### loglib.py

Provides logging-related code. Logs are written to STDOUT.

### otel.py

This module provides OpenTelemetry initialization/setup logic. Throughout the
Python code you'll find supporting code to generate and emit OTel metrics. These
get collected and used in the CloudWatch dashboards.

Of note, metrics can be sent to an OTLP collector, or written to STDOUT. This is
configurable via environment variable.

### timeout_handling.py

There is no default 'timeout' handling for calls made to the Senzing SDK.
Therefore, we have to implement some timeout logic ourselves so we bail from
calls to Senzing that appear to stalled. The module makes use of the
`signal.SIGALRM` facility. The timeout value itself is configurable via
environment variable. This is used by Consumer and Redoer.

### healthcheck.sh

This is used by Docker as a simple way to check the status of the
container/application. It simply checks that the Python application is running.
To make this happen, there is a call in the Dockerfiles that look like this:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ./healthcheck.sh consumer.py || exit 1
```

## dev-scripts folder

There are various ad-hoc Python tools inside the `dev-scripts` folder. Most of
these are addressed in the README file, but a couple are not and so they are
addressed here.

`sz_eng`: This launches a Python REPL with the sz_engine object already
instantiated:

```bash
docker compose run tools python -i dev/sz_eng.py
```

`check_export_tracker`: This tool provides some basic checking and insight into
the existence and contents of the export_traker table:

```bash
# Basic usage -- check table exists:
docker compose run tools python dev/check_export_tracker.py

# To dump contents of export_tracker to stdout:
docker compose run tools python dev/check_export_tracker.py dump

# Choose which export_status (1, 2, or 3) to dump (default is 1):
docker compose run tools python dev/check_export_tracker.py dump 2

# Get metrics about rows (counts, basically):
docker compose run tools python dev/check_export_tracker.py metrics

# Example:
Running as user: senzing
Executing command: python dev/check_export_tracker.py metrics
==================================================
Checking that export_tracker was set up ...
o sqs_entity_resolution database exists OK
o export_tracker table exists OK
==================================================
{'TODO': 0, 'IN PROGRESS': 0, 'DONE': 127}
```

## Regarding data source names

Each record needs to have a "data source". Senzing needs to know that data
source name before it can process records from that data source. As mentioned
earlier, data source names are added dynamically by Consumer. However, there are
actually several ways to load Data Source names into Senzing.

1. Via environment variable `SENZING_TOOLS_DATASOURCES`. E.g.:

    ```bash
    export SENZING_TOOLS_DATASOURCES="CUSTOMER REFERENCE WATCHLIST"
    ```

1. Via the `sz_configtool` utility. E.g.:

    ```bash
    (szcfg) addDataSource `CUSTOMERS`
    Data source successfully added!
    (szcfg) save
    Are you certain you wish to proceed and save changes? (y/n) y
    Configuration changes saved!
    ```

1. Dynamically via Python using the Senzing SDK. Take a look at the code in
   consumer.py for details.

> [!NOTE]
> It's also possible for the Redoer to encounter a `SzUnknownDataSourceError`
> error when attempting to process a record. It's not clear why that is, but,
> nonetheless, some perfunctory code has been added to Redoer to "reload" the
> Senzing config (which contains data source names) if/when that happens.

More info:

- [Managing the Senzing ER configuration][managing]
- [`SENZING_TOOLS_DATASOURCES` environment variable][datasources-var]
- [How to add a data source][add-datasource]

# Test suite

See the section "Running Tests" in the README.

# Maintenance

## External libs

The Dockerfiles generally pull in the dependent libs; they will pull in the
proper versions at build time.

The test suite, however, uses a `requirements.txt` file. This file defines
specific lib versions. At some point in the future, the versions defined in this
file might need to be upgraded.

## Export tracker table

The export_tracker table will continue to grow (old rows will have a status of
DONE or SKIPPED). At some point, it could be worthwhile to create a tool to
empty/truncate the table.

[add-datasource]: https://www.senzing.com/docs/entity_specification/#how-to-add-a-data-source
[consumer]: consumer.md
[datasources-var]: https://github.com/senzing-garage/knowledge-base/blob/main/lists/environment-variables.md#senzing_tools_datasources
[exporter]: exporter.md
[managing]: https://senzing.zendesk.com/hc/en-us/articles/360010784333--Advanced-Managing-the-Senzing-ER-configuration
[redoer]: redoer.md
