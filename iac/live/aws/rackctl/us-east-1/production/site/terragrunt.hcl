include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/site.hcl"
  merge_strategy = "deep"
}

inputs = {
  domain = "rackctl.com"

  # gotcha #1: the root passes region + environment but NOT name_prefix; the module
  # derives the www-redirect bucket (rackctl-www-redirect) and deploy role
  # (rackctl-site-deploy) from it.
  name_prefix = "rackctl-"

  # gotcha #2: the origin bucket name is immutable — keep the live one or the plan
  # destroys the origin.
  site_bucket_name = "rackctl.com-site"

  # gotcha #3: the zone is a data source in the retired component, managed elsewhere.
  create_zone = false

  # rackctl owns rackctl-site-deploy in its standalone deploy component, so the module
  # must not create a colliding role. github_repository is unused while this is false,
  # but kept for when the deploy role consolidates here.
  create_deploy_role = false
  github_repository  = "rackctl/web"

  # The site is a React SPA that loads Google Fonts and carries a React inline style
  # (and animates via `motion`), so style-src needs 'unsafe-inline' + the fonts CSS
  # origin, and font-src needs the fonts file origin. script-src stays strict 'self'.
  content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
}

# Migration state ops, generated into the working dir. State-only, no infra changes:
#   - the distribution keeps its identity (rename .this -> .apex, an update in place)
#   - the zone data source becomes counted ([0])
#   - the apex A/AAAA aliases move onto apex["A"]/apex["AAAA"]; the www aliases are
#     NOT moved (they are replaced by the new www distribution's records)
# The old component managed bucket versioning; the module does not. Drop that resource
# from state WITHOUT touching the bucket — versioning stays as-is on rackctl.com-site.
generate "moved" {
  path      = "moved.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    moved {
      from = aws_cloudfront_distribution.this
      to   = aws_cloudfront_distribution.apex
    }
    moved {
      from = data.aws_route53_zone.this
      to   = data.aws_route53_zone.this[0]
    }
    moved {
      from = aws_route53_record.alias_a["rackctl.com"]
      to   = aws_route53_record.apex["A"]
    }
    moved {
      from = aws_route53_record.alias_aaaa["rackctl.com"]
      to   = aws_route53_record.apex["AAAA"]
    }

    removed {
      from = aws_s3_bucket_versioning.site
      lifecycle {
        destroy = false
      }
    }
  EOT
}
