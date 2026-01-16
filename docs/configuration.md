# Configuration

Configuration of the service is done at deployment time using [input
variables][variables]. These can set using environment variables in the format
`TF_VAR_<variable_name>` or in a `terraform.tfvars` file.

> [!NOTE]
> When setting variables via environment variables, OpenTofu requires that the
> `TF_VAR_` be uppercase, while the `<variable_name>` portion is case-sensitive
> and must be therefore must lowercase.
>
> GitHub Actions, and other secrets management systems, may automatically
> uppercase variable names. Be sure to set the variable names correctly within
> your CI/CD pipelines.
>
> There is an [open feature request][names-feature] to allow case-insensitive
> environment  variable names.

## Options

The following sections describe the available configuration options for the
service. They assume you are operating the service through GitHub Actions and
references the name of the environment variable or secret to set for that
platform.

### Required

| Environment Secret/Variable         | Description                                                                                                                                                      |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AWS_REGION**                      | AWS region where resources should be deployed.                                                                                                                   |
| **AWS_ROLE_ARN**                    | ARN of the AWS IAM role for GitHub Actions to assume.                                                                                                            |
| **TF_VAR_REPO_OIDC_ARN**            | ARN of the OpenID Connect provider for the GitHub repository the workflow is running on.                                                                         |
| **TF_VAR_VPC_PRIVATE_SUBNET_CIDRS** | IP CIDRs of the private subnets that will be created for resources to be deployed, in the format: `["##.##.##.##/##", "##.##.##.##/##", ...]`                    |
| **TF_VAR_VPC_PUBLIC_SUBNET_CIDRS**  | IP CIDRs of the public subnets that will be created, in the format: `["##.##.##.##/##", "##.##.##.##/##", ...]`. Note that these subnets are not currently used. |
| **TF_VAR_VPC_CIDR**                 | IP CIDR for the VPC that will be created.                                                                                                                        |

### Optional

