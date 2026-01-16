# Security

## AWS Security Hub

Security of the AWS resources used in this deployment is monitored using
[AWS Security Hub][security-hub]. Security Hub provides a comprehensive view of
security alerts and compliance status across resources. It aggregates findings
across services such as Amazon GuardDuty, Amazon Inspector, and AWS Config to
ensure that security best practices are being followed.

## GitHub Advanced Security

GitHub Actions runs three workflows that either require or support [GitHub
Advanced Security][ghas] (GHAS) features. GHAS is an additional paid feature for
GitHub repositories that provides advanced security features, including code
scanning, secret scanning, and dependency review. Public repositories have
access to these features at no cost.

## Enabling GitHub Advanced Security

Once you have obtained GitHub Advanced Security for your organization, you can
follow the steps below to enable it for your repository:

1. Navigate to your repository GitHub
1. Click the "Settings" tab under your repository name. If you don't see it,
   select the dropdown menu, then click Settings.
1. In the left sidebar, in the "Security" section, click either "Code security
   and analysis" or "Advanced Security," depending on your GitHub interface
1. Next to "Cde security", click the "Enable" button to the right of the feature

There are no additional steps required to enable the workflows in this
repository. Once GHAS is enabled, the workflows will automatically start to
utilize the GHAS features.

### CodeQL

> [!NOTE]
> GitHub Advanced Security is required to use CodeQL analysis in GitHub Actions
> on private repositories. If GHAS is not enabled, the CodeQL workflow will be
> skipped.

[CodeQL] is a semantic code analysis engine that performs deep analysis of code
to identify potential security vulnerabilities. The [workflow][codeql-workflow]
is configured to run on pushes and pull requests to the `main` branch, as well
as on a weekly schedule.

The results of the CodeQL analysis are available in the "Security" tab of the
GitHub repository when GitHub Advanced Security is enabled.

### TFLint

[TFLint] is a Terraform linter that checks for best practices and potential
security issues in Terraform code. The [workflow][tflint-workflow] is configured
to run on pushes and pull requests to the `main` branch.

If GHAS is enabled, TFLint will upload the results of its analysis of the `main`
branch to the "Security" tab of the GitHub repository.

### Trivy

[Trivy] is a static analysis tool that scans Terraform code for security
vulnerabilities. The [workflow][trivy-workflow] is configured to run on pushes
and pull requests to the `main` branch.

If GHAS is enabled, Trivy will upload the results of its analysis of the `main`
branch to the "Security" tab of the GitHub repository.

[codeql]: https://codeql.github.com/
[codeql-workflow]: https://github.com/codeforamerica/sqs-entity-resolution/blob/main/.github/workflows/codeql.yaml
[ghas]: https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security
[security-hub]: https://docs.aws.amazon.com/securityhub/latest/userguide/what-are-securityhub-services.html
[tflint]: https://github.com/terraform-linters/tflint
[tflint-workflow]: https://github.com/codeforamerica/sqs-entity-resolution/blob/main/.github/workflows/tflint.yaml
[trivy]: https://github.com/aquasecurity/trivy
[trivy-workflow]: https://github.com/codeforamerica/sqs-entity-resolution/blob/main/.github/workflows/trivy.yaml
