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
  site_buckets = ["rackctl.com-site", "docs.rackctl.ai-site"]
}
