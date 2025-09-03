#!/bin/sh

echo "Initializing localstack S3"
awslocal s3 mb s3://sqs-senzing-local-export

echo "Initializing localstack SQS"
awslocal sqs create-queue --queue-name sqs-senzing-local-ingest
awslocal sqs create-queue --queue-name sqs-senzing-local-redo
