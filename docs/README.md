# Homeserver reachability check

A Route53 health check + CloudWatch alarm + SNS email alert: checks
`https://jkandler.de/` (the bare apex — dyndns's home-network-managed
DNS record, not `www.jkandler.de`) every 30 seconds from AWS's global
network, and emails `alert_email` if it stops responding (and again when
it recovers).

## Why this exists, and why it's this small

This is deliberately the *only* piece of monitoring that runs in AWS. The
rest (host and container health, per-service probes, certificate expiry,
backups, logs) runs on the homeserver itself: Prometheus with its exporters
and Loki on the host, Grafana and Alertmanager in k3s (`home-infra`'s
`monitoring` role, `k3s-apps`). Running that in AWS would have real ongoing
cost for something hardware already paid for does for free. But monitoring
that lives entirely on the homeserver can't tell you the homeserver itself
is unreachable. This is that one external, independent check — small,
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

## Timing and what it doesn't cover

Each Route53 checker marks the endpoint unhealthy after 3 failed requests
30 s apart; `HealthCheckStatus` drops to 0 once fewer than about 18% of the
checkers report it healthy. The alarm fires on the first minute whose
minimum is 0, so the email arrives roughly 2-3 minutes into an outage, and
outages shorter than that may not alert at all. A 2xx or 3xx within the
timeout counts as healthy, so Traefik's redirect is enough: a single broken
service behind it doesn't trip this check, and Route53 doesn't validate the
TLS certificate. Both are covered by the homeserver's own blackbox probes.

## Why us-east-1, with its own KMS key

Route53 health checks publish their CloudWatch metrics only in
`us-east-1`, wherever the checked endpoint is, so this whole root runs
there. That also rules out the workspace's shared customer managed key
([`terraform-state`'s `shared_kms_key.tf`](https://github.com/KandlerLi/terraform-state/blob/main/shared_kms_key.tf)):
it lives in `eu-central-1` and can't encrypt anything here. The SNS topic
gets its own dedicated key instead (trivy AWS-0095/AWS-0136), referenced
directly within this root. Its key policy lets CloudWatch Alarms publish
to the encrypted topic, in the shape AWS documents for that case
("Enable compatibility between event sources from AWS services and
encrypted topics" in the SNS key management docs).

## `alert_email` has no default

Like every variable here, it has no default in `variables.tf`; its value is
committed in `terraform.tfvars`, the single source for CI and local runs
alike (since 2026-09-23). The repo is public, so the address is too; it was
already in `repo-infra`'s public history, which used to set it as an
`ALERT_EMAIL` Actions variable.

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
terraform init
terraform plan
terraform apply
```

The S3 backend uses `homeserver-health-check/terraform.tfstate` and
native S3 lock files.

## Runner

Self-hosted runner label `[self-hosted, home, debian]` through
`gha-common`'s reusable workflows, served by this repo's ARC runner scale set
in k3s (`k3s-node-2`, `k3s-bootstrap`; ADR 0027), same as the other AWS repos.

## Local validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
