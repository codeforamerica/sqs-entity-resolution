# Service Configuration

This configuration creates and manages a single deployment of the entity
resolution service. It creates the database, container reposirory, ECS tasks,
SQS quques, etc.

## Usage

This configuration is designed to be managed by GitHub Actions, but it can be
used locally with the appropraite permissions and input variables set.

Before deploying this configuration, make sure the [foundation] and [networking]
layers have been deployed, and the required [inputs] documented below are in
place.

## SSM parameters

In additional to the OpenTofu [inputs] documented below, this configuration
requires SSM inputs from the [foundation] and [networking] configs. This
provides a safe, secure way to store and reference values needed across
configurations, without the need to manage them manually.

Paramters are prefixed with the provided project and environment, in the format
`/${project}/${environment}/`.

### SSM inputs

The following input paramters are required from other configurations:

- `application/tag`
- `logging/bucket`
- `logging/key`
- `vpc/id`
- `vpc/private_subnets`

## Inputs

| Name                                 | Description                                                                                                                  | Type        | Default           | Required |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------------- | -------- |
| apply_database_updates_immediately   | Whether to apply database updates immediately. May result in downtime.                                                       | bool        | false             | No       |
| consumer_container_count             | Desired number of consumer containers to run.                                                                                | number      | `1`               | No       |
| consumer_container_max               | Maximum number of consumer containers to run.                                                                                | number      | `10`              | No       |
| consumer_cpu                         | Number of virtual CPUs to allocate to each consumer container.                                                               | number      | `1`               | No       |
| consumer_memory                      | Amount of memory (in MiB) to allocate to each consumer container.                                                            | number      | `4096`            | No       |
| consumer_message_threshold           | Number of messages in the SQS queue that will trigger scaling up the number of consumer containers.                          | number      | `250000`          | No       |
| database_admin_username              | Admin username for the database cluster.                                                                                     | string      | `"root"`          | No       |
| database_instance_count              | Number of instances in the database cluster.                                                                                 | number      | `1`               | No       |
| database_instance_type               | Instance type to use for the database instances.                                                                             | string      | `"db.t4g.medium"` | No       |
| database_password_rotation_frequency | Number of days between automatic rotation of the database password.                                                          | number      | `30`              | No       |
| database_skip_final_snapshot         | Whether to skip the final snapshot when the database cluster is deleted.                                                     | bool        | `false`           | No       |
| deletion_protection                  | Whether to enable deletion protection on the database cluster. Must be disabled and applied before resources can be deleted. | bool        | `true`            | No       |
| environment                          | Environment for the deployment.                                                                                              | string      | `"development"`   | No       |
| export_expiration                    | Number of days before export files expire.                                                                                   | number      | `365`             | No       |
| export_mode                          | Export mode used for the automated export. Valid options are 'delta' or 'full'.                                              | string      | `"full"`          | No       |
| image_tag                            | Tag for the docker images, will be used for all images. Leave empty to have a new tag generated on each run.                 | string      | `null`            | No       |
| image_tags_mutable                   | Whether to allow image tags to be mutable.                                                                                   | bool        | `false`           | No       |
| key_recovery_period                  | Recovery period for deleted KMS keys in days. Must be between 7 and 30.                                                      | number      | `30`              | No       |
| log_level                            | Log level for all containers.                                                                                                | string      | `"INFO"`          | No       |
| message_expiration                   | Number of days before messages in the SQS queues expire.                                                                     | number      | `14`              | No       |
| otel_version                         | Version of the OpenTelemetry collector to use.                                                                               | string      | `"v0.45.1"`       | No       |
| postgres_version                     | Version of [Aurora PostgreSQL][db-versions] to use for the database cluster.                                                 | string      | `"17"`            | No       |
| program                              | Program the application belongs to. Optional, used for tagging.                                                              | string      | `null`            | No       |
| project                              | Project that these resources are supporting.                                                                                 | string      | `"sqs-senzing"`   | No       |
| queue_empty_threshold                | Number of minutes that the SQS queue must have zero messages before we consider it empty.                                    | number      | `15`              | No       |
| redoer_container_count               | Desired number of redoer containers to run.                                                                                  | number      | `1`               | No       |
| redoer_cpu                           | Number of virtual CPUs to allocate to each redoer container.                                                                 | number      | `1`               | No       |
| redoer_memory                        | Amount of memory (in MiB) to allocate to each redoer container.                                                              | number      | `4096`            | No       |
| region                               | AWS region where resources should be deployed.                                                                               | string      | `"us-west-1""`    | No       |
| senzing_license_base64               | Base64 encoded Senzing license.                                                                                              | map(string) | `null`            | No       |
| tags                                 | Tags to apply to resources.                                                                                                  | map(string) | `{}`              | No       |

## Outputs

| Name                   | Description                                                               | Type           |
| ---------------------- | ------------------------------------------------------------------------- | -------------- |
| container_subnets      | The IDs of the subnets in which the container resources will be deployed. | `list(string)` |
| export_bucket          | The name of the S3 bucket for exports.                                    | `string`       |
| image_tag              | The tag of the container image used for the ECS tasks.                    | `string`       |
| queue_url              | The URL of the SQS queue.                                                 | `string`       |
| task_security_group_id | The ID of the security group attached to the ECS tasks.                   | `string`       |

[db-versions]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/AuroraPostgreSQL.Updates.html#aurorapostgresql-versions-version17
[foundation]: ../foundation/README.md
[inputs]: #inputs
[networking]: ../networking/README.md

