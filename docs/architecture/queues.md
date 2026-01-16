# Queues

The primary entry point for data into the Senzing system is the ingestion queue.
This ia an AWS SQS queue that receives and holds incoming messages until they
can be processed by the consumer service. Additionally, a dead-letter queue
(DLQ) is used to capture messages that cannot be processed successfully after
multiple attempts.

## Configuration Options

The following configuration options are available in GitHub Secrts for the
ingestion queue. For more information on configuring the service, see the
[configuration documentation][configuration].

| Name                             | Description                                                                                                                               | Default         | Required |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------- |
| **AWS_REGION**                   | AWS region where the queues should be deployed.                                                                                           | `"us-west-1"`   | No       |
| **TF_VAR_DELETION_PROTECTION**   | Whether to enable deletion protection on resources. Must be disabled _and applied_ before resources can be deleted.[^deletion-protection] | `true`          | No       |
| **TF_VAR_ENVIRONMENT**           | Name of the deployment environment (e.g., `production`, `staging`, `development`).                                                        | `"development"` | No       |
| **TF_VAR_KEY_RECOVERY_PERIOD**   | Recovery period for deleted KMS encryption keys, in days. Must be between 7 and 30.                                                       | `30`            | No       |
| **TF_VAR_MESSAGE_EXPIRATION**    | Number of days before messages in the SQS queues expire. Must be between 1 and 14.                                                        | `14`            | No       |
| **TF_VAR_PROGRAM**               | Program the project belongs to. Optional, used for tagging.                                                                               | `null`          | No       |
| **TF_VAR_PROJECT**               | Project that these resources are supporting. Used to prefix resource names.                                                               | `sqs-senzing`   | No       |
| **TF_VAR_QUEUE_EMPTY_THRESHOLD** | Number of minutes that the SQS queue must have zero messages before we consider it empty.[^empty-queue]                                   | `15`            | No       |

[configuration]: ../configuration.md

[^deletion-protection]: If deletion protection is enabled, you _must_ set this
  variable to `false` _and_ deploy that change before attempting to delete any
  resources. Failure to do so will result in errors during deletion and may
  require manual intervention to recover.
[^empty-queue]: This helps prevent scaling down consumer containers before all
  messages have been sent to the queue and processed.
