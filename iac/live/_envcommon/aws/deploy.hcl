# Shared wiring for the GitHub Actions deploy-role component: points the live
# leaf at the component source. Concrete inputs (repos, buckets) live in the leaf.
terraform {
  source = "git::git@github.com:stxkxs/landing-zone.git//iac/components/aws/deploy?ref=deploy-v1.0.0"
}
