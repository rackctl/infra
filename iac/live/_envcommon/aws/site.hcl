# Shared wiring for the rackctl static-site component: points every live leaf at
# the component source. Concrete inputs (domain, aliases) live in the leaf.
terraform {
  source = "git::git@github.com:stxkxs/landing-zone.git//iac/components/aws/site?ref=site-v1.0.2"
}
