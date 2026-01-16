# Exporter Middleware

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

More info on S3 multipart uploads:

- [Uploading and copying objects using multipart upload in Amazon
  S3][mp-uploads]
- [Amazon S3 API Reference: UploadPart][uploadpart]
- [Amazon S3 multipart upload limits][upload-limits]
- [S3.Client.create_multipart_upload][boto-create-upload]
- [S3.Client.upload_part][boto-upload-part]
- [S3.Client.complete_multipart_upload][boto-complete-upload]
- [S3.Client.abort_multipart_upload][boto-abort-upload]

### Full mode

Full mode logic:

```pseudo
Call Senzing's export_json_entity_report
Loop:
  Keep calling Senzing's `fetch_next` as long as data is returned
  Every 10 MB, write the data to S3
When finished, call Senzing's close_export_report
```

Note that what `fetch_next` returns is, essentially, a single JSON blob
representing a particular entity.

More info:

- [SzEngine.export_json_entity_report][sz-export-report]
- [SzEngine.fetch_next][sz-fetch-next]
- [SzEngine.close_export_report][sz-close-report]

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

- [Senzing SDK flags][sz-flags] (Go SDK)
- [Source code for senzing.szengineflags][sz-flags-source] (Python SDK)

### Delta mode

This is a custom mode we developed. (See also the next section below.) It will
output only data for entity IDs that have been stored in the export tracker
table.

Performance: in delta mode, Exporter takes about 35 minutes to export ~800,000
entity's worth of data.

Delta mode logic:

```pseudo
Retrieve a distinct list of entity IDs from the export_tracker database table
Shift the status of these entity IDs from TODO to IN_PROGESS
Loop:
  For each entity ID, call Senzing's get_entity_by_entity_id
  Every 10 MB, write the data to S3
When finished, shift the status of the processed entity IDs to DONE
```

Flags: the same flags are used in delta mode as in full mode. (These flags are
passed into the call to `get_entity_by_entity_id`).

More info:

- [SzEngine.get_entity_by_entity_id][sz-get-entity]

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
time worrying about duplicates. This is handle satisfactorily by simply using
'DISTINCT' later on when getting the full list of entity IDs (when exporting).

What about deleted entities?

No problem. If Exporter encounters a deleted entity ID, it will just skip it.
After all, if the entity no longer exists, then there is nothing to export at
that point.

### Resetting the export_tracker table

It's possible that, at the end of a batch run, a full export is desired. This
would mean that the export_tracker would have a bunch of entity IDs hanging
around with a status of "TODO".

> [!NOTE]
> The Senzing repository and the `export_tracker` table are separate. Purging
> the Senzing repository will not affect the `export_tracker` table (and vice
> versa).

To "reset" or finalize the export_tracker table, a tool has been provided that
will change all "TODO" rows to have the status of "SKIPPED":

```bash
docker compose run tools python3 dev/reset_export_tracker.py
```

[boto-abort-upload]: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/abort_multipart_upload.html
[boto-complete-upload]: https://boto3.amazonaws.com/v1/documentation/api/1.35.9/reference/services/s3/client/complete_multipart_upload.html
[boto-create-upload]: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/create_multipart_upload.html
[boto-upload-part]: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/upload_part.html
[mp-uploads]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html
[sz-close-report]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.close_export_report
[sz-export-report]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.export_json_entity_report
[sz-fetch-next]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.fetch_next
[sz-flags]: https://pkg.go.dev/github.com/senzing-garage/sz-sdk-go/sz
[sz-flags-source]: https://garage.senzing.com/sz-sdk-python/_modules/senzing/szengineflags.html
[sz-get-entity]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.get_entity_by_entity_id
[upload-limits]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html
[uploadpart]: https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html
