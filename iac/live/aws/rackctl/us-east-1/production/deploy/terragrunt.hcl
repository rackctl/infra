include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/deploy.hcl"
  merge_strategy = "deep"
}

# The role web and docs assume via GitHub OIDC to publish content and invalidate
# CloudFront. Buckets are the deterministic `<domain>-site` names from the site
# component.
inputs = {
  github_repos = ["rackctl/web", "rackctl/docs"]
  site_buckets = ["rackctl-site", "rackctl-docs-site"]

  # The account's GitHub Actions OIDC provider is shared (billoquy/nanohype
  # already created the account-global singleton) — consume it, don't recreate.
  manage_oidc_provider = false
}
