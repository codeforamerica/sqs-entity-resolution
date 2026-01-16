# Foundation Configuration

This configuration is the base layer for all infrastrucure. It creates
resources necessary to deploy and manage the OpenTofu configurations.

## Usage

The initial deployment of this configuration must be performed locally, or in a
stable environment with the necessary privledges. This is due to the creation of
the remote state backend and permissions required to deploy from GitHub Actions.

## SSM parameters

In additional to the OpenTofu [outputs] documented below, this configuration
creates SSM paramters that can be consumed by other configuration layers. This
provides a safe, secure way to store and reference values needed across
configurations, without the need to manage them manually.

Paramters are prefixed with the provided project and environment, in the format
`/${project}/${environment}/`.

### SSM outputs

The following output parameters are created by this configuration:

- `application/tag`
- `logging/bucket`
- `logging/key`

## Inputs

| Name                    | Description                                                                                                               | Type         | Default                                  | Required |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------ | ---------------------------------------- | -------- |
| repo_oidc_arn           | ARN of the OpenID Connect provider for the GitHub repository.                                                             | string       | n/a                                      | Yes      |
| deployment_environments | List of additional deployment environments to create permissions for. Useful for deploying multiple service environments. | list(string) | `[]`                                     | No       |
| environment             | Environment for the deployment.                                                                                           | string       | `"development"`                          | No       |
| key_recovery_period     | Recovery period for deleted KMS keys in days. Must be between 7 and 30.                                                   | number       | `30`                                     | No       |
| program                 | Program the project belongs to. Optional, used for tagging.                                                               | string       | `null`                                   | No       |
| project                 | Project that these resources are supporting.                                                                              | string       | `"sqs-senzing"`                          | No       |
| region                  | AWS region where resources should be deployed.                                                                            | string       | `"us-west-1"`                            | No       |
| repository              | GitHub repository in the format 'owner/repo'.                                                                             | string       | `"codeforamerica/sqs-entity-resolution"` | No       |


## Outputs

| Name                         | Description                                                         | Type           |
| ---------------------------- | ------------------------------------------------------------------- | -------------- |
| application_arn              | ARN of the Service Catalog App Registry application.                | `string`       |
| deployment_role_arn          | The ARN of the deployment role for system components.               | `string`       |
| environment_deployment_roles | ARN of any deployment roles for additional deployment environments. | `list(string)` |
| logging_bucket               | The name of the S3 bucket for logging.                              | `string`       |
| logging_key_arn              | The ARN of the KMS key for logging.                                 | `string`       |
| state_bucket                 | The name of the S3 bucket for infrastructure state files.           | `string`       |

[outputs]: #outputs