# Redoer Middleware

- Dockerfile.redoer
- middleware/redoer.py

Redoer, like the [consumer], is a continually-running middleware app. Its job is
to check Senzing's REDO queue and process REDO records as needed.

[From Senzing][redo]:

> There are times the Senzing engine determines additional work
> needs to be performed on an entity. In some cases it will automatically decide
> this work should be done at a different time. [...] When this happens, an
> special record is written to the SYS_EVAL_QUEUE table for future processing.
> These entries and known as REDOs or redo records".

The outcome of a REDOing a record is similar to adding a record: an entity might
be created, or deleted, or modified (i.e., records affiliated or disaffiliated
with that entity).

Redoer's logic is approximately like so (note that things are slightly
simplified here for explanatory purposes):

```pseudo
while 1:
  Call Senzing's `count_redo_records`
  If count is non-zero, call Senzing's `get_redo_record`
  If the return value is empty, try again.
  Call Senzing's `process_redo_record`
  Store affected entity IDs in the export tracker database table
```

(The export tracker database table will be discussed in a later section.)

The primary call to note above is the call to `process_redo_record`.

At this point, it might not be clear what "getting" a REDO record really means.
To be clear: the record itself is *not* removed from the database. It is
possible to call get_redo_record, but then never call process_redo_record; in
such a scenario, the Senzing database would simply remain as it is.

Redoer will keep attempting to process a REDO record up to `MAX_REDO_ATTEMPTS`
times.

More info:

- [Processing REDO][redo]
- [SzEngine.count_redo_records][count-records]
- [SzEngine.get_redo_record][get-record]
- [SzEngine.process_redo_record][process-record]

[consumer]: consumer.md
[count-records]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.count_redo_records
[get-record]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.get_redo_record
[process-record]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.process_redo_record
[redo]: https://senzing.zendesk.com/hc/en-us/articles/360007475133-Processing-REDO
