terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.9"
    }
  }
}
