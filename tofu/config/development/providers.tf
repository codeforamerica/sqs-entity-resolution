provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      application = "sqs-senzing-development"
      environment = "development"
      program     = "safety-net"
      project     = "sqs-senzing"
    }
  }
}
