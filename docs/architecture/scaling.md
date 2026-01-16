# Scaling

Scaling is managed through two smaller components. The first, is the EventBridge
rule that monitors the SQS queue size and triggers scaling actions. The second,
is the set of scaling policies that define how the ECS services should scale
based on the queue size.

![A diagram showing EventBridge and AWS Scaling Policies and their connections
  to the rest of the service.][scaling-diagram]

## Configuration Options

The following configuration options are available in GitHub Secrts for the
service's scaling. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                                  | Description                                                                                                                               | Default         | Required |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                        | AWS region where the redoer should be deployed.                                                                                           | `"us-west-1"`   | No       |
| **TF_VAR_CONSUMER_CONTAINER_COUNT**   | Minimum number of consumer containers to keep running at all times.[^container-count]                                                     | `0`             | No       |
| **TF_VAR_CONSUMER_CONTAINER_MAX**     | Maximum number of consumer containers to run when scaling. Must be between 1 and 20.                                                      | `10`            | No       |
| **TF_VAR_CONSUMER_MESSAGE_THRESHOLD** | Number of messages in the SQS queue that will trigger scaling up the number of consumer containers.                                       | `250000`        | No       |
| **TF_VAR_DELETION_PROTECTION**        | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**                | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_PROGRAM**                    | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**                    | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |
| **TF_VAR_QUEUE_EMPTY_THRESHOLD**      | Number of minutes that the SQS queue must have zero messages before we consider it empty.[^empty-queue]                                   | `15`            | No       |
| **TF_VAR_REDOER_CONTAINER_COUNT**     | Minimum number of redoer containers to keep running at all times.[^container-count]                                                       | `0`             | No       |

[configuration]: ../configuration.md
[scaling-diagram]: ../assets/components/scaling.svg

[^container-count]: Setting the container count to `0` (the default) allows the
  service to scale down to zero containers when there is no work to be done.
[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^empty-queue]: This helps prevent scaling down consumer containers before all
  messages have been sent to the queue and processed.
