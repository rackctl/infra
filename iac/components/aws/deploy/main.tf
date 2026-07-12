# GitHub Actions OIDC → a least-privilege role that CI assumes to publish site
# content and invalidate CloudFront. No long-lived AWS keys live in any repo.

locals {
  oidc_host = "token.actions.githubusercontent.com"

  provider_arn = var.manage_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # sub claims: `repo:owner/name:*` matches any branch, tag, or environment.
  sub_claims = [for r in var.github_repos : "repo:${r}:*"]

  # Each bucket needs the bucket ARN (ListBucket) and object ARN (Get/Put/Delete).
  bucket_arns = flatten([for b in var.site_buckets : ["arn:aws:s3:::${b}", "arn:aws:s3:::${b}/*"]])
}

# The GitHub OIDC provider is account-global — create it here, or point at an
# existing one with manage_oidc_provider = false.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.manage_oidc_provider ? 1 : 0

  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.manage_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_host}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.sub_claims
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Name = "${var.role_name}-${var.environment}"
  }
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "SiteBucketWrite"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.bucket_arns
  }

  # CreateInvalidation has no meaningful resource-level scoping (it cannot read or
  # mutate content), so it is granted account-wide.
  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "site-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
