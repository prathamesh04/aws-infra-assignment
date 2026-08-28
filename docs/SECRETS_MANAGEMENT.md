# Secret Management

Secrets (RDS password, API keys, cert private keys) must **never** live in VCS. This documents how
secrets are handled and the production-grade pattern to adopt.

## How the assignment handles secrets
- DB password is declared as a Terraform **`sensitive`** variable:
  ```hcl
  variable "db_password" { type = string; sensitive = true }
  ```
  Sensitive values are redacted from plan/apply output.
- `.gitignore` excludes `terraform.tfvars`, `*.pem`, `credentials`, `*.env` — real values are never
  committed. Only `*.tfvars.example` placeholders are tracked.
- CI reads secrets from **GitHub Actions encrypted secrets** (`AWS_ACCESS_KEY_ID`, etc.), never
  from the repo.

## Production pattern: AWS Secrets Manager

For a real deployment, store the DB password (and other secrets) in **AWS Secrets Manager** and let
the application read it at runtime instead of baking it into the launch template / env:

```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}/db/credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# EC2 Instance Profile already grants AmazonSSMManagedInstanceCore;
# add a policy to read this secret so the app can fetch it at boot:
resource "aws_iam_policy" "read_db_secret" { /* ... */ }
```

The container then fetches credentials from `secretsmanager:GetSecretValue` at startup, enabling
**rotation** and avoiding static env vars.

### Rotation
- Secrets Manager supports **Lambda-based automatic rotation** for RDS credentials. Configure a
  rotation schedule (e.g., every 30 days) and the app re-reads the secret per connection.

### Minimal checklist
- [ ] No secrets in `git` history (use `git filter-repo` if leaked).
- [ ] All secrets behind AWS Secrets Manager / SSM Parameter Store (secure-string).
- [ ] Least-privilege IAM policies to read only the secrets an app needs.
- [ ] Rotate secrets regularly; enforce MFA on the console.
