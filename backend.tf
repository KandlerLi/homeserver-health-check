terraform {
  backend "s3" {
    bucket       = "jkandler-terraform-state"
    key          = "homeserver-health-check/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
