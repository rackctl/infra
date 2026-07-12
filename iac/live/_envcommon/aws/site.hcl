# Shared wiring for the rackctl static-site component: points every live leaf at
# the component source. Concrete inputs (domain, aliases) live in the leaf.
terraform {
  source = "${dirname(find_in_parent_folders("cloud.hcl"))}/../..//components/aws/site"
}
