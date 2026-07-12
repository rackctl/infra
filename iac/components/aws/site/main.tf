locals {
  # The zone to write records into — the apex zone, which may be a parent of the
  # served subdomain (docs.rackctl.ai lives in the rackctl.ai zone).
  zone_name = var.hosted_zone != "" ? var.hosted_zone : var.domain

  # Static multi-page sites 404 honestly to /404.html; SPAs fall back to the app
  # shell (index.html, 200) so client-side routing can take over.
  error_page = var.rewrite_dir_index ? "/404.html" : "/index.html"
  error_code = var.rewrite_dir_index ? 404 : 200
}

data "aws_route53_zone" "this" {
  name = local.zone_name
}

# ── Origin bucket ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "site" {
  bucket = "${var.domain}-site"

  tags = {
    Name = "${var.domain}-site-${var.environment}"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── TLS certificate (DNS-validated, us-east-1) ──────────────────────────────
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain
  subject_alternative_names = [for a in var.aliases : a if a != var.domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── CloudFront ──────────────────────────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.domain}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Directory-index rewrite for statically-generated multi-page sites: S3 + OAC has
# no index-document resolution, so map `/foo/` and `/foo` to `/foo/index.html`.
resource "aws_cloudfront_function" "dir_index" {
  count   = var.rewrite_dir_index ? 1 : 0
  name    = "${replace(var.domain, ".", "-")}-dir-index"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory URIs to /index.html for ${var.domain}"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.split('/').pop().includes('.')) {
        request.uri = uri + '/index.html';
      }
      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.domain
  default_root_object = "index.html"
  aliases             = var.aliases
  price_class         = var.price_class

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed CachingOptimized policy.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    dynamic "function_association" {
      for_each = var.rewrite_dir_index ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.dir_index[0].arn
      }
    }
  }

  # S3 + OAC returns 403 for a missing key. A static site serves its /404.html
  # (404); a SPA serves the app shell (index.html, 200) so client routing runs.
  # The /install object exists on rackctl.com, so it is served directly.
  custom_error_response {
    error_code            = 403
    response_code         = local.error_code
    response_page_path    = local.error_page
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = local.error_code
    response_page_path    = local.error_page
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ── Bucket policy: only this distribution may read, via OAC ──────────────────
data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# ── DNS: apex + aliases → CloudFront ────────────────────────────────────────
resource "aws_route53_record" "alias_a" {
  for_each = toset(var.aliases)

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_aaaa" {
  for_each = toset(var.aliases)

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
