# Consumer Middleware

- Dockerfile.consumer
- middleware/consumer.py

The consumer's job is to poll the SQS ingestion queue for a new message,
retrieve that message (which contains a record), and add the record to Senzing.

The basic loop is:

```pseudo
while 1:
  Get message from SQS queue (blocks up to 20 seconds before retrying)
  Call Senzing's `add_record`
  Store affected entity IDs in the export tracker database table
  Delete message from queue
```

(The export tracker database table will be discussed in a later section.)

There is additional logic to handle errors/exceptions, including:

- timeouts -- configurable via the `SZ_CALL_TIMEOUT_SECONDS` environment
  variable.
- Senzing errors
- general errors

In the case of an error, the message is *not* deleted from the SQS queue.

More info:

- [SZEngine.add_record][add-record]

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

[add-record]: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.add_record
