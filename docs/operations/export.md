# Manual Export

While the exporter is typically [triggered automatically][auto-export] after
ingestion is complete, you can also trigger an export manually using GitHub
Actions.

## Running

To trigger a manual export, use the [`export.yaml`][manual-export] workflow in
GitHub Actions.

1. Navigate to the "Actions" tab of the GitHub repository
1. Select the "Trigger Senzing export to S3" workflow from the left sidebar

    ![List of workflows with "Trigger Senzing export to S3" highlighted][img-export-workflow]

1. Click the "Run workflow" button on the right side of the page

   ![Run workflow button located in the header of the workflow runs table][img-run-workflow]

1. Select the appropriate branch (usually `main`), environment, and desired
   export mode

    ![Run workflow dialog with options for the export workflow][img-export-options]

1. Click the "Run workflow" button to start the workflow
1. Wait for the page to reload and display the workflow run
1. Click on the latest workflow run to view the details

> [!TIP]
> The export process can take some time to complete, depending on the mode and
> number of entities to be exporter. The workflow will trigger the export but
> does not wait for its completion. You can monitor the progress of the export
> task in ECS using the AWS Console or CLI.

[auto-export]: ../architecture/exporter.md#launching
[img-export-options]: ../assets/export/workflow-options.png
[img-export-workflow]: ../assets/export/workflow-list.png
[img-run-workflow]: ../assets/run-workflow.png
[workflow]: ../../.github/workflows/export.yaml
