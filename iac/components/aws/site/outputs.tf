output "bucket" {
  description = "The S3 bucket holding the site content (deploy target)."
  value       = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  description = "CloudFront distribution id, for cache invalidations after a deploy."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "domain" {
  description = "The site's public domain."
  value       = var.domain
}
