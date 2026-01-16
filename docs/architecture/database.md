# Database

The Senzing database is stored on an [AWS Aurora PostgreSQL][aurora] cluster.
Aurora allows for easy scaling of database resources, automated backups, and a
durable, high performance, cloud-native architecture.

## Configuration Options

The following configuration options are available in GitHub Secrts for the
database. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                                            | Description                                                                                                                               | Default         | Required |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                                  | AWS region where the database cluster should be deployed.                                                                                 | `"us-west-1"`   | No       |
| **TF_VAR_APPLY_DATABASE_UPDATES_IMMEDIATELY**   | Whether to apply database updates immediately. May result in downtime.                                                                    | `false`         | No       |
| **TF_VAR_DATABASE_ADMIN_USERNAME**              | Admin username for the database cluster.                                                                                                  | n/a             | Yes      |
| **TF_VAR_DATABASE_INSTANCE_COUNT**              | Number of instances in the database cluster. Must be between 0 and 16.[^db-count]                                                         | `1`             | No       |
| **TF_VAR_DATABASE_INSTANCE_TYPE**               | Instance type to use for the database instances.                                                                                          | `db.t4g.medium` | No       |
| **TF_VAR_DATABASE_PASSWORD_ROTATION_FREQUENCY** | Number of days between automatic rotation of the database password.                                                                       | `30`            | No       |
| **TF_VAR_DATABASE_SKIP_FINAL_SNAPSHOT**         | Whether to skip the final snapshot when the database cluster is deleted.[^skip-snapshot]                                                  | `false`         | No       |
| **TF_VAR_DELETION_PROTECTION**                  | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**                          | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**                  | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_POSTGRES_VERSION**                     | Version of [Aurora PostgreSQL][db-versions] to use for the database cluster.                                                              | `17`            | No       |
| **TF_VAR_PROGRAM**                              | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                              | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |


## Scaling

The database cluster can be scaled both horizontally, by increasing the number
of instances, and vertically, by changing the instance types used.

### Instance count (horizontal scaling)

You can change the number of instances in the database cluster by modifying the
`TF_VAR_DATABASE_INSTANCE_COUNT` secret in the GitHub environment used for
deployments. While you can set the instance count to a higher number, the
service will only use a single instance for writes; additional instances will be
used for read operations and failover only.

The default instance count is `1`.

### Instance type (vertical scaling)

You can change the instance type used for each instance in the database cluster
by modifying the `TF_VAR_DATABASE_INSTANCE_TYPE` secret in the GitHub
environment used for deployments. The instance type determines the CPU, memory,
and networking capacity of each database instance. You can use the [instances]
table provided by Vantage to compare instace types, in order to identify the
right instance type for your workload.

The default instance type is `db.t4g.medium`. This is the minimum instance size
supported by Aurora PostgreSQL. While this may be sufficient for development or
small workloads, production workloads will likely require larger instance types.

Senzing provides some [performance testing results][perf-testing] to help guide
instance sizing decisions. For example, if you expect to process around
100M records, you can use [these results][perf-results-100m] to estimate how
well an instance of type `r6i-24xlarge` would handle that workload.

> [!NOTE]
> Actual performance will vary based on data characteristics, ingestion
> patterns, and other factors. It's recommended to conduct your own performance
> testing with representative data and workloads to determine the optimal
> instance sizing for your specific use case.

## Authentication

The admin username and password for the database cluster are managed using AWS
Secrets Manager. The admin username is specified using the
`TF_VAR_DATABASE_ADMIN_USERNAME` secret, and the password is automatically
generated and stored in Secrets Manager. The password is rotated automatically
based on the frequency specified in the
`TF_VAR_DATABASE_PASSWORD_ROTATION_FREQUENCY` secret.

This username and password are read during deployment to configure the Senzing
services to connect to the database. The resulting JSON configuration is stored
in [AWS Parameter Store][parameter-store]. This parameter is read, and it's
value injected into the Senzing containers at runtime.

[aurora]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraPostgreSQL.html
[configuration]: ../configuration.md
[db-versions]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/AuroraPostgreSQL.Updates.html#aurorapostgresql-versions-version17
[instances]: https://instances.vantage.sh/rds?id=2f8ea167c6e686105285d86b52232ae77e7cb6d8
[parameter-store]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
[perf-results-100m]: https://github.com/senzing-garage/aws-cloudformation-performance-testing/tree/main/results/20250916-100M-provisioned-r6i-24xlarge-single-senzing-4.1
[perf-testing]: https://github.com/senzing-garage/aws-cloudformation-performance-testing/tree/main/results

[^db-count]: While the databae cluster may support up to 16 instances, only one
  of those will be used for write operations.
[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^skip-snapshot]: Skipping the final snapshot may result in data loss. This may
  be useful in non-production environments where data persistence is not
  required.
