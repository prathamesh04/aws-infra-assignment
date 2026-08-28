# Bootstrap Scripts

Scripts in this directory set up the prerequisites that must exist **before** `terraform init`:

## `bootstrap_tfstate.sh`

Creates the remote-state backend — an S3 bucket (versioned, SSE-encrypted, public-access blocked)
and a DynamoDB `terraform-locks` table used for state locking.

```bash
chmod +x bootstrap_tfstate.sh
./bootstrap_tfstate.sh cloudzone-tfstate-<account-id> ap-south-1
```

- **Args:** `BUCKET` (default `cloudzone-tfstate-952868634839`), `REGION` (default `ap-south-1`).
- Idempotent — safe to re-run.

After running, confirm the bucket name matches what's declared in
`infra/environments/<env>/backend.tf`, then initialize:

```bash
cd infra/environments/staging
terraform init -reconfigure
```
