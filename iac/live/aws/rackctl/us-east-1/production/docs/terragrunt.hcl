include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("cloud.hcl"))}/../_envcommon/aws/site.hcl"
  merge_strategy = "deep"
}

# docs.rackctl.sh — the Starlight documentation, served from the shared site
# component (site-v1.1.0). It is a SUBDOMAIN site: its records live in the
# rackctl.sh apex zone (hosted_zone), and it has no www.<subdomain> alias
# (enable_www = false, so the module builds a single distribution and a cert
# with no SAN). The module's dir_index CloudFront function handles the
# directory-index rewrite for the statically generated multi-page site — there
# is no separate rewrite_dir_index/aliases input in this component.
inputs = {
  domain = "docs.rackctl.sh"

  # Records live in the parent apex zone (rackctl.sh, Z0543652NWOT6RRWNZ2D),
  # adopted via the module's data source. Only the zone LOOKUP uses hosted_zone;
  # the site's own name (records, cert, alias) is always the domain.
  hosted_zone = "rackctl.sh"
  create_zone = false

  # A subdomain has no www.<subdomain>: no second distribution, no redirect
  # bucket, no www SAN on the cert.
  enable_www = false

  # name_prefix scopes the module's derived names (e.g. the OAC) for docs.
  name_prefix = "rackctl-docs-"

  # The origin bucket name is immutable and domain-agnostic. Renamed to the estate
  # naming convention (rackctl-docs-site); because bucket names are immutable this
  # force-replaces the origin bucket (destroy docs.rackctl.ai-site + create
  # rackctl-docs-site) and repoints the apex distribution's origin in place.
  site_bucket_name = "rackctl-docs-site"

  # The publish role for docs is owned by the standalone deploy component
  # (github_repos includes rackctl/docs), so this module must not create a
  # colliding role. github_repository is unused while this is false, but kept for
  # when the deploy role consolidates here.
  create_deploy_role = false
  github_repository  = "rackctl/docs"

  # Starlight inlines critical CSS and ships small inline bootstrap scripts (the
  # theme provider + the search-shortcut binder), so both style-src and script-src
  # need 'unsafe-inline'. Pagefind search instantiates a WebAssembly module
  # ('wasm-unsafe-eval') and fetches its same-origin index (connect-src 'self').
  # CSS backgrounds are inlined data: SVGs (img-src data:); fonts are the system
  # stack, so font-src 'self' suffices. Everything else is same-origin.
  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
}

# State migration onto site-v1.1.0's addresses. The docs site was previously on a
# single-distribution component whose distribution was `.this`; v1.1.0 names the
# sole distribution `.apex`. Relink it so the CloudFront distribution keeps its
# identity (an in-place update, not a slow destroy+create).
#
# The prior component also managed bucket versioning; v1.1.0 does not. Drop that
# resource from state WITHOUT touching the bucket, so versioning stays as-is on
# docs.rackctl.ai-site.
#
# The zone data source (uncounted -> [0]) and the domain change itself are handled
# by the plan: the data source simply re-reads at the new address, and the
# docs.rackctl.ai -> docs.rackctl.sh change legitimately replaces the ACM cert, its
# DNS validation record, and the alias A/AAAA records (they move from the
# rackctl.ai zone to the rackctl.sh zone) — intentional greenfield destroy+create.
#
# The dir-index CloudFront function is NOT moved here: its name is derived from the
# domain, so the docs.rackctl.ai -> docs.rackctl.sh change forces a new function,
# and the module declares it without create_before_destroy. tofu would try to
# delete the old function while the distribution still references it (409
# FunctionInUse). It is instead handled out of band before apply by removing the
# old function from state (terragrunt state rm 'aws_cloudfront_function.dir_index[0]')
# so the new one is a pure create and the apex in-place update disassociates the
# old — which then remains as an orphaned function for manual teardown.
generate "moved" {
  path      = "moved.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    moved {
      from = aws_cloudfront_distribution.this
      to   = aws_cloudfront_distribution.apex
    }

    removed {
      from = aws_s3_bucket_versioning.site
      lifecycle {
        destroy = false
      }
    }
  EOT
}
