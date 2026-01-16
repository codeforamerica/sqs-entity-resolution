# Networking Configuration

This configuration creates and manages a networking layer, will appropriate
configuration and logging to operate the service. Multiple instances of the
service can be run within a single netowrking layer[^multiple-services].

## Usage

This configuration is designed to be managed by GitHub Actions, but it can be
used locally with the appropraite permissions and input variables set.

Before deploying this configuration, make sure the [foundation] layer has been
deployed, and the required [inputs] documented below are in place.

## SSM parameters

In additional to the OpenTofu [inputs] and [outputs] documented below, this
configuration requires SSM inputs from the [foundation] config, and cretes SSM
paramters that can be consumed by others. This provides a safe, secure way to
store and reference values needed across configurations, without the need to
manage them manually.

Paramters are prefixed with the provided project and environment, in the format
`/${project}/${environment}/`.

### SSM inputs

The following input paramters are required from other configurations:

- `application/tag`
- `logging/key`

### SSM outputs

The following output parameters are created by this configuration:

- `vpc/id`
- `vpc/private_subnets`
- `vpc/public_subnets`

## Inputs

| Name                     | Description                                                 | Type         | Default         | Required |
| ------------------------ | ----------------------------------------------------------- | ------------ | --------------- | -------- |
| vpc_cidr                 | CIDR block for the VPC.                                     | string       | n/a             | Yes      |
| vpc_private_subnet_cidrs | List of CIDR blocks for private subnets.                    | list(string) | n/a             | Yes      |
| vpc_public_subnet_cidrs  | List of CIDR blocks for public subnets.                     | list(string) | n/a             | Yes      |
| environment              | Environment for the deployment.                             | string       | `"development"` | No       |
| program                  | Program the project belongs to. Optional, used for tagging. | string       | `null`          | No       |
| project                  | Project that these resources are supporting.                | string       | `"sqs-senzing"` | No       |
| region                   | AWS region where resources should be deployed.              | string       | `"us-west-1"`   | No       |
| tags                     | Tags to apply to resources.                                 | map(string)  | `{}`            | No       |


## Outputs

| Name            | Description                     | Type           |
| --------------- | ------------------------------- | -------------- |
| private_subnets | The IDs of the private subnets. | `list(string)` |
| public_subnets  | The IDs of the public subnets.  | `list(string)` |
| vpc_id          | The ID of the VPC.              | `string`       |

[foundation]: ../foundation/README.md
[inputs]: #inputs
[outputs]: #outputs

[^multiple-services]: While running multiple services within the same networking
  layer can be useful in development and testing environments, be cautious of
  network isolation requiremetns in production.