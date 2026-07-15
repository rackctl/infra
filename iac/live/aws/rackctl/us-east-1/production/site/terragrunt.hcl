include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/site.hcl"
  merge_strategy = "deep"
}

inputs = {
  domain = "rackctl.sh"

  # gotcha #1: the root passes region + environment but NOT name_prefix; the module
  # derives the www-redirect bucket (rackctl-www-redirect) and deploy role
  # (rackctl-site-deploy) from it.
  name_prefix = "rackctl-"

  # gotcha #2: the origin bucket name is immutable and domain-agnostic — keep the
  # live one (rackctl.com-site) or the plan destroys + recreates the origin. The
  # bucket is reused as-is across the rackctl.com -> rackctl.sh cutover.
  site_bucket_name = "rackctl.com-site"

  # gotcha #3: the rackctl.sh zone (Z0543652NWOT6RRWNZ2D) is delegated and owned
  # elsewhere; the module reads it via a data source (zone_name resolves to the
  # domain, rackctl.sh) rather than creating it.
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

# No leaf-level moved block is needed for the site-v1.1.0 cutover.
#
# The live state is already on the module's current addresses (aws_cloudfront_
# distribution.apex, aws_route53_record.apex["A"|"AAAA"], data.aws_route53_zone.
# this[0], cert_validation keyed by domain). The only address migration this ref
# introduces — the www-redirect resources gaining `count = var.enable_www`, moving
# from the un-indexed address to [0] — is carried by moved{} blocks INSIDE the
# module itself, so the leaf must not duplicate them.
#
# The rackctl.com -> rackctl.sh domain change legitimately REPLACES the ACM cert
# (new domain + www SAN), its DNS validation records, and the apex/www alias
# records (their name + zone_id change from the rackctl.com zone to the rackctl.sh
# zone). Those are intentional destroy+create on a greenfield zone, not something a
# moved block should mask — so there is nothing to generate here.
