# Cost Optimization

The defaults are chosen to keep the assignment **free-tier / minimal-cost** friendly. Trade-offs are explicit.

## Baseline config (as delivered)

| Resource | Sizing | Free-tier note |
|---|---|---|
| VPC + subnets + IGW | — | Free |
| NAT Gateway | enabled by default | **~$32/mo** — disable for dev |
| EC2 (ASG) | `t3.micro` ×1 | `t2.micro`/`t3.micro` may be free-tier eligible |
| RDS | `db.t3.micro`, gp3, 20 GB | Free-tier `db.t3.micro` eligible (750 hr) |
| ALB | 1 | ~$16/mo (not free) |
| CloudWatch | logs + dashboards | minimal; pay per GB ingested |
| S3 (state + logs) | tiny | ~free |

## Recommendations to cut cost

1. **Disable NAT in free-tier/dev** — set `enable_nat_gateway = false`. NAT is the biggest hidden
   cost for a single-AZ dev environment. Private instances still get internet via the ALB tier
   pattern only if you accept the tradeoff; for a demo pulling from ECR, prefer using the
   AWS-optimized path or accept NAT for correctness and disable it in dev.
2. **Run single AZ for staging** — `azs = ["ap-south-1a"]`, `enable_nat_gateway = false`,
   `multi_az = false`. This drops NAT, and RDS stays single-AZ. ALB still requires ≥2 subnets in
   **two different AZs** — keep 2 AZs for the ALB even in dev.
3. **Right-size** — keep `t3.micro`/`db.t3.micro`; only scale up when load demands. Production
   `tfvars` already balance HA vs. cost.
4. **Cap storage growth** — RDS `max_allocated_storage` prevents runaway autoscaling.
5. **Short log retention** — `log_retention_days = 14` for staging (longer for prod).
6. **Teardown when idle** — run `terraform destroy` after the demo:
   ```bash
   cd infra/environments/staging && terraform destroy -var-file=terraform.tfvars -auto-approve
   ```

## Rough monthly estimate (staging, NAT off, 1 AZ, 1×t3.micro, 1×db.t3.micro)

| Item | Est. / mo |
|---|---|
| EC2 t3.micro | ~$7 |
| RDS db.t3.micro | ~$13 |
| ALB | ~$16 |
| EIP + misc | ~$3 |
| **Total** | **~$39** (vs. ~$70+ with NAT + multi-AZ) |

Free tier credits can cover much of this for the first 12 months.

## What "good practice" extra would help
- **AWS Budgets** alarm at e.g. $20 with email/Slack notification.
- **Scheduled stop/start** of non-production instances (EC2 Instance Scheduler) when not active.
- Move long-lived log/artifact buckets to `STANDARD_IA`/`GLACIER` lifecycle.
