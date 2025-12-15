# Middleware Documentation

The reader is advised to first go over the README.md article in full prior to 
reading this one. In particular, the README file details all the environment 
variables for each of the middleware apps.

## Introduction

Firstly: what are the "pieces" of Senzing itself?
- the database
- the Senzing SDK

The middleware apps are the "glue" around Senzing that make the system work.  
There are three middleware applications: 
- Consumer
- Redoer
- Exporter

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

## Consumer

- Dockerfile.consumer
- middleware/consumer.py

Consumer's job is to poll the SQS queue for a new message, retrieve that message 
(which contains a record), and add the record to Senzing.

The basic loop is:

    while 1:
      Get message from SQS queue (blocks up to 20 seconds before retrying)
      Call Senzing's `add_record`
      Store affected entity IDs in the export tracker database table
      Delete message from queue

(The export tracker database table will be discussed in a later section.)

There is additional logic to handle errors/exceptions, including:
- timeouts -- configurable via the `SZ_CALL_TIMEOUT_SECONDS` environment 
  variable.
- Senzing errors
- general errors

In the case of an error, the message is *not* deleted from the SQS queue. 

More info:
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.add_record

### Dynamic data source names

One particular event that can occur is that a new Data Source Name is 
encountered (in a record) which Senzing has never seen before; this results in 
Senzing raising a `SzUnknownDataSourceError`. This can happen when first loading 
a brand-new data set. We expect this to happen. When it does, Consumer will 
dynamically "add" the new Data Source Name to the Senzing database. Note that 
for logging/metric purposes, it will treat this as an "error" but it isn't 
actually an error in the normal sense. 

See also: the section down below titled "Regarding data source names".

### Required fields

At minimum, an incoming record MUST have these two fields:
- `DATA_SOURCE` (string)
- `RECORD_ID` (string)

## Redoer

- Dockerfile.redoer
- middleware/redoer.py

Redoer is the other continually-running middleware app. It's job is to check 
Senzing's REDO queue and process so-called REDO records as needed.

From Senzing: "There are times the Senzing engine determines additional work 
needs to be performed on an entity. In some cases it will automatically decide 
this work should be done at a different time. [...] When this happens, an 
special record is written to the SYS_EVAL_QUEUE table for future processing.  
These entries and known as REDOs or redo records".

The outcome of a REDOing a record is similar to adding a record: an entity might 
be created, or deleted, or modified (i.e., reocrds affiliated or disaffiliated 
with that entity).

Redoer's logic is approximately like so (note that things are slightly 
simplified here for explanatory purposes):

    while 1:
      Call Senzing's `count_redo_records`
      If count is non-zero, call Senzing's `get_redo_record`
      If the return value is empty, try again.
      Call Senzing's `process_redo_record`
      Store affected entity IDs in the export tracker database table

(The export tracker database table will be discussed in a later section.)

The primary call to note above is the call to `process_redo_record`. 

At this point, it might not be clear what "getting" a REDO record really means.  
To be clear: the record itself is *not* removed from the database. It is 
possible to call get_redo_record, but then never call process_redo_record; in 
such a scenario, the Senzing database would simply remain as it is.

Redoer will keep attempting to process a REDO record up to `MAX_REDO_ATTEMPTS` 
times.

More info:
- "Processing REDO" -
  https://senzing.zendesk.com/hc/en-us/articles/360007475133-Processing-REDO
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.count_redo_records
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.get_redo_record
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.process_redo_record

## Exporter

- Dockerfile.exporter
- middleware/exporter.py

Exporter is an "ephemeral" container. It generates a JSONL export file and 
writes it to S3.

Exporter is designed to be memory efficient; it makes use of "multipart uploads" 
-- it will accumulate 10 MB (configurable) of data and then immediately write 
that piece of data to S3.

It has two modes (configurable via the `EXPORT_MDOE` environment variable):
- Delta
- Full

More info on S3 multipard uploads:
- https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/create_multipart_upload.html
- https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/upload_part.html
- https://boto3.amazonaws.com/v1/documentation/api/1.35.9/reference/services/s3/client/complete_multipart_upload.html
- https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/abort_multipart_upload.html

### Full mode

Full mode logic:

    Call Senzing's export_json_entity_report
    Loop:
      Keep calling Senzing's `fetch_next` as long as data is returned
      Every 10 MB, write the data to S3
    When finished, call Senzing's close_export_report

Note that what `fetch_next` returns is, essentially, a single JSON blob 
representing a particular entity.

More info:
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.export_json_entity_report
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.fetch_next
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.close_export_report

#### Export flags

Of note: the DEFAULT export flags that each Senzing facility uses: 
- Senzing SDK's `export_json_entity_report` uses:
  - `SzEngineFlags.SZ_EXPORT_DEFAULT_FLAGS`
- The `sz_export` utility uses:
  - `SzEngineFlags.SZ_ENTITY_BRIEF_DEFAULT_FLAGS | 
    SzEngineFlags.SZ_EXPORT_INCLUDE_ALL_ENTITIES`

That said, Exporter has been configured to use the SAME flags as `sz_export`, as 
this results in greatly improved performance.

More info about Senzing flags:
- https://pkg.go.dev/github.com/senzing-garage/sz-sdk-go/sz
- https://garage.senzing.com/sz-sdk-python/_modules/senzing/szengineflags.html

### Delta mode

