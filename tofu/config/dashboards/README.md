# Dashboards Configuration

This configuration creates and manages a set of CloudWatch dashbaords to monitor
the service.

## Usage

This configuration is designed to be managed by GitHub Actions, but it can be
used locally with the appropraite permissions and input variables set.

Before deploying this configuration, make sure the [service] layer has been
deployed, and the required [inputs] documented below are in place.

## Inputs

| Name        | Description                                                     | Type   | Default         | Required |
| ----------- | --------------------------------------------------------------- | ------ | --------------- | -------- |
| environment | Environment for the deployment.                                 | string | `"development"` | No       |
| program     | Program the application belongs to. Optional, used for tagging. | string | `null`          | No       |
| project     | Project that these resources are supporting.                    | string | `"sqs-senzing"` | No       |
| region      | AWS region where resources are deployed.                        | string | `"us-west-1""`  | No       |

[inputs]: #inputs
[service]: ../service/README.md

