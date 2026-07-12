include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/site.hcl"
  merge_strategy = "deep"
}

inputs = {
  domain  = "rackctl.com"
  aliases = ["rackctl.com", "www.rackctl.com"]
}
