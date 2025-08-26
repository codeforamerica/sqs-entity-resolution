# SQS Entity Resolution using Senzing

This is an implementation of entity resolution using [Senzing] with [AWS
SQS][sqs]. Data is sent to an SQS queue, which is processed by a "consumer"
service that forwards the data to Senzing for entity resolution. The results can
then be exported to an S3 bucket.

```mermaid
architecture-beta
  group vpc(cloud)[VPC]

  service queue(database)[SQS Queue] in vpc
  service consumer(server)[Consumer] in vpc
  service senzing(server)[Senzing] in vpc
  service db(database)[PostgreSQL] in vpc
  service s3(disk)[S3 Bucket]

  consumer:L --> T:queue
  consumer:B --> T:senzing
  senzing:R --> L:db
  senzing:B --> L:s3
```

[senzing]: https://senzing.com
[sqs]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html
