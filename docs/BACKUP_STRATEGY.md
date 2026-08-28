# Backup Strategy

The assignment includes a working backup strategy for the most critical data (RDS) and for
infrastructure artifacts (state + logs).

## RDS PostgreSQL — automated backups (implemented)

The `database` Terraform module configures RDS backups:

```hcl
backup_retention_period = 7      # staging: 7 days / production: 30 days
backup_window           = "03:00-04:00"
maintenance_window      = "sun:04:00-sun:05:00"
deletion_protection     = false  # true in production
skip_final_snapshot     = true   # false in production
```

- Automated snapshots + **Point-in-Time Recovery (PITR)** available back to the retention window.
- `deletion_protection` prevents accidental `terraform destroy` of the DB.
- Production takes a **final snapshot** on deletion (`skip_final_snapshot = false`).

### Restore drills
- **PITR restore** to a new instance:
  ```bash
  aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier <db-id> \
    --target-db-instance-identifier <db-id>-pitr \
    --restore-time "<iso-timestamp>"
  ```
- **Snapshot restore**:
  ```bash
  aws rds describe-db-snapshots --db-instance-identifier <db-id>
  aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier <new-id> --db-snapshot-identifier <snap-id>
  ```
- Test restoring at least quarterly and document an **RPO = retention window** and **RTO ≈ restore
  time**.

## Infrastructure state (S3) — implemented
- The Terraform state bucket is **versioned** and **encrypted**, so every state change is
  recoverable (guards against accidental `destroy` of state).
- ALB access-logs bucket is also versioned.

## Application artifacts (ECR)
- Docker images are immutable-ish (each deploy tagged with the commit `sha`), enabling rollback to
  any prior image tag by re-pointing the deploy.

## Recommended production additions
1. **RDS cross-region snapshot copy / cross-region automated backups** to a DR region.
2. **S3 lifecycle** to move old snapshots/logs to `GLACIER` for cost.
3. **EC2 EBS snapshots** for any stateful EC2 volumes (or move state to managed services to avoid it).
4. A **runbook** with step-by-step restore procedures and a documented **RTO/RPO SLA**.
