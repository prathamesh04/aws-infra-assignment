# Security Considerations

Security is applied in layers (defense-in-depth). This documents the posture and how to harden further.

## 1. Network isolation
- EC2 and RDS live in **private subnets** — no public IPs, no internet ingress.
- **Security groups are default-deny** and only open explicit, minimal paths:
  - `0.0.0.0/0 → 80/443` on the ALB only
  - ALB → App on `80` (referencing the ALB SG, not a CIDR)
  - App → DB on `5432`
- No SSH is exposed to the internet by default. A bastion SG exists and is **disabled** by default;
  if enabled, restrict its CIDR to your office IP.

## 2. Encryption
- **At rest**: EBS volumes are `gp3` + encrypted; RDS storage is encrypted; S3 state and ALB-log
  buckets have SSE + versioning + public-access-block.
- **In transit**: HTTPS listener supported via ACM (`acm_certificate_arn`), pinned to
  `ELBSecurityPolicy-TLS13-1-2-2021-06`. Apps should also enforce TLS to the DB (pg `ssl=require`).

## 3. Identity & Access Management
- **No static access keys on EC2** — instances assume an IAM **instance profile** scoped to
  ECR-read + SSM core + CloudWatch agent.
- **RDS enhanced monitoring** uses a dedicated `AmazonRDSEnhancedMonitoringRole` (least privilege).
- CI uses a dedicated deploy user whose policy should be scoped to the resources it manages
  (recommend switching to GitHub **OIDC** to avoid long-lived keys in CI).
- Multifactor/rotated root keys; avoid using root for routine IaC.

## 4. Secrets management
- The DB password is a Terraform **`sensitive`** variable and is **not** committed (`.gitignore`
  excludes `terraform.tfvars`, `*.pem`, `credentials`).
- Production secrets should be stored in **AWS Secrets Manager** and rotated (see
  `docs/SECRETS_MANAGEMENT.md` for the pattern).

## 5. Supply-chain / containers
- CI runs **Trivy** on dependency `fs` scans and container images (`CRITICAL,HIGH`, fail on container
  findings) plus `npm audit`.
- Docker image runs as a **non-root user** and exposes `/health` for readiness gating.
- Application dependencies are pinned via `package-lock.json` (`npm ci`).

## 6. Audit & monitoring
- Network traffic and service events visible in CloudWatch + VPC Flow Logs (recommend enabling).
- Alarms (5xx, latency, DB connections, CPU) feed **SNS → email/Slack**.
- RDS event subscriptions capture backup/maintenance/availability events.

## 7. Recommended hardening for production
1. Configure an ACL/route table that blocks private-subnet traffic you don't need.
2. Enable **GuardDuty**, **Security Hub**, and **VPC Flow Logs**.
3. Rotate IAM keys; adopt OIDC for CI.
4. Enforce **HTTPS redirect** on the ALB (add a `default_action` redirect once a certificate is
   attached).
5. Turn on **deletion protection** for RDS and ALB (already on in production tfvars).
6. Restrict `admin_cidr_blocks` if a bastion is used.
