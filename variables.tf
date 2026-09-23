variable "fqdn" {
  description = "Public hostname to health-check. jkandler.de (the bare apex) is dyndns's home-network-managed record -- checking it, not www.jkandler.de, is what actually tests home network/Traefik reachability rather than the AWS-hosted CV site."
  type        = string
}

variable "alert_email" {
  description = "Email address to notify when the health check goes unhealthy"
  type        = string
}
