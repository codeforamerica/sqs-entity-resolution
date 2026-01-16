# Consumer Service

The consumer is responsible for retrieving messages from the ingestion queue,
and processing them with the Senzing SDK. The consumer is designed to scale
horizontally to handle varying workloads, and can be configured to run multiple
instances concurrently.

Each consumer instance operates independently, allowing for efficient processing
of messages in parallel. This results in out-of-order processing of messages,
which is acceptable for entity resolution tasks. Additionally, it is possible
for messages to be retrieved more than once. Fortunately, as the data in the
message is idempotent, Senzing can handle the duplicates without any issues.

Each entity updated as a result of message processing will be added to a table
in the database for tracking changes. This table is then used by the exporter
to determine which entities need to be included in the next delta export.

![A diagram showing a consumer task with the consumer container and OpenTelemtry
  sidecar.][consumer-diagram]

## Configuration Options

The following configuration options are available in GitHub Secrts for the
consumer service. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                                  | Description                                                                                                                               | Default         | Required |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                        | AWS region where the consumer should be deployed.                                                                                         | `"us-west-1"`   | No       |
| **TF_VAR_CONSUMER_CONTAINER_COUNT**   | Minimum number of consumer containers to keep running at all times.[^container-count]                                                     | `0`             | No       |
| **TF_VAR_CONSUMER_CONTAINER_MAX**     | Maximum number of consumer containers to run when scaling. Must be between 1 and 20.                                                      | `10`            | No       |
| **TF_VAR_CONSUMER_CPU**               | Number of virtual CPUs to allocate to each consumer container.                                                                            | `1`             | No       |
| **TF_VAR_CONSUMER_MEMORY**            | Amount of memory (in MiB) to allocate to each consumer container.                                                                         | `4096`          | No       |
| **TF_VAR_CONSUMER_MESSAGE_THRESHOLD** | Number of messages in the SQS queue that will trigger scaling up the number of consumer containers.                                       | `250000`        | No       |
| **TF_VAR_DELETION_PROTECTION**        | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**                | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_IMAGE_TAG**                  | Tag to use for consumer container images. Leave empty to have a new tag generated on each run.[^image-tag]                                | `null`          | No       |
| **TF_VAR_IMAGE_TAGS_MUTABLE**         | Whether to allow overwriting existing image tags in the consumer container registry.                                                      | `false`         | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**        | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_LOG_LEVEL**                  | Log level for the consumer containers. Must be one of: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.                                   | `INFO`          | No       |
| **TF_VAR_OTEL_VERSION**               | Version of the OpenTelemetry collector to use.[^otel-version]                                                                             | `v0.45.1`       | No       |
| **TF_VAR_PROGRAM**                    | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                    | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |
| **TF_VAR_SENZING_LICENSE_BASE64**     | Base64-encoded Senzing license string.[^license]                                                                                          | `null`          | Yes      |

## Instrumentation

The consumer service includes built-in instrumentation using OpenTelemetry. A
sidecar container runs alongside the main consumer container, collecting
metrics, and exporting them to Amazon CloudWatch. This sidecar uses the [AWS
Distro for OpenTelemetry][aws-otel]. To ensure support for air-gapped
environments, the OpenTelemetry collector image is copied from the public
repository to a private ECR repository during deployment.

Metrics emitted by the service include the following tags:

* `environment`: The deployment environment (e.g., `production`, `staging`,
  `development`)
* `service`: The name of the service emitting the metric; in this case,
  `consumer`
* `status`: The status of the operation: `success` or `failure`

The following metrics are emitted by the consumer service:

| Metric                       | Type      | Tags                               | Description                                      |
| ---------------------------- | --------- | ---------------------------------- | ------------------------------------------------ |
| `consumer.messages.count`    | counter   | `environment`, `service`, `status` | Counter incremented with each message processed. |
| `consumer.messages.duration` | histogram | `environment`, `service`, `status` | Message processing duration.                     |

## Middleware

The tasks launched by the consumer service run the [consumer
middleware][middleware]. The middleware is the application layer that's
responsible for reading messages from the queue and processing them.

[aws-otel]: https://aws-otel.github.io/
[configuration]: ../configuration.md
[consumer-diagram]: ../assets/components/consumer.svg
[middleware]: ../middleware/consumer.md
[otel-releases]: https://github.com/aws-observability/aws-otel-collector/releases

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
