# Shared wiring for the GitHub Actions deploy-role component: points the live
# leaf at the component source. Concrete inputs (repos, buckets) live in the leaf.
terraform {
  source = "${dirname(find_in_parent_folders("cloud.hcl"))}/../..//components/aws/deploy"
}
