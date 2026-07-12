variable "region" {
  description = "AWS region for the stack; must be us-east-1 for the CloudFront ACM certificate."
  type        = string

  validation {
    condition     = var.region == "us-east-1"
    error_message = "CloudFront certificates require us-east-1."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. production)."
  type        = string
}

variable "domain" {
  description = "Primary domain served by the distribution; used for the bucket name and the certificate."
  type        = string
}

variable "hosted_zone" {
  description = "Route53 hosted zone that holds the records. Defaults to var.domain; set it when the served domain is a subdomain of a larger zone (e.g. docs.rackctl.ai served from the rackctl.ai zone)."
  type        = string
  default     = ""
}

variable "aliases" {
  description = "Domain names the distribution answers to (apex plus any subdomains), all covered by the certificate."
  type        = list(string)
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "rewrite_dir_index" {
  description = "Rewrite directory-style URIs (ending in / or extensionless) to …/index.html via a CloudFront Function, and serve /404.html for misses. Enable for statically-generated multi-page sites (Starlight docs); leave off for single-page apps that route client-side and want the index.html fallback."
  type        = bool
  default     = false
}
