locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  region      = local.region_vars.locals.region
  environment = local.env_vars.locals.environment

  # TERRAGRUNT_ACCOUNT_ID injects the real AWS account id at run time so it never
  # lands in a tracked file. Falls back to the account.hcl placeholder for normal
  # local deploys (where the user sets it in account.hcl directly).
  account_id = get_env("TERRAGRUNT_ACCOUNT_ID", local.account_vars.locals.account_id)

  # Common metadata
  cost_center         = local.env_vars.locals.cost_center
  business_unit       = local.env_vars.locals.business_unit
  data_classification = local.env_vars.locals.data_classification
  compliance          = local.env_vars.locals.compliance
  repository          = local.env_vars.locals.repository

  # owner falls back to cost_center; revision is the CI commit (GITHUB_SHA), "local" off-CI.
  owner    = try(local.env_vars.locals.owner, local.cost_center)
  revision = substr(get_env("GITHUB_SHA", "local"), 0, 7)
}

# --- Common inputs ---
# region + environment are declared by every component; the root passes the
# resolved values down. Component-specific inputs come from _envcommon and the leaf.
inputs = {
  region      = local.region
  environment = local.environment
}

# --- Provider ---
# AWS-only. The region comes from region.hcl; default_tags land on every resource.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Environment        = "${local.environment}"
      ManagedBy          = "opentofu"
      Project            = "rackctl"
      CostCenter         = "${local.cost_center}"
      BusinessUnit       = "${local.business_unit}"
      DataClassification = "${local.data_classification}"
      Compliance         = "${local.compliance}"
      Repository         = "${local.repository}"
      Owner              = "${local.owner}"
      Revision           = "${local.revision}"
      Lifecycle          = "persistent"
    }
  }
}
EOF
}

# --- Remote State ---
# Anchored on the AWS account + region: the state bucket resolves to
# {account_id}-us-east-1-tfstate.
remote_state {
  backend = "s3"

  config = {
    encrypt      = true
    bucket       = "${local.account_id}-${local.region}-tfstate"
    key          = "${local.environment}/${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    use_lockfile = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
