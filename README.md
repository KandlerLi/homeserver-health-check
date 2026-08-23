# Homeserver reachability check

A Route53 health check + CloudWatch alarm + SNS email alert: checks
`https://jkandler.de/` (the bare apex — dyndns's home-network-managed
DNS record, not `www.jkandler.de`) every 30 seconds from AWS's global
network, and emails `alert_email` if it stops responding (and again when
it recovers).

## Why this exists, and why it's this small

This is deliberately the *only* piece of monitoring that runs in AWS. The
rest (host health, container health, service reachability, certificate/DNS
expiry) is planned to run entirely on the homeserver itself — a full
Prometheus + Grafana stack would have real ongoing AWS cost for something
that can run for free on hardware already paid for. But monitoring that
lives entirely on the homeserver can't tell you the homeserver itself is
unreachable. This is that one external, independent check — small,
cheap (~$0.50-1/month), and specifically placed outside the thing it's
watching.

## Why the bare apex, not `www.jkandler.de`

`www.jkandler.de` is served by CloudFront/S3 — entirely AWS-hosted,
independent of the home network. Checking it would test AWS's own
reachability, not the homeserver's. `jkandler.de` (bare) is the
DynDNS-managed record pointing at the home IP; checking it, and getting a
response at all (even the 301 redirect to `www` that Traefik serves for
it), confirms the home network, DynDNS record, and Traefik are all
actually working end-to-end.

## `alert_email` has no default, deliberately

Same as `aws-budget`: this repo is public, so the address isn't committed
to git history. It's supplied via `TF_VAR_alert_email`, sourced from this
repository's own `ALERT_EMAIL` GitHub Actions variable (set automatically
by `repo-infra`).

## One manual step nothing can automate

SNS email subscriptions require clicking a confirmation link AWS sends to
`alert_email` after the first apply. No notification is delivered until
that's confirmed — this is an SNS platform requirement, not something
Terraform can skip.

## Prerequisites

- Terraform 1.10 or newer
- The `jkandler-terraform-state` S3 backend bucket
- AWS credentials with permission to manage Route53 health checks,
  CloudWatch alarms, and SNS when bootstrapping or recovering outside
  GitHub Actions

## Deploy

```bash
export TF_VAR_alert_email="you@example.com"
terraform init
terraform plan
terraform apply
```

The S3 backend uses `homeserver-health-check/terraform.tfstate` and
native S3 lock files.

## Runner

Self-hosted home runner (`[self-hosted, home, debian]`), same as
`dyndns`/`website`/`aws-budget`.

## Local validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
