# Architecture

## Overview

The stack is a classic **three-tier, multi-AZ** web architecture designed for high availability,
isolation between tiers, and centralized observability.

```
                    ┌─────────────────────────────────────────┐
                    │              Internet                    │
                    └───────────────┬─────────────────────────┘
                                    │ 80 / 443
                    ┌───────────────▼─────────────────────────┐
                    │        Application Load Balancer        │  (public subnets, 2 AZ)
                    └───────────────┬─────────────────────────┘
                                    │ 80 (SG: ALB-only)
                    ┌───────────────▼─────────────────────────┐
                    │   Auto Scaling Group (EC2, t3.micro)     │  (private subnets, 2 AZ)
                    │   Launch Template → user-data runs       │
                    │   Docker container (app:latest from ECR) │
                    │   CloudWatch Agent (metrics+syslog)      │
                    └───┬──────────────┬──────────────────────┘
                        │ 5432         │ egress
                        │ (SG: App)    ▼ NAT Gateway → Internet
                    ┌───▼─────────────────────────────────────┐
                    │        RDS PostgreSQL (db.t3.micro)      │  (database subnets, 2 AZ)
                    │   automated backups, PITR, monitoring    │
                    └─────────────────────────────────────────┘

  Observability:
    CloudWatch Logs (app logs, syslog, ALB access) → S3 (access logs)
    CloudWatch Metrics (EC2 via agent, ALB, RDS, app filters)
    CloudWatch Alarms → SNS → Email
    CloudWatch Dashboards (infrastructure + application)
```

## Component breakdown

### Networking (`infra/modules/networking`)
- One VPC (`10.0.0.0/16` staging / `10.1.0.0/16` production).
- **Public subnets** (ALB + NAT) across AZs, `map_public_ip_on_launch = true`.
- **Private subnets** (compute) — no public IPs.
- **Database subnets** (RDS) — no public IPs.
- Internet Gateway for public routing; NAT Gateway for private egress (disabled for free-tier dev).
- Dedicated DB subnet group.

### Compute (`infra/modules/compute`)
- **Launch template** picks current Amazon Linux 2023 AMI, `t3.micro`, gp3 encrypted root volume,
  Instance Profile (ECR + SSM + CloudWatch), monitoring enabled.
- **User-data** installs Docker + CloudWatch agent, logs into ECR, runs the app container on host
  port `80 → 8080` with the `awslogs` log driver.
- **ASG** with min/max/desired sizing and a target-group attachment for the ALB.
- **Autoscaling policies** + CPU alarms (scale-out on high CPU / scale-in on low).

### Database (`infra/modules/database`)
- RDS **PostgreSQL 16**, `db.t3.micro`, gp3 encrypted storage, enhanced monitoring via dedicated role.
- Backups enabled with configurable retention; PITR when retention > 0.
- Parameter group tuned for logging; event subscription → SNS.

### Load balancer (`infra/modules/loadbalancer`)
- Application LB in public subnets; HTTP listener; optional HTTPS (ACM) with modern TLS policy.
- Target group with `/health` health checks, sticky sessions.
- Access logs → S3.

### Security (`infra/modules/security`)
- One SG per tier, least-privilege ingress only:
  - ALB: 80/443 from `0.0.0.0/0`
  - App: 80 from ALB SG only
  - DB: 5432 from App SG only
  - Bastion (optional): 22 from admin CIDR

## Data / security boundaries
- App → DB traffic traverses private subnets only; no public endpoint.
- All storage encrypted at rest; state bucket encrypted + versioned.
- No pods/keys on instances; IAM roles grant minimal permissions.

## Failure & scaling behavior
- EC2 failures → ASG replaces; ASG capacity scales with CPU load.
- New deploys → image pulled from ECR, container restarts; ALB health-check holds traffic until `/health` returns 200.
- Multi-AZ DB (prod) survives single AZ loss.