| Environment Secret/Variable                     | Description                                                                                                                             | Default                                  |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **TF_VAR_APPLY_DATABASE_UPDATES_IMMEDIATELY**   | Whether to apply database updates immediately. May result in downtime.                                                                  | `false`                                  |
| **TF_VAR_CONSUMER_CONTAINER_COUNT**             | Minimum number of consumer containers to keep running at all times.[^container-count]                                                   | `0`                                      |
| **TF_VAR_CONSUMER_CONTAINER_MAX**               | Maximum number of consumer containers to run when scaling. Must be between 1 and 20.                                                    | `10`                                     |
| **TF_VAR_CONSUMER_CPU**                         | Number of virtual CPUs to allocate to each consumer container.                                                                          | `1`                                      |
| **TF_VAR_CONSUMER_MEMORY**                      | Amount of memory (in MiB) to allocate to each consumer container.                                                                       | `4096`                                   |
| **TF_VAR_CONSUMER_MESSAGE_THRESHOLD**           | Number of messages in the SQS queue that will trigger scaling up the number of consumer containers.                                     | `250000`                                 |
| **TF_VAR_DATABASE_ADMIN_USERNAME**              | Admin username for the database cluster.                                                                                                | `root`                                   |
| **TF_VAR_DATABASE_INSTANCE_COUNT**              | Number of instances in the database cluster. Must be between 0 and 16.[^db-count]                                                       | `1`                                      |
| **TF_VAR_DATABASE_INSTANCE_TYPE**               | Instance type to use for the database instances.                                                                                        | `db.t4g.medium`                          |
| **TF_VAR_DATABASE_PASSWORD_ROTATION_FREQUENCY** | Number of days between automatic rotation of the database password.                                                                     | `30`                                     |
| **TF_VAR_DATABASE_SKIP_FINAL_SNAPSHOT**         | Whether to skip the final snapshot when the database cluster is deleted.[^skip-snapshot]                                                | `false`                                  |
| **TF_VAR_DELETION_PROTECTION**                  | Whether to enable deletion protection on resources. Must be disabled and applied before resources can be deleted.[^deletion-protection] | `true`                                   |
| **TF_VAR_DEPLOYMENT_ENVIRONMENTS**              | List of additional deployment environments to create permissions for. Useful for deploying multiple service environments.               | `[]`                                     |
| **TF_VAR_ENVIRONMENT**                          | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                      | `development`                            |
| **TF_VAR_EXPORT_EXPIRATION**                    | Number of days before export files expire and are deleted.                                                                              | `365`                                    |
| **TF_VAR_EXPORT_MODE**                          | Export mode used for the automated export. Valid options are 'delta' or 'full'.                                                         | `full`                                   |
| **TF_VAR_IMAGE_TAG**                            | Tag to use for all container images. Leave empty to have a new tag generated on each run.[^image-tag]                                   | `null`                                   |
| **TF_VAR_IMAGE_TAGS_MUTABLE**                   | Whether to allow overwriting existing image tags in the container registry.                                                             | `false`                                  |
| **TF_VAR_KEY_RECOVERY_PERIOD**                  | Recovery period for deleted KMS keys, in days. Must be between 7 and 30.                                                                | `30`                                     |
| **TF_VAR_LOG_LEVEL**                            | Log level for all containers. Must be one of: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.                                          | `INFO`                                   |
| **TF_VAR_MESSAGE_EXPIRATION**                   | Number of days before messages in the SQS queues expire. Must be between 1 and 14.                                                      | `14`                                     |
| **TF_VAR_OTEL_VERSION**                         | Version of the OpenTelemetry collector to use.[^otel-version]                                                                           | `v0.45.1`                                |
| **TF_VAR_POSTGRES_VERSION**                     | Version of [Aurora PostgreSQL][db-versions] to use for the database cluster.                                                            | `17`                                     |
| **TF_VAR_PROGRAM**                              | Program the project belongs to. Optional, used for tagging.                                                                             | `null`                                   |
| **TF_VAR_PROJECT**                              | Project that these resources are supporting. Used to prefix resource names.                                                             | `sqs-senzing`                            |
| **TF_VAR_QUEUE_EMPTY_THRESHOLD**                | Number of minutes that the SQS queue must have zero messages before we consider it empty.[^empty-queue]                                 | `15`                                     |
| **TF_VAR_REDOER_CONTAINER_COUNT**               | Minimum number of redoer containers to keep running at all times.[^container-count]                                                     | `0`                                      |
| **TF_VAR_REDOER_CPU**                           | Number of virtual CPUs to allocate to each redoer container.                                                                            | `1`                                      |
| **TF_VAR_REDOER_MEMORY**                        | Amount of memory (in MiB) to allocate to each redoer container.                                                                         | `4096`                                   |
| **TF_VAR_REPOSITORY**                           | GitHub repository that the workflow is running on, in the format 'owner/repo'.                                                          | `"codeforamerica/sqs-entity-resolution"` |
| **TF_VAR_SENZING_LICENSE_BASE64**               | Base64-encoded Senzing license string.[^license]                                                                                        | `null`                                   |


[db-versions]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/AuroraPostgreSQL.Updates.html#aurorapostgresql-versions-version17
[names-feature]: https://github.com/opentofu/opentofu/issues/3657
[otel-releases]: https://github.com/aws-observability/aws-otel-collector/releases
[variables]: https://opentofu.org/docs/language/values/variables/

[^container-count]: Setting the redoer or consumer container count to `0` (the
  default) allows the service to scale down to zero containers when there is no
  work to be done.
[^db-count]: While the databae cluster may support up to 16 instances, only one
  of those will be used for write operations.
[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^empty-queue]: This helps prevent scaling down consumer containers before all
  messages have been sent to the queue and processed.
[^image-tag]: On GitHub Actions, the default image tag is generated using the
  current commit SHA. On other platforms, a timestamp-based tag is used.
[^license]: This value is sensitive and is not saved into the OpenTofu state
  file. If no license is provided, the service will operate in evaluation mode,
  which will only process a limited number of records.
[^otel-version]: For security and stability reasons, it is recommended to use a
  specific version of the OpenTelemetry collector rather than `latest`. Releases
  can be found om the [AWS Distro for OpenTelemetry Collector
  repository][otel-releases].
[^skip-snapshot]: Skipping the final snapshot may result in data loss. This may
  be useful in non-production environments where data persistence is not
  required.
