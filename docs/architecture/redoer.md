# Redoer Service

The redoer monitors the internal Senzing redo queue for [REDO] messages and
processes then. As new messages are processed, Senzing is continuously comparing
them against existing data, which may result in updates to existing entities and
relationships.

Some of these updates are executed immediately, while others are deferred for
later processing. Deferred updates are added to the redo queue as REDO messages.
The redoer continuously processes these messages to ensure that the updates are
applied before the data is exported.

For more information on REDO processing, see the [Senzing documentation][redo].

![A diagram showing a redoer task with the redoer container and OpenTelemtry
  sidecar.][redoer-diagram]

## Configuration Options

The following configuration options are available in GitHub Secrts for the
redoer service. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                              | Description                                                                                                                               | Default         | Required |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                    | AWS region where the redoer should be deployed.                                                                                           | `"us-west-1"`   | No       |
| **TF_VAR_DELETION_PROTECTION**    | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**            | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_IMAGE_TAG**              | Tag to use for redoer container images. Leave empty to have a new tag generated on each run.[^image-tag]                                  | `null`          | No       |
| **TF_VAR_IMAGE_TAGS_MUTABLE**     | Whether to allow overwriting existing image tags in the redoer container registry.                                                        | `false`         | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**    | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_LOG_LEVEL**              | Log level for the redoer containers. Must be one of: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.                                     | `INFO`          | No       |
| **TF_VAR_OTEL_VERSION**           | Version of the OpenTelemetry collector to use.[^otel-version]                                                                             | `v0.45.1`       | No       |
| **TF_VAR_PROGRAM**                | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |
| **TF_VAR_REDOER_CONTAINER_COUNT** | Minimum number of redoer containers to keep running at all times.[^container-count]                                                       | `0`             | No       |
| **TF_VAR_REDOER_CPU**             | Number of virtual CPUs to allocate to each redoer container.                                                                              | `1`             | No       |
| **TF_VAR_REDOER_MEMORY**          | Amount of memory (in MiB) to allocate to each redoer container.                                                                           | `4096`          | No       |
| **TF_VAR_SENZING_LICENSE_BASE64** | Base64-encoded Senzing license string.[^license]                                                                                          | `null`          | Yes      |

## Instrumentation

The redoer service includes built-in instrumentation using OpenTelemetry. A
sidecar container runs alongside the main redoer container, collecting metrics,
and exporting them to Amazon CloudWatch. This sidecar uses the [AWS Distro for
OpenTelemetry][aws-otel]. To ensure support for air-gapped environments, the
OpenTelemetry collector image is copied from the public repository to a private
ECR repository during deployment.

Metrics emitted by the service include the following tags:

* `environment`: The deployment environment (e.g., `production`, `staging`,
  `development`)
* `service`: The name of the service emitting the metric; in this case, `redoer`
* `status`: The status of the operation: `success` or `failure`

The following metrics are emitted by the redoer service:

| Metric                     | Type      | Tags                               | Description                                                    |
| -------------------------- | --------- | ---------------------------------- | -------------------------------------------------------------- |
| `redoer.messages.count`    | counter   | `environment`, `service`, `status` | Counter incremented with each message processed by the redoer. |
| `redoer.messages.duration` | histogram | `environment`, `service`, `status` | Message processing duration for the redoer.                    |
| `redoer.queue.count`       | guage     | `environment`, `service`           | Current number of messages in the redoer queue.                |

## Middleware

The tasks launched by the redoer service run the [redoer
middleware][middleware]. The redoer middleware is the application layer that's
responsible for reading REDO messages from the redo queue and processing them.

[aws-otel]: https://aws-otel.github.io/
[configuration]: ../configuration.md
[middleware]: ../middleware/redoer.md
[otel-releases]: https://github.com/aws-observability/aws-otel-collector/releases
[redo]: https://senzing.zendesk.com/hc/en-us/articles/360007475133-Processing-REDO
[redoer-diagram]: ../assets/components/redoer.svg

[^container-count]: Setting the container count to `0` (the default) allows the
  service to scale down to zero containers when there is no work to be done.
[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^image-tag]: On GitHub Actions, the default image tag is generated using the
  current commit SHA. On other platforms, a timestamp-based tag is used.
[^license]: This value is sensitive and is not saved into the Terraform state
  file. If no license is provided, the service will operate in evaluation mode,
  which will only process a limited number of records.
[^otel-version]: For security and stability reasons, it is recommended to use a
  specific version of the OpenTelemetry collector rather than `latest`. Releases
  can be found om the [AWS Distro for OpenTelemetry Collector
  repository][otel-releases].
