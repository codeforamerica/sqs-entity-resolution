# Scaling

The service includes a set of auto-scaling policies, CloudWatch alarms, and
EventBridge rules that are used to automatically scale the service in and out
based on the size of the ingestion queue. The parameter for this process, along
with some static scaling parameters, can be configured by setting the
appropriate secrets in the GitHub environment, and deploying to the service.

## Database

You can scale the database instance count and types by modifying the following
secrets:

- `TF_VAR_DATABASE_INSTANCE_COUNT`: The number of database instances to run.
  While you can set this to a higher number, the service will only use a single
  instance for writes.
- `TF_VAR_DATABASE_INSTANCE_TYPE`: The instance type to use for each instance in
  the cluster.[^1]

## Consumer

By default, the service will run 0 consumer containers and will scale up to a
maximum of 10 consumer containers based on the size of the ingestion queue. Once
the queue has been drained, the service will scale back down to 0 containers.

You can modify the following secrets to change this behavior:

- `TF_VAR_CONSUMER_CONTAINER_COUNT`: The number of consumer containers to run at
  all times, regardless of the size of the ingestion queue.
- `TF_VAR_CONSUMER_CONTAINER_MAX`: The maximum number of consumer containers to
  run. The number is constrained to a maximum of 20.
- `TF_VAR_CONSUMER_CPU`: The number of virtual CPUs to allocate to each consumer
  container.[^2]
- `TF_VAR_CONSUMER_MEMORY`: The amount of memory (in MiB) to allocate to each
  consumer container.
- `TF_VAR_CONSUMER_MESSAGE_THRESHOLD`: Controls how many messages can be in the
  ingestion queue before a new consumer container is started.

## Redoer

The redoer is a special type of consumer that processes [REDO] messages
identified by Senzing. These messages are far fewer than ingestion queue, and as
such the redoer does not require the same level of scaling as the consumer.

By default, the service will run 0 redoer containers and will scale up to 1 when
there are items in the ingestion queue. Once the queue has been drained, the
service will scale back down to 0 containers.

You can modify the following secrets to change this behavior:

- `TF_VAR_REDOER_CONTAINER_COUNT`: The number of redoer containers to run at all
  times, regardless of the size of the ingestion queue.
- `TF_VAR_REDOER_CPU`: The number of virtual CPUs to allocate to each redoer
  container.[^2]
- `TF_VAR_REDOER_MEMORY`: The amount of memory (in MiB) to allocate to each
  redoer container.

[instances]: https://instances.vantage.sh/rds?id=2f8ea167c6e686105285d86b52232ae77e7cb6d8
[redo]: https://senzing.zendesk.com/hc/en-us/articles/360007475133-Processing-REDO
[task-size]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size

[^1]: You can use the [instances] table provided by Vantage to help identify the
      right instance type for your workload.
[^2]: The available CPU and memory values are constrained by the [task size
      limits defined by AWS][task-size].
