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
  description = "Apex domain served by the distribution; its Route53 hosted zone must already exist."
  type        = string
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