This is a custom mode we developed. (See also the next section below.) It will 
output only data for entity IDs that have been stored in the export tracker 
table.

Performance: in delta mode, Exporter thakes about 35 minutes to export ~800,000 
entities's worth of data.

Delta mode logic:

    Retrieve a distinct list of entity IDs from the export_tracker database table
    Shift the status of these entity IDs from TODO to IN_PROGESS
    Loop:
      For each entity ID, call Senzing's get_entity_by_entity_id
      Every 10 MB, write the data to S3
    When finished, shift the status of the processed entity IDs to DONE

Flags: the same flags are used in delta mode as in full mode. (These flags are 
passed into the call to `get_entity_by_entity_id`). 

More info:
- https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.get_entity_by_entity_id

## More about delta exports

Senzing does not provide an "out of the box" solution for delta exports. Here 
are the moving parts of the delta export process:

Database table:
- A database table is created called export_tracker. It is a database table used 
  exclusively by the middleware code itself; it is not used by Senzing, if that 
  makes sense.
  - DDL code: `docker/sql/create-export-tracker-table.sql`
  - Four columns:
    - ts (timestamp) without time zone NOT NULL default current_timestamp,
    - entity_id bigint NOT NULL,
    - export_status smallint NOT NULL DEFAULT 0,
    - export_id char

Supporting `db` module:
- The `db.py` Python module contains all the functions needed to interact with 
  the export_tracker table. This is the interface to this table.

Consumer:
- When calling Senzing's `add_record`, SzEngineFlags.SZ_WITH_INFO is passed in; 
  this will result in the affected entity IDs being returned as a list.
- These entity IDs are then stored in the export_tracker table.
- Note: Consumer has no knowledge of "full" vs "delta" mode, so it always 
  stores these entity IDs as a matter of course. A future enhancement to 
  Consumer could involve turning this logic on/off via an environment 
  variable.

Redoer:
- The behavior here is very similar to Consumer. It passes in 
  `SzEngineFlags.SZ_WITH_INFO` into the call to Senzing's `process_redo_record` 
  and saves off the affected entity IDs to the export_tracker table.
- And, again, similar to Consumer, it has no knowledge of "full" vs "delta" 
  mode, so it always stores these entity IDs as a matter of course.

What about duplicates?

Over time, it will probably end up being the case that duplicate IDs exist in 
the export_tracker table. That is fine. For performance reasons, we don't spend 
time worrying about duplicates. This is handle satisfactorlly by simply using 
'DISTINCT' later on when getting the full list of entity IDs (when exporting).

What about deleted entities?

No problem. If Exporter encounters a deleted entity ID, it will just skip it.  
After all, if the entity no longer exists, then there is nothing to export at 
that point.

### Resetting the export_tracker table

It's possible that, at the end of a batch run, a full export is desired. This 
would mean that the export_tracker would have a bunch of entity IDs hanging 
around with a status of "TODO". 

To "reset" or finalize the export_tracker table, a tool has been provided that 
will change all "TODO" rows to have the status of "SKIPPED":

    docker compose run tools python3 dev/reset_export_tracker.py

## Supporting modules

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
configurable via envrionment variable.

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

    HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ./healthcheck.sh consumer.py || exit 1

## dev-scripts folder

There are various ad-hoc Python tools inside the `dev-scripts` folder. Most of 
these are addressed in the README file, but a couple are not and so they are 
addressed here.

`sz_eng`: This launches a Python REPL with the sz_engine object already 
instantiated:

    docker compose run tools python -i dev/sz_eng.py

`check_export_tracker`: This tool provides some basic checking and insight into 
the existence and contents of the export_traker table:

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

## Regarding data source names

Each record needs to have a "data source". Senzing needs to know that data 
source name before it can process records from that data source. As mentioned 
earlier, data source names are added dynamically by Consumer. However, there are 
actually several ways to load Data Source names into Senzing.

1. Via environment variable `SENZING_TOOLS_DATASOURCES`. E.g.:

        export SENZING_TOOLS_DATASOURCES="CUSTOMER REFERENCE WATCHLIST"

2. Via the `sz_configtool` utility. E.g.:

        (szcfg) addDataSource `CUSTOMERS`
        Data source successfully added!
        (szcfg) save
        Are you certain you wish to proceed and save changes? (y/n) y
        Configuration changes saved!

3. Dynamically via Python using the Senzing SDK. Take a look at the code in 
consumer.py for details.

Important note: it's also possible for Redoer to encounter a 
`SzUnknownDataSourceError` error when attempting to process a record. It's not 
clear why that is, but, nonetheless, some perfunctory code has been added to 
Redoer to "reload" the Senzing config (which contains data source names) if/when 
that happens.

More info:
- "Managing the Senzing ER configuration" - 
  https://senzing.zendesk.com/hc/en-us/articles/360010784333--Advanced-Managing-the-Senzing-ER-configuration
- https://github.com/senzing-garage/knowledge-base/blob/main/lists/environment-variables.md#senzing_tools_datasources
- https://www.senzing.com/docs/entity_specification/#how-to-add-a-data-source

# Test suite

See the section "Running Tests" in the README.

# Maintenance of external libs

The Dockerfiles generally pull in the dependent libs; they will pull in the 
proper versions at build time.

The test suite, however, uses a `requirements.txt` file. This file defines 
specific lib versions. At some point in the future, the versions defined in this 
file might need to be upgraded.
