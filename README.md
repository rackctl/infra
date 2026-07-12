# rackctl infra

AWS infrastructure for rackctl, provisioned with **OpenTofu** + **Terragrunt** —
AWS-only, mirroring the `components/` + `live/` layout used across the ecosystem.

## Layout

```
iac/
  components/aws/site/         # reusable module: S3 + CloudFront + ACM + Route53
  live/
    root.hcl                   # S3 remote state + generated aws provider + default_tags
    _envcommon/aws/site.hcl    # shared component wiring
    aws/rackctl/us-east-1/production/site/   # the live stack
```

The account id is never tracked: it's injected at run time via
`TERRAGRUNT_ACCOUNT_ID` (the `account.hcl` value is a placeholder), and state
lives in `{account_id}-us-east-1-tfstate`.

## What `site` provisions

**rackctl.com** — a private S3 origin behind CloudFront (origin-access-control),
a DNS-validated ACM certificate (**us-east-1**, required for CloudFront), and
Route53 alias records for the apex + `www`. The installer is served at
`rackctl.com/install` as an S3 object, so `curl … | sh` works.

## Deploy

Prereqs: `tofu`, `terragrunt`, the `aws` CLI (SSO), an existing Route53 hosted
zone for `rackctl.com`, and a `{account_id}-us-east-1-tfstate` state bucket.

```sh
export AWS_PROFILE=…                # SSO profile for the rackctl account
export TERRAGRUNT_ACCOUNT_ID=…      # real account id, kept out of tracked files
cd iac/live/aws/rackctl/us-east-1/production/site
terragrunt apply
```

Content — the built site and the installer script — is uploaded as a separate
deploy step (not managed by tofu), then CloudFront is invalidated:

```sh
BUCKET=$(terragrunt output -raw bucket)
DIST=$(terragrunt output -raw distribution_id)
aws s3 sync path/to/web/dist "s3://$BUCKET/"
aws s3 cp path/to/install.sh "s3://$BUCKET/install" --content-type text/plain
aws cloudfront create-invalidation --distribution-id "$DIST" --paths '/*'
```

## License

[Apache 2.0](LICENSE)
