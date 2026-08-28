# Approach Documentation

This document explains the key engineering decisions made while building this assignment.

## 1. Stack & Tooling Choice

| Concern | Choice | Why |
|---|---|---|
| IaaC | **Terraform** | Industry-standard, provider-agnostic, modules encourage reuse, huge ecosystem. Matches "Terraform" requirement. |
| Container runtime | **Docker + ECR** | Simple, portable, works across free-tier EC2 without ECS/EKS control-plane cost. Images are single deployment artifact. |
| Compute | **ALB + ASG + EC2 (t3.micro)** | Autoscaling + load balancing with minimal moving parts and free-tier friendly cost. |
| Database | **RDS PostgreSQL** | Managed PostgreSQL (requirement), automatic backups, metrics, PITR out of the box. |
| CI/CD | **GitHub Actions** | No self-hosted infra, YAML-based, native approvals & environments, free for public repos. |
| Monitoring/Logging | **CloudWatch** | Everything streams *by default* from AWS services; dashboards + alarms + SNS + Logs in one place. |

## 2. Module Design

Rather than one monolithic `main.tf`, I split infrastructure into six reusable modules:

- `networking` — VPC, public/private/database subnets, IGW, NAT, route tables, DB subnet group
- `security` — per-tier security groups (ALB/App/DB/Bastion)
- `compute` — launch template + ASG + autoscaling policies + user-data (Docker + CloudWatch agent)
- `database` — RDS PostgreSQL + parameter group + event subscription
- `loadbalancer` — ALB, target group, HTTP/HTTPS listeners, access logs
- `monitoring` — log groups, metric filters, alarms, SNS, and **two dashboards**

This keeps `staging` and `production` as thin environments that merely feed different variable
values into the same modules — a classic **environment-as-config** pattern that avoids duplicated
code and drift.

## 3. State Management

- **Remote backend**: state lives in an encrypted, versioned S3 bucket.
- **State locking**: a DynamoDB `terraform-locks` table prevents concurrent apply conflicts.
- **Per-environment isolation**: remote state paths are `staging/terraform.tfstate` and
  `production/terraform.tfstate`, so a blast radius of one environment cannot corrupt the other.

## 4. Security Posture (defense in depth)

- **Default-deny security groups**: only the exact port paths are opened:
  - Internet → ALB (80/443)
  - ALB → App (80)
  - App → DB (5432)
- **No public instance access**: EC2 lives in private subnets; SSH is not exposed to the internet
  (bastion option toggled off by default).
- **Encryption at rest**: EBS = gp3+encrypted, RDS = encrypted, S3 state/access-logs = SSE + versioning.
- **IAM roles, not keys**: EC2 uses an instance profile (ECR read, SSM, CloudWatch agent); RDS
  enhanced-monitoring uses a dedicated role.
- **Secrets**: DB password is `sensitive`; never committed; intended to be served from AWS Secrets
  Manager at runtime. See `docs/SECRETS_MANAGEMENT.md`.

## 5. CI/CD Pipeline Design

- **Fast feedback on PR**: boundary-triggered jobs run tests and vulnerability scans but do NOT
  deploy (safe).
- **Single image, multi-stage promotion**: merge to `main` builds **once** → pushes to ECR →
  deploys to staging → after a human approves the `production` environment gate, the **same**
  image tag is deployed to production. This is the "promotable artifact" ideal.
- **Gate with memory**: production deploy auto-stops if staging smoke test fails.
- **Environment `url`**: GitHub environments link the deployment to the live environment URL.

## 6. Monitoring Design

- **Three data sources** deliberately stream into CloudWatch:
  1. **AGENT-side** (EC2): CloudWatch Agent reports CPU/memory/disk, ships syslog.
  2. **INTEGRATION-side** (ALB/RDS): native service metrics + access logs.
  3. **APPLICATION-side**: Docker `awslogs` log driver + app emits structured JSON and request
     latency/status; log metric filters turn log lines into numeric metrics.
- **Two meaningful dashboards**: one for infrastructure health, one for application health + live
  logs. "Meaningful" = an operator can answer "is the system up and fast?" in one glance.

## 7. Cost-conscious defaults

- Defaults chose the smallest viable sizes (`t3.micro`, `db.t3.micro`), single-AZ RDS, capped
  storage growth, short staging log retention, and NAT disabled in dev guidance.

## 8. Testing strategy

- **Automated**: Node `node:test` unit/integration tests hit live HTTP endpoints.
- **Container verification**: local docker run + curl smoke test.
- **Infra**: `terraform fmt` + `terraform validate` + `terraform plan` (no-apply) in CI.

## What extra code would help (if this were a real product)

- GitHub **OIDC** federated identity for CI (remove long-lived keys).
- Add **Terraform apply in CI with plan-approval** (Atlantis-style) using `terraform plan -out` + approved apply.
- **S3 backend for the S3 module** (bootstrap pattern) or move to OpenTofu/Atlantis.
- Add **EDR/GuardDuty**, **Security Hub** for audit.
- Add **Karpenter/cluster-autoscaler** if moving to EKS for larger scale.
- **IaC drift detection**: schedule `terraform plan` and auto-file issues.
- **Cost anomaly** alarms + Budgets (AWS Budgets) with email alert.
