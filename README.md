# rackctl infra

AWS infrastructure for rackctl, provisioned with **OpenTofu** + **Terragrunt** —
AWS-only, mirroring the `components/` + `live/` layout used across the ecosystem.

## Layout

```
iac/
  components/aws/
    site/                      # reusable module: S3 + CloudFront + ACM + Route53
    deploy/                    # GitHub Actions OIDC provider + least-privilege deploy role
  live/
    root.hcl                   # S3 remote state + generated aws provider + default_tags
    _envcommon/aws/{site,deploy}.hcl   # shared component wiring
    aws/rackctl/us-east-1/production/
      site/                    # rackctl.com
      docs/                    # docs.rackctl.ai
      deploy/                  # the CI deploy role
```

The account id is never tracked: it's injected at run time via
`TERRAGRUNT_ACCOUNT_ID` (the `account.hcl` value is a placeholder), and state
lives in `{account_id}-us-east-1-tfstate`.

## What it provisions

The reusable **`site`** component is a private S3 origin behind CloudFront
(origin-access-control), a DNS-validated ACM certificate (**us-east-1**, required
for CloudFront), and Route53 alias records. It's instantiated twice:

- **rackctl.com** — the landing page. The installer is served at
  `rackctl.com/install` as an S3 object, so `curl … | sh` works. SPA-style: a
  missing key falls back to `index.html`.
- **docs.rackctl.ai** — the Starlight docs. A subdomain of the `rackctl.ai` zone
  (`hosted_zone`), served as a static multi-page site: a CloudFront Function
  rewrites directory URIs to `…/index.html` (`rewrite_dir_index`) and misses
  return the real `/404.html`.

The **`deploy`** component wires GitHub Actions OIDC to a least-privilege IAM role
(`rackctl-site-deploy`) that `rackctl/web` and `rackctl/docs` assume from CI to
publish content and invalidate CloudFront — no long-lived AWS keys in any repo.

## Deploy

Prereqs: `tofu`, `terragrunt`, the `aws` CLI (SSO), Route53 hosted zones for
`rackctl.com` and `rackctl.ai`, and a `{account_id}-us-east-1-tfstate` state
bucket.

```sh
export AWS_PROFILE=…                # SSO profile for the rackctl account
export TERRAGRUNT_ACCOUNT_ID=…      # real account id, kept out of tracked files

# provision all three stacks (or run them individually)
cd iac/live/aws/rackctl/us-east-1/production
terragrunt run-all apply
```

Then wire CI to the deploy role. These are Actions **variables** (not secrets — a
role ARN and a distribution id are not credentials), which lets each `deploy`
workflow guard on them and stay dormant until they're set:

```sh
cd deploy
ROLE=$(terragrunt output -raw deploy_role_arn)
gh variable set AWS_DEPLOY_ROLE_ARN --org rackctl --visibility selected --repos web,docs --body "$ROLE"

cd ../site && gh variable set SITE_DISTRIBUTION_ID --repo rackctl/web  --body "$(terragrunt output -raw distribution_id)"
cd ../docs && gh variable set DOCS_DISTRIBUTION_ID --repo rackctl/docs --body "$(terragrunt output -raw distribution_id)"
```

After that, each repo's `deploy` workflow publishes on merge to `main`: build →
assume the role via OIDC → `aws s3 sync` → CloudFront invalidation. The installer
is uploaded to `rackctl.com/install` by the web deploy.

## License

[Apache 2.0](LICENSE)
