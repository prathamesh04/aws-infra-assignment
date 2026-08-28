# Datadog Monitoring & Logging

The JD asks for **infrastructure metrics, application metrics (request rate / error rate /
latency), database metrics, centralized logging, and two dashboards**. Since your AWS account is
already integrated with **Datadog**, we implement observability in Datadog (with CloudWatch kept as
the AWS-native baseline).

## How the pieces map to the JD

| JD requirement | Datadog mechanism |
|---|---|
| Infra metrics (CPU / memory / disk) | **Datadog Agent** on EC2 (`system.cpu`, `system.mem`, `system.disk`) + **AWS integration** (auto-discovered EC2) |
| App metrics (request rate, error rate, latency) | **dd-trace** custom StatsD metrics (`http.request.count`, `http.request.latency`, `http.request.errors`) + **APM** traces |
| Database metrics | **AWS RDS integration** (`aws.rds.*` metrics via CloudWatch) |
| Centralized logs (app/system/access) | **Datadog Agent** with `logs_enabled: true` + `container_collect_all` |
| Two meaningful dashboards | `dashboard-infrastructure.json` and `dashboard-application.json` |

## Setup

### 1. Store API key in AWS Secrets Manager (already done for you)
```bash
aws secretsmanager create-secret \
  --name "datadog/app" \
  --secret-string '{"DD_API_KEY":"<your key>","DD_SITE":"datadoghq.com"}' \
  --region ap-south-1
# → arn:aws:secretsmanager:ap-south-1:952868634839:secret:datadog/app-OKaryO
```

### 2. Enable Datadog in your environment tfvars
```hcl
dd_enabled            = true
dd_site               = "datadoghq.com"
dd_api_key_secret_arn = "arn:aws:secretsmanager:ap-south-1:952868634839:secret:datadog/app-OKaryO"
```

On apply, EC2 user-data will:
- Install the **Datadog agent** and point it at your key/site (metrics + logs).
- Run the app container with `DD_API_KEY` / `DD_SITE` / `DD_TRACE_ENABLED` and add the
  `host.docker.internal` host mapping so the container reaches the agent for **APM + StatsD**.

### 3. Connect the AWS account integration (one-time, in UI)
In Datadog: `Integrations → AWS` → install. Creates a cross-account IAM role so Datadog ingests
CloudWatch metrics (EC2, RDS, ELB) and CloudTrail. Auto-installs the EC2/ELB/RDS dashboards.

### 4. Import the dashboards
Datadog → Dashboards → **New Dashboard → Import dashboard JSON**, then load:
- `monitoring/datadog/dashboard-infrastructure.json`
- `monitoring/datadog/dashboard-application.json`

> The application dashboard relies on `http.request.*` metrics emitted by the app when
> `DD_TRACE_ENABLED` + the agent are live, plus `trace_stream` from APM.

### Alternative: Dashboard-as-code (Terraform)
See `datadog.tf.example` for provisioning these dashboards with the Datadog Terraform provider,
so they version with your infra.

## Metrics emitted by the app (`app/src/server.js`)
Custom StatsD metrics (via `tracer.dogstatsd()`), tagged with `env` & `service`:
- `http.request.count` (counter) — request rate
- `http.request.latency` (distribution) — p50/p95 latency
- `http.request.errors` (counter) — error rate
- Plus full **APM** traces via dd-trace HTTP/Express integration.

The metric recording is wrapped in try/catch and initialises a no-op when Datadog isn't configured,
so the app runs fine with or without it (tests pass independently).

## Alerts (in addition to CloudWatch/SNS)
Datadog **Monitors** can be created for request error rate, p95 latency, and disk usage. Example
monitor query: `avg(last_5m):(sum:http.request.errors{*}.as_rate() / sum:http.request.count{*}.as_rate()) * 100 > 2`.
