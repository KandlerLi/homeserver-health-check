terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Route53 health check metrics exist only in us-east-1.
provider "aws" {
  region = "us-east-1"
}
