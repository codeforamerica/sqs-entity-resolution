# Tools Container

The service includes a tools container that provides a set of utilities for
managing and interacting with the Senzing system. You can launch a tools
container, with a number of commands, using the `launch-tools.yaml` GitHub
Actions workflow.

## Usage

The [`launch-tools.yaml`][launch-tools] workflow allows you to start a tools
container with a variety of pre-defined commands. Additionally, you can specify
custom commands to run within the container.

To run the workflow:

1. Navigate to the "Actions" tab of the GitHub repository
1. Select the "Run tools container command" workflow from the left sidebar

   ![List of workflows with "Run tools container command" highlighted][img-tools-workflow]

1. Click the "Run workflow" button on the right side of the page

   ![Run workflow button located in the header of the workflow runs table][img-run-workflow]

1. Select the environment you want to run the tools container in, and the
   command you want to execute.
1. If you've selected the "Custom command" option, enter the command you want to
   run in the provided text box. The command must be a valid command in the
   [Docker exec form][cmd-format].
1. Optionally, set a custom timeout or disable the waiter entirely.

    > [!NOTE]
    > If the command sent to the container does not complete before the timeout,
    > the workflow will be marked as failed. However, the ECS task running the
    > container will continue to run until the command completes or the task is
    > stopped manually.
    >
    > For long-running commands, you may want to disable the waiter entirely by
    > setting the timeout to `0`.

    ![Run workflow dialog with options for the launch tools workflow][img-tools-options]

1. Click the "Run workflow" button to start the workflow
1. Wait for the page to reload and display the workflow run
1. Click on the latest workflow run to view the details

If you've chosen to disable the waiter, you can follow the progress of the task
using the AWS Console or CLI.

## Commands

The following pre-defined commands are available via the workflow.

### Hello World

The "Hello World" command simply echos "Hello, World!" This can be used to
verify the ability to launch the tools container, and it's basic connectivity.

### CSV Export

> [!NOTE]
> This command performs a full export of all entities in the Senzing system.
> Depending on the number of entities, this operation can take a significant
> amount of time and may generate a large amount of data. Ensure that you have
> set a sufficient timeout, or disable the waiter entirely.

The "CSV Export" command uses `sz_export` to export all entities in the Senzing
system to a CSV file. These files can get large depending on the number of
entities in the system. To avoid running out of disk space, the export is
streamed directly to the exports S3 bucket.

The resulting file can be found in the S3 bucket under the `sz-exports/` prefix,
in the format `YYYY-DD-MMTHH:MM:SS+hh:mm-exports.csv`. For example:
`sz-exports/2025-12-15T20:22:42+00:00-exports.csv`.

## Generate Snapshot

> [!NOTE]
> This command performs an analysis of all entities in the Senzing system.
> Depending on the number of entities, this operation can take a significant
> amount of time and may generate a large amount of data. Ensure that you have
> set a sufficient timeout, or disable the waiter entirely.

The "Generate Snapshot" command uses `sz_snapshot` to create a snapshot of all
entities in the Senzing system.

The resulting snapshot file can be found in the exports S3 bucket under the
`sz-snapshots/` prefix, in the format
`YYYY-DD-MMTHH:MM:SS+hh:mm-snapshot.json`. For example:
`sz-snapshots/2025-12-15T20:22:42+00:00-snapshot.json`

## Initialize Database

The "Initialize Database" command performs any necessary initialization of the
database used by the system. This includes Senzing's `G2` database, as well as
the tracking database used for delta exports.

This action is idempotent, and can be run multiple times without adverse
effects.

## JSON Export

> [!NOTE]
> This command performs a full export of all entities in the Senzing system.
> Depending on the number of entities, this operation can take a significant
> amount of time and may generate a large amount of data. Ensure that you have
> set a sufficient timeout, or disable the waiter entirely.

The "JSON Export" command uses `sz_export` to export all entities in the Senzing
system to a JSON file. These files can get large depending on the number of
entities in the system. To avoid running out of disk space, the export is
streamed directly to the exports S3 bucket.

> [!TIP]
> Despite the name and file extension, the export is in [JSON Lines][jsonl]
> format, where each line is a separate JSON object representing an entity.

The resulting file can be found in the S3 bucket under the `sz-exports/` prefix,
in the format `YYYY-DD-MMTHH:MM:SS+hh:mm-exports.json`. For example:
`sz-exports/2025-12-15T20:22:42+00:00-exports.json`.

## Keep Running

> [!NOTE]
> This command overrides any configured timeout and will disable the waiter
> entirely.

The "Keep Running" command simply keeps the tools container running without
exiting. This can be useful for debugging, more complex operations, commands
that require an interactive session, or commands that output sensitive
information such as PII.

Once the task is up and running, you can connect to the container using
[ECS Exec][exec] from either the AWS Console or CLI. The task must be stopped
manually when you are finished.

## Custom

> [!CAUTION]
> The "Custom" command allows you to run arbitrary commands within the tools
> container. Ensure that you understand the implications of the commands you
> run, as they can affect the state of the Senzing system and its data.
>
> The command and its output will be logged. Avoid running commands that may
> expose sensitive information.

The "Custom" option allows you to specify a command to run within the tools
container. The command must be provided in the [Docker exec form][cmd-format].

[cmd-format]: https://docs.docker.com/reference/dockerfile/#exec-form
[exec]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec-run.html
[img-run-workflow]: ../assets/run-workflow.png
[img-tools-options]: ../assets/tools/workflow-options.png
[img-tools-workflow]: ../assets/tools/workflow-list.png
[jsonl]: https://jsonlines.org/
[launch-tools]: ../../.github/workflows/launch-tools.yaml
