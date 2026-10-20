---
title: Infrastructure
---
# Infrastructure

The infrastrucure for the service is managed using OpenTofu configurations. 
These configurations are divded into multiple "layers" that allow independant
deployments, shared resourecs, and greater portability.

These configurations are found in the [`tofu/config`][configs] directory.

## Foundation

The [foundation] config is the base layer for all infrasrucutre. It creates
resources necessary to deploy and manage the OpenTofu configurations.

## Networking

The [networking] config builds and manages the VPC, subnets, and other
networking related resources required to operate the service.

## Service

The [service] config deploys the actual entity resolution seervice and all of
its requried components.

## Dashbaords

The [dashbaords] config deploys a set of CloudWatch dashbaord to monitor the
service.

[configs]: https://github.com/codeforamerica/sqs-entity-resolution/tree/main/tofu/config
[dashbaords]: dashboards.md
[foundation]: foundation.md
[networking]: networking.md
[service]: service.md