terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Route53 health checks and their CloudWatch alarm metrics are only
# published in us-east-1, regardless of where the checked endpoint
# actually is.
provider "aws" {
  region = "us-east-1"
}
