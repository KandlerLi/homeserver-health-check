# Homeserver reachability check

A Route53 health check, CloudWatch alarm and SNS email alert that watch
`https://jkandler.de/` from outside the home network, so an outage is noticed
even when the homeserver's own monitoring is down.

## Documentation

Setup, operations and design notes, including the sections code comments refer to:
[`docs/README.md`](docs/README.md)
