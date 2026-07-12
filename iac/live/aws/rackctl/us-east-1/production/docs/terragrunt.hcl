include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/site.hcl"
  merge_strategy = "deep"
}

# docs.rackctl.ai — the Starlight documentation. A subdomain of the rackctl.ai
# zone, served as a static multi-page site (directory-index rewrite on).
inputs = {
  domain            = "docs.rackctl.ai"
  aliases           = ["docs.rackctl.ai"]
  hosted_zone       = "rackctl.ai"
  rewrite_dir_index = true
}
