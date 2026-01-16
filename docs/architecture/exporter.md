# Exporter

The exporter is the primary means of extracting data from the Senzing system
after it has been ingested and processed. It can be run in either "full" or
"delta" mode, depending on your needs.

The "delta" mode is designed to export only the entities that have been
created or modified since the last export. This can significantly reduce the
amount of data being exported, resulting in a small file size. However, this
comes at the cost of a longer execution time.

In "full" mode, the exporter generates a complete export of all entities in the
Senzing system. Despite the overall number of entities being potentially larger
than the delta export, the full export execution time is often shorter. It will
produce a larger file size.

![Diagram showing an exporter task with the exporter container and OpenTelemtry
  sidecar.][exporter-diagram]

## Configuration Options

The following configuration options are available in GitHub Secrts for the
exporter. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                              | Description                                                                                                                               | Default         | Required |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                    | AWS region where the exporter should be launched.                                                                                         | `"us-west-1"`   | No       |
| **TF_VAR_DELETION_PROTECTION**    | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**            | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_EXPORT_EXPIRATION**      | Number of days before export files expire and are deleted.                                                                                | `365`           | No       |
| **TF_VAR_EXPORT_MODE**            | Export mode used for the automated export. Valid options are 'delta' or 'full'.                                                           | `"full"`        | No       |
| **TF_VAR_IMAGE_TAG**              | Tag to use for exporter container images. Leave empty to have a new tag generated on each run.[^image-tag]                                | `null`          | No       |
| **TF_VAR_IMAGE_TAGS_MUTABLE**     | Whether to allow overwriting existing image tags in the exporter container registry.                                                      | `false`         | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**    | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_LOG_LEVEL**              | Log level for the exporter container. Must be one of: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.                                    | `"INFO"`        | No       |
| **TF_VAR_OTEL_VERSION**           | Version of the OpenTelemetry collector to use.[^otel-version]                                                                             | `"v0.45.1"`     | No       |
| **TF_VAR_PROGRAM**                | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                | Project that these resources are supporting. Used to prefix resource names.                                                               | `"sqs-senzing"` | No       |
| **TF_VAR_QUEUE_EMPTY_THRESHOLD**  | Number of minutes that the SQS queue must have zero messages before we consider it empty.[^empty-queue]                                   | `15`            | No       |
| **TF_VAR_SENZING_LICENSE_BASE64** | Base64-encoded Senzing license string.[^license]                                                                                          | `null`          | Yes      |

## Instrumentation

The exporter includes built-in instrumentation using OpenTelemetry. A sidecar
container runs alongside the main exporter container, collecting metrics, and
exporting them to Amazon CloudWatch. This sidecar uses the [AWS Distro for
OpenTelemetry][aws-otel]. To ensure support for air-gapped environments, the
OpenTelemetry collector image is copied from the public repository to a private
ECR repository during deployment.

Metrics emitted by the exporter include the following tags:

* `environment`: The deployment environment (e.g., `production`, `staging`,
  `development`)
* `service`: The name of the service emitting the metric; in this case,
  `exporter`
* `status`: The status of the operation: `success` or `failure`

The following metrics are emitted by the exporter:

| Metric                     | Type      | Tags                               | Description                                   |
| -------------------------- | --------- | ---------------------------------- | --------------------------------------------- |
| `exporter.export.count`    | counter   | `environment`, `service`, `status` | Counter incremented with each export request. |
| `exporter.export.duration` | histogram | `environment`, `service`, `status` | Export duration.                              |

## Launching

The exporter is launched automatically after the ingestion queue has been
emptied. Once the queue has been empty for a number of minutes, specified by the
`TF_VAR_QUEUE_EMPTY_THRESHOLD` secret, the exporter task is started. This helps
ensure that all data has been processed, and prevents premature exports when
there is a short delay between messages. The automated export uses the mode
specified in the `TF_VAR_EXPORT_MODE` secret.

The exporter can also be launched manually using the [Trigger Senzing export to
S3][export-workflow] GitHub Actions workflow.

## Export File

The export file is stored in the designated S3 bucket as a JSONL file. Each file
contains one JSON object per line, representing a single entity, it's records,
related entities, and match information.

A simple example of an exported entity is shown below:

```json
{
  "RESOLVED_ENTITY": {
    "ENTITY_ID": 51,
    "RECORDS": [
      {
        "DATA_SOURCE": "KUNGFUFIGHTERS",
        "RECORD_ID": "1234567890",
        "INTERNAL_ID": 51,
        "MATCH_KEY": "",
        "MATCH_LEVEL_CODE": "",
        "ERRULE_CODE": ""}
    ]
  },
  "RELATED_ENTITIES": [
    {
      "ENTITY_ID":91,
      "MATCH_LEVEL_CODE": "POSSIBLY_RELATED",
      "MATCH_KEY": "+ADDRESS+PHONE-NPI_NUMBER",
      "ERRULE_CODE": "MFF",
      "IS_DISCLOSED": 0,
      "IS_AMBIGUOUS": 0
    }
  ]
}
```

## Middleware

The task launched by the exporter runs the [exporter middleware][middleware].
This is the application layer that's responsible for generating the export file,
either in full or delta mode, and storing it in the designated S3 bucket.

[aws-otel]: https://aws-otel.github.io/
[configuration]: ../configuration.md
[export-workflow]: ../operations/export.md
[exporter-diagram]: ../assets/components/exporter.svg
[middleware]: ../middleware/exporter.md
[otel-releases]: https://github.com/aws-observability/aws-otel-collector/releases

[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^empty-queue]: This helps prevent scaling down consumer containers before all
  messages have been sent to the queue and processed.
[^image-tag]: On GitHub Actions, the default image tag is generated using the
  current commit SHA. On other platforms, a timestamp-based tag is used.
[^license]: This value is sensitive and is not saved into the Terraform state
  file. If no license is provided, the service will operate in evaluation mode,
  which will only process a limited number of records.
[^otel-version]: For security and stability reasons, it is recommended to use a
  specific version of the OpenTelemetry collector rather than `latest`. Releases
  can be found om the [AWS Distro for OpenTelemetry Collector
  repository][otel-releases].
