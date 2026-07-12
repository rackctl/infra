output "deploy_role_arn" {
  description = "ARN of the role GitHub Actions assumes to publish site content. Set it as the AWS_DEPLOY_ROLE_ARN secret on web and docs."
  value       = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider used by the trust policy."
  value       = local.provider_arn
}
