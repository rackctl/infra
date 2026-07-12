variable "region" {
  description = "AWS region for the stack (IAM is global; this is declared for the shared root inputs)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. production)."
  type        = string
}

variable "manage_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if the account already has one (it is account-global — only one may exist)."
  type        = bool
  default     = true
}

variable "github_repos" {
  description = "owner/name repositories whose Actions workflows may assume the deploy role (any branch/ref)."
  type        = list(string)
}

variable "site_buckets" {
  description = "S3 site bucket names the deploy role may write to (deterministic: `<domain>-site`)."
  type        = list(string)
}

variable "role_name" {
  description = "Name of the deploy role."
  type        = string
  default     = "rackctl-site-deploy"
}
