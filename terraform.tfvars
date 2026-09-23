# Non-secret deployment configuration. Every variable here is required
# (no default in variables.tf) -- this file is the single explicit
# source, whether applied by CI or a human running `terraform apply`
# locally with no other setup. alert_email's value was already public
# in repo-infra's own committed config.yml, so committing it here
# doesn't newly expose anything.
fqdn        = "jkandler.de"
alert_email = "julian.kandler@outlook.com"
