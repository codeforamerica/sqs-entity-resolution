# Tools Container

The tools container is a utility container that provides various tools and
services to support the Senzing deployment. It includes the [AWS CLI][aws-cli],
[psql], and the Senzing command-line tools.

The tools container can be [launched] with a command to perform specific tasks,
or it can be kept running to support interactive sessions.

![Diagram showing a tools task with available tools and OpenTelemetry
  sidecar.][tools-diagram]

## Available Tools

The tools container includes the following tools and utilities:

- `aws`: The [AWS CLI][aws-cli] with limited permissions to interact with
  supporting sources and resources, such as S3 and SQS
- `psql`: The [PostgreSQL command-line client][psql] for interacting directly
  with the database

> [!CAUTION]
> Directly modifying the PostgreSQL database can lead to data corruption and
> is not supported by Senzing. Use caution when using `psql` to interact
> with the database.

> [!TIP]
> The Senzing command-line tools (`sz_*`) are not well documented. For more
> information on using these tools, refer to their included documentation by
> running the command with the `--help` flag (e.g., `sz_audit --help`).

- `sz_audit`: Compares output to a chosen ground truth dataset for auditing
- `sz_command`: Utility to interact with Senzing APIs
- `sz_configtool`: Utility to view and manipulate the Senzing configuration
- `sz_configupgrade`: Utility to create upgrade scripts for the Senzing
  configuration
- `sz_create_project`: Creates a new instance of a Senzing project
- `sz_dbupgrade`: Utility to create upgrade scripts for the Senzing database
- `sz_explorer`: Interactive tool for exploring Senzing data
- `sz_export`: Exports all data from Senzing
- `sz_file_loader`: Utility to load Senzing mapped JSON records and process redo
  records
- `sz_setup_config`: Load configuration into Senzing
- `sz_snapshot`: Creates a snapshot of information for the Senzing database,
  used for exploratory data analysis
- `sz_update_project`: Update an existing V3 or V4 Senzing project to the
  installed version of Senzing.

## Configuration Options

The following configuration options are available in GitHub Secrts for the
tools container. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                              | Description                                                                                                                               | Default         | Required |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                    | AWS region where the container should be launched.                                                                                        | `"us-west-1"`   | No       |
| **TF_VAR_DELETION_PROTECTION**    | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**            | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_IMAGE_TAG**              | Tag to use for tools container images. Leave empty to have a new tag generated on each run.[^image-tag]                                   | `null`          | No       |
| **TF_VAR_IMAGE_TAGS_MUTABLE**     | Whether to allow overwriting existing image tags in the tools container registry.                                                         | `false`         | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**    | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_LOG_LEVEL**              | Log level for the tools container. Must be one of: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.                                       | `INFO`          | No       |
| **TF_VAR_OTEL_VERSION**           | Version of the OpenTelemetry collector to use.[^otel-version]                                                                             | `v0.45.1`       | No       |
| **TF_VAR_PROGRAM**                | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |
| **TF_VAR_SENZING_LICENSE_BASE64** | Base64-encoded Senzing license string.[^license]                                                                                          | `null`          | Yes      |

## Instrumentation

The tools container does not include any built-in instrumentation. However, it
does include an OpenTelemetry sidecar container for consistency and future usr.
This sidecar uses the [AWS Distro for OpenTelemetry][aws-otel]. To ensure
support for air-gapped environments, the OpenTelemetry collector image is copied
from the public repository to a private ECR repository during deployment.

[aws-cli]: https://aws.amazon.com/cli/
[aws-otel]: https://aws-otel.github.io/
[configuration]: ../configuration.md
[launched]: ../operations/tools.md
[psql]: https://www.postgresql.org/docs/17/app-psql.html
[tools-diagram]: ../assets/components/tools.svg
