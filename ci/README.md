# CI/CD Pipeline

The GitHub Actions pipelines live in `.github/workflows/` (canonical). This `ci/` directory mirrors
them plus supporting docs.

## Workflows

| File | Trigger | Purpose |
|---|---|---|
| `pr-ci.yml` | PR to `main` (`app/**`) | Tests, `npm audit`, Trivy FS + container scan |
| `terraform-ci.yml` | PR/push (`infra/**`) | `terraform fmt`, `validate`, `plan` (staging + prod) |
| `build-deploy.yml` | merge to `main` (`app/**`) | Build/push ECR → deploy staging → manual-approve → deploy prod |

## GitHub Org/Repo setup

1. Create the repo on GitHub and push this code.
2. Add **secrets** under `Settings → Secrets and variables → Actions`:
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
   - `AWS_ACCOUNT_ID` (12-digit)
   - `TF_STATE_BUCKET`
3. Create GitHub **environments** named `staging` and `production`. Place a **required reviewer** on
   the `production` environment so `deploy-production` waits for a human approval.
4. Optionally set the `production` environment URL to the deployed ALB URL.

### Minimal IAM policy for the CI deploy user

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "ecr:*", "Resource": "*" },
    { "Effect": "Allow", "Action": "ec2:*", "Resource": "*" },
    { "Effect": "Allow", "Action": "elasticloadbalancing:*", "Resource": "*" },
    { "Effect": "Allow", "Action": "autoscaling:*", "Resource": "*" },
    { "Effect": "Allow", "Action": "rds:*", "Resource": "*" },
    { "Effect": "Allow", "Action": "s3:GetObject", "Resource": "arn:aws:s3:::cloudzone-tfstate-*/*" },
    { "Effect": "Allow", "Action": ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:ap-south-1:*:table/terraform-locks" }
  ]
}
```

> **Recommendation:** replace long-lived keys with GitHub **OIDC** for least-privilege, short-lived
> credentials (see `docs/SECURITY.md`).

## Notifications
- AWS-side alerts already flow to email via SNS (`alert_email` in `.tfvars`).
- To get **Slack** failure notifications, add a `slack/send` step or webhook call in the
  `notify-*` jobs of each workflow.
