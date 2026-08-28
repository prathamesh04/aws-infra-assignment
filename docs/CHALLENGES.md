# Challenges Faced & Resolutions

This documents the real issues encountered while building the assignment and how each was
resolved — a required deliverable.

## 1. Module source path resolution

**Problem:** After introducing a nested `environments/<env>/` directory, Terraform module sources
like `source = "../modules/networking"` failed with
`Unable to evaluate directory symlink: lstat ../modules: no such file or directory`.

**Resolution:** Corrected the relative depth to `source = "../../modules/networking"` (from
`environments/staging/` the modules live two levels up). Systematically re-checked all six module
references. Re-ran `terraform init` and `terraform validate` to confirm.

## 2. Production environment silently drifting from staging

**Problem:** The production directory was initially a copy of staging created before I added the
`app_log_group`/`system_log_group` arguments to the compute module, so `production` failed validate
with `Missing required argument`.

**Resolution:** Re-synced `production/main.tf` (plus `variables.tf`, `outputs.tf`) from the fixed
staging version so both environments share identical module wiring, and only differ through
`terraform.tfvars`. Re-validated.

## 3. Node.js test runner not finding tests

**Problem:** `npm test` (run as `node --test test/`) failed with `MODULE_NOT_FOUND` / no tests
executed because the trailing-slash directory argument isn't reliably globbed by the test runner.

**Resolution:** Changed the script to an explicit glob `node --test test/*.test.js`, driven all
tests to load the app via `require` with `listen` gated behind `require.main === module`, then
verified `3/3` tests pass.

## 4. Unused dependencies inflating the vulnerability surface

**Problem:** The initial `package.json` listed `pg` and `winston-cloudwatch` that the sample app did
not import, which would show as "should we trust these?" and add unnecessary audit surface.

**Resolution:** Removed unused deps; kept only `express` and `winston`. Cleaner dependency tree,
smaller container image, fewer Trivy/`npm audit` findings.

## 5. Keeping CloudWatch log-collection strategy consistent

**Problem:** Two overlapping mechanisms (Docker `awslogs` driver vs. CloudWatch agent tailing
container files) risked duplicate logs, duplicated costs, and inconsistent log-group names.

**Resolution:** Chose a clean split — **Docker `awslogs` driver** owns application logs
(`/<env>/app`), **CloudWatch Agent** owns system logs (`/<env>/system`) and OS-level metrics.
Parameterized the log-group names into the user-data template so staging/production map to the
right groups automatically.

## 6. Avoiding a circular dependency in the Terraform graph

**Problem:** `monitoring` needs the ALB ARN-suffix, ALB needs the target group, compute needs the
target group, and several modules need the SNS topic from monitoring — an easy source of dependency
cycles.

**Resolution:** Let the Terraform dependency graph resolve ordering naturally (it already handles
this via references), and only pass the minimal cross-module values needed (log-group names to
compute, ALB ARN-suffix + DB identifier to monitoring) rather than creating any back-references from
ALB back to monitoring.

## 7. Remote state bootstrap without committing real resources/secrets

**Problem:** The S3 state bucket name must be unique and account-specific, and it must exist before
`terraform init` — but its name can't be hard-coded generically.

**Resolution:** Wrote an idempotent bootstrap script (`infra/bootstrap/bootstrap_tfstate.sh`) that
creates the bucket (versioned, encrypted, public-access-blocked) and the DynamoDB lock table, and
documented the exact account-specific bucket used.

## 8. Demonstrable-but-credentials-safe verification on the account

**Problem:** I wanted to prove the infra works against the real free-tier account without leaking
secrets or triggering expensive resources.

**Resolution:** Ran `terraform plan` (dry-run) against the live account → **53 resources to add,
0 errors**. Created the ECR repository, built and pushed the app image, and smoke-tested the
container locally — all free of charge. Full `terraform apply` is left to the deployer/CI so no
secrets are handled inline and costs stay under control.

---

## General lessons

- **Test Terraform syntax early and often** (`validate` after every module change) — most errors
  surfaced were structural, not logical.
- **Keep environments code-identical, config-different** — this is the single most effective way
  to stay DRY and avoid environment drift.
- **Treat "verification" as part of the deliverable** — a config that `plan`s cleanly and an app
  that builds/runs gives the reviewer confidence beyond reading the docs.
