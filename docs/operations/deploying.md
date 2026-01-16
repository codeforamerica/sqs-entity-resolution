# Deploying

The service is managed by Terraform and deployed using GitHub Actions. There are
two primary workflows that make up the deployment process: `plan.yaml` and
`deploy.yaml`.

## Plan

The "Plan infrastructure changes" [`plan.yaml`][plan] workflow acts as a dry-run
for the deployment. It will analyze the current state of the service and compare
it to the desired state as defined by the Terraform configuration. The plan will
then be displayed in the workflow logs for review.

To run the plan workflow:

1. Navigate to the "Actions" tab of the GitHub repository
1. Select the "Plan infrastructure changes" workflow from the left sidebar

    ![List of workflows with "Plan infrastructure changes" highlighted][img-plan-workflow]

1. Click the "Run workflow" button on the right side of the page

    ![Run workflow button located in the header of the workflow runs table][img-run-workflow]

1. Select the appropriate branch (usually `main`) and environment

    ![Run workflow dialog with branch and environment selectors][img-plan-options]

1. Click the "Run workflow" button to start the workflow
1. Wait for the page to reload and display the workflow run
1. Click on the latest workflow run to view the details

## Deploy

> [!WARNING]
> Although the deploy workflow includes a plan step, it is recommended to always
> run the plan workflow separately and review the results before deploying any
> changes before running the deploy workflow.

The [`deploy.yaml`][deploy] workflow applies the changes defined in the
Terraform configuration to the service. This workflow will first run a plan,
which acts a final check before making any changes. If the plan is successful,
the workflow will proceed to apply the changes.

To run the deploy workflow:

1. Navigate to the "Actions" tab of the GitHub repository
1. Select the "Deploy infrastructure changes" workflow from the left sidebar

   ![List of workflows with "Deploy infrastructure changes" highlighted][img-deploy-workflow]

1. Click the "Run workflow" button on the right side of the page

   ![Run workflow button located in the header of the workflow runs table][img-run-workflow]

1. Select the appropriate branch (usually `main`) and environment

   ![Run workflow dialog with options for the deploy workflow][img-deploy-options]

1. Optionally, specify a tag to use for the container images, or leave blank to
   use the latest commit SHA as the tag
1. Optionally, you can choose to ignore the results of the plan step. This is
   not recommended, but can be useful in rare cases where the changes can result
   in an inconsistent plan.
1. Click the "Run workflow" button to start the workflow
1. Wait for the page to reload and display the workflow run
1. Click on the latest workflow run to view the details

## Common Issues

### AWS eventual consistency

Amazon APIs are eventually consistent, meaning that changes made to resources
may not be immediately reflected in subsequent API calls. This can lead to
failures in the deployment process if a resource is not yet fully available
when the next step is executed. The [aws provider][tf-provider-aws] for
Terraform includes waiters and retries to help mitigate these issues, but in
some cases this may not be sufficient.

If you encounter errors related to resource availability, such as
`ResourceNotFound` or `ResourceInUse`, you may need to re-run the deployment
workflow. In most cases, the issue will resolve itself on a subsequent run.

If the issue persists, you may need to investigate the specific resource
and ensure that it is in the expected state before re-running the deployment.

### Docker build issues

The [kreuzwerker/docker][tf-provider-docker] provider is used to build and push
Docker images. GitHub Actions runners do not have a local Docker cache, so all
images must be built from scratch on each run. If any of the images fail to
build, the deployment will fail.

To help reduce the likelihood of build failures, the deployment workflow uses
the [Clean Runner for Docker Builds][clean-runner] action to reclaim disk space
from unnecessary files before building the images.

Image build failures can also be caused by transient network issues when
pulling base images or dependencies. If you encounter build failures, you can
re-run the deployment workflow to attempt the build again.

[clean-runner]: https://github.com/sctg-development/clean-image-for-docker
[deploy]: ../../.github/workflows/deploy.yaml
[img-deploy-options]: ../assets/deploy/workflow-options.png
[img-deploy-workflow]: ../assets/deploy/workflow-list.png
[img-plan-options]: ../assets/plan/workflow-options.png
[img-plan-workflow]: ../assets/plan/workflow-list.png
[img-run-workflow]: ../assets/run-workflow.png
[plan]: ../../.github/workflows/plan.yaml
[tf-provider-aws]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
[tf-provider-docker]: https://github.com/kreuzwerker/terraform-provider-docker
