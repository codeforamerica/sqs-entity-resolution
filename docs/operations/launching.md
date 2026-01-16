# Launching a New Environment

The system is built and deployed using [Terraform], which automates the
provisioning of all necessary resources into AWS. Using Terraform allows the
system to be deployed across different projects and environments with minimal
effort.

This document outlines the steps required to launch a new environment using
the provided Terraform configurations.

## Prerequisites

Before you can launch a new environment, ensure you have completed the following
prerequisites.

### AWS Account

The Terraform configuration uses an [S3 backend][backend], with DynamoDB state
locking, to store the state of the deployed resources. Additionally, an [OIDC
connection][oidc] between GitHub and AWS is required. GitHub will use this
connection to assume a role that must have sufficient privleges to deploy and
manage the system.

You will need access to an AWS account with sufficient permissions to create and
manage the required resources. To aid in this process, you may use the provided
[Foundation] and [Networking] configurations to create the necessary backend
infrastructure. These configs creates the necessary resources to manage the
Terraform state, as well as the IAM role and policies required for GitHub
Actions to deploy the system.

### GitHub Environment

Configuration is managed through GitHub Secrets. These secrets are scroped to a
specific GitHub Environment, which corresponds to the environment you are
launching/deploying into.

1. [Create a new GitHub Environment][create-environment] for the environment you
   wish to launch
1. Follow the [configuration guide][configuration] to set the required secrets,
   along with any optional overrides, for the new environment

    > [!TIP]
    > Make sur your combination of project and environment names is unique
    > across all your deployments to avoid naming conflicts.

1. Ensure you've set the `AWS_ROLE_ARN`, `TF_BACKEND_BUCKET`, and
   `TF_BACKEND_DYNAMODB_TABLE` secrets to the outputs of the CloudFormation
   stack you deployed in the AWS section above

## Launching the Environment

With the prerequisites complete, you can now launch the new environment. This
is done using the same [deployment process][deploying] used for updating
existing environments.

### Initializing the database

Beore you can begin to use your new environment, you must initialize the Senzing
database. This process sets up the schemas for Senzing and the delta export
tracker.

Use the [Run tools container command][tools-workflow] with the
"Initialize Database" command to set up the database schemas.

## Destroying the Environment

> [!CAUTION]
> Destroying an environment will permanently delete all resources associated
> with that environment, including any data stored in databases or storage
> services. Ensure you have backed up any important data before proceeding.
>
> This action cannot be undone.

To destroy an existing environment, including all associated resources, you can
use the "Destroy infrastructure" workflow in GitHub Actions. This workflow will
tear down all resources created during the deployment of the environment.

_Before you can destroy the environment_, you must first disable deletion
protection. Set the `TF_VAR_DELETION_PROTECTION` secret to `false` in the GitHub
Environment associated with the environment you wish to destroy, and run the
deployment workflow to apply this change.

> [!WARNING]
> Failing to disable deletion protection before destroying the environment will
> result in errors during the destruction process, and may require manual
> intervention to recover.

To help prevent accidental destruction of environments, the workflow includes a
confirmation checkbox. You must check this confirmation box before the workflow
will proceed with destroying the environment.

[backend]: https://developer.hashicorp.com/terraform/language/backend/s3
[configuration]: ../configuration.md
[create-environment]: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments#creating-an-environment
[deploying]: deploying.md
[foundation]: ../architecture/infrastrucure/foundation.md
[networking]: ../architecture/infrastrucure/networking.md
[oidc]: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
[terraform]: https://www.terraform.io/
[tools-workflow]: ../operations/tools.md
