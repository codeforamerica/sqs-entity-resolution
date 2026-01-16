# Components

The Senzing system is composed of several key components that work together to
provide a robust entity resolution solution. This document outlines the main
components of the system, and how they interact with each other.

All components are contained within a single AWS VPC, where possible. For
resources that don't support VPC deployment (such as SQS and S3), VPC endpoints
are used to ensure communication remains within the AWS network.

![An architecutre diagram show how the differn components connect to each
  other.][components-diagram]

## Ingestion Queue

The [ingestion queue][queues] is responsible for receiving and queuing incoming
data for processing. It represents the entry point for data into the Senzing
system, allowing for easy integration with existing data pipelines.

An AWS SQS queue is used for this purpose, providing a reliable and scalable way
to handle incoming messages. Additionally, a dead-letter queue (DLQ) is
configured to capture any messages that cannot be processed successfully after a
certain number of attempts. This ensures that problematic messages can be
isolated and reviewed without impacting the overall data processing flow, and
without data loss.

## Consumer Service

The [consumer service][consumer] is responsible for processing messages from the
ingestion queue. It retrieves messages, and uses the Senzing SDK to process the
data and perform entity resolution. The consumer service is designed to scale
horizontally, allowing multiple instances to run concurrently to handle varying
workloads.

The consumer service is implemented as a containerized application, deployed on
AWS ECS Fargate. This allows for easy management and scaling of the service,
without the need to manage underlying infrastructure.

## Redoer Service

The [redoer service][redoer] is responsible for reprocessing REDO records in the
Senzing system. REDO records are used to update or correct previously ingested
data, and the redoer service ensures that these updates are applied correctly.

Similar to the consumer service, the redoer service is implemented as a
containerized application deployed on AWS ECS Fargate. It retrieves REDO records
from an internal Senzing queue and processes them using the Senzing SDK.

## Senzing Database

The [Senzing database][database] is the core component of the system,
responsible for storing ingested data and resolved entities. It is implemented
using an AWS Aurora PostgreSQL database, providing a scalable and reliable
storage solution.

## Exporter

The [exporter] is responsible for exporting resolved entities from the Senzing
system. It retrieves entities from the Senzing database and exports them to an
S3 bucket, allowing for easy access and further processing.

The exporter can be run in two modes: full export and delta export. A full
export includes all entities in the system, while a delta export only includes
entities that have changed since the last export.

Similar to the consumer and redoer services, the exporter is implemented as a
containerized application deployed on AWS ECS Fargate. However, it does is
triggered as a one-off task rather than a continuously running service.

## Export Bucket

The export bucket is an S3 bucket used to store exported entities from the
Senzing system. It provides a durable and secure storage solution. The bucket
represents the exit point for data leaving the Senzing system, allowing for easy
access and further processing of exported entities by downstream systems.

## EventBridge

AWS [EventBridge][scaling] is used to trigger certain actions, such as launching
consumers or the exporter, based on the size of the ingestion queue. This allows
for dynamic scaling and operation of the system based on workload.

## Scaling Policies

The [scaling policies][scaling] define how the consumer and redoer services
scale based on the size of the ingestion queue. These policies ensure that the
system can handle varying workloads efficiently, scaling up during periods of
high ingestion and scaling down during periods of low activity.

## Tools Container

The [tools container][tools] is a utility component that provides various
maintenance and operational functions for the Senzing system. It is implemented
as a containerized application deployed on AWS ECS Fargate, and can be run as a
one-off task.

The tools container includes commands for interacting with the database, the
Senzing engine, and the certain AWS resources used by the system through the AWS
CLI.

[components-diagram]: ../assets/components/components.svg
[consumer]: consumer.md
[database]: database.md
[exporter]: exporter.md
[queues]: queues.md
[redoer]: redoer.md
[scaling]: scaling.md
[tools]: tools.md
