#!/bin/bash
# Bootstrap: app-first, monitoring second. App startup must NEVER be blocked
# by a monitoring agent failure, so monitoring blocks are guarded.
set -e

REGION="${region}"
APP_IMAGE="${app_image}"
APP_LOG_GROUP="${app_log_group}"
SYSTEM_LOG_GROUP="${system_log_group}"
DD_ENABLED="${dd_enabled}"
DD_API_KEY_SECRET_ARN="${dd_api_key_secret_arn}"
DD_SITE="${dd_site}"

# ---------------------------------------------------------------------------
# 1. Base packages + Docker
# ---------------------------------------------------------------------------
apt-get update -y
apt-get install -y ca-certificates curl gnupg unzip jq

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

# ---------------------------------------------------------------------------
# 2. AWS CLI v2 (needed for ECR login + Secrets Manager)
# ---------------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  cd /tmp
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -qo awscliv2.zip
  ./aws/install --update 2>/dev/null || ./aws/install
  export PATH="/usr/local/bin:$PATH"
  cd /
fi

# ---------------------------------------------------------------------------
# 3. App container (CRITICAL - must succeed)
# ---------------------------------------------------------------------------
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$(echo "$APP_IMAGE" | cut -d/ -f1)"

docker pull "$APP_IMAGE"

DD_RUN_ARGS=()
if [ "$DD_ENABLED" = "true" ]; then
  DD_API_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "$DD_API_KEY_SECRET_ARN" \
    --region "$REGION" \
    --query SecretString --output text | jq -r '.DD_API_KEY' 2>/dev/null || true)
  DD_RUN_ARGS=(
    -e DD_API_KEY="$DD_API_KEY"
    -e DD_SITE="$DD_SITE"
    -e DD_AGENT_HOST="host.docker.internal"
    -e DD_TRACE_ENABLED="true"
    -e DD_LOGS_INJECTION="true"
    -e DD_APM_ENABLED="true"
    -e DD_DOGSTATSD_PORT="8125"
    -e DD_ENV="staging"
  )
fi

docker run -d --name app \
  --add-host=host.docker.internal:host-gateway \
  --restart always -p 80:8080 \
  "$${DD_RUN_ARGS[@]}" \
  -e AWS_REGION="$REGION" \
  -e LOG_LEVEL=info \
  "$APP_IMAGE"

echo "App container started: $(docker ps --format '{{.Names}} {{.Status}}' | grep '^app')"

# ---------------------------------------------------------------------------
# 3b. Swap space (free-tier 1GiB instances OOM-kill large dpkg installs like
#      the Datadog agent's embedded bundle, so give the box room)
# ---------------------------------------------------------------------------
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null 2>&1
  swapon /swapfile 2>/dev/null || true
  echo '/swapfile none swap sw 0 0' >> /etc/fstab 2>/dev/null || true
  sysctl vm.swappiness=60 >/dev/null 2>&1 || true
  echo "swapfile created: $(free -h | grep -i swap | awk '{print $2}')"
fi

# ---------------------------------------------------------------------------
# 4. CloudWatch agent (system metrics + syslog) - non-blocking
# ---------------------------------------------------------------------------
set +e
(
  if ! command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    curl -fsSL -o /tmp/cw-agent.deb \
      "https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
    dpkg -i /tmp/cw-agent.deb
  fi

  cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWJSON
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": { "measurement": [
        {"name":"cpu_usage_idle","rename":"CPUUtilization"},
        {"name":"cpu_usage_user","rename":"CPUUser"} ], "metrics_collection_interval": 60 },
      "mem": { "measurement": [
        {"name":"mem_used_percent","rename":"MemoryUtilization"} ], "metrics_collection_interval": 60 },
      "disk": { "measurement": [
        {"name":"used_percent","rename":"DiskSpaceUtilization"} ], "metrics_collection_interval": 60 }
    }
  },
  "logs": { "logs_collected": { "files": { "collect_list": [
    { "file_path": "/var/log/syslog", "log_group_name": "$SYSTEM_LOG_GROUP", "log_stream_name": "ec2-{instance_id}-syslog" }
  ] } } }
}
CWJSON

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
  echo "CloudWatch agent configured"
) || echo "WARN: CloudWatch agent setup skipped"

# ---------------------------------------------------------------------------
# 5. Datadog agent (system metrics + logs + APM endpoint) - non-blocking
# ---------------------------------------------------------------------------
if [ "$DD_ENABLED" = "true" ]; then
  (
    DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=dummy \
      bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)" || true

    DD_API_KEY=$(aws secretsmanager get-secret-value \
      --secret-id "$DD_API_KEY_SECRET_ARN" \
      --region "$REGION" --query SecretString --output text | jq -r '.DD_API_KEY' 2>/dev/null)

    mkdir -p /etc/datadog-agent
    cat > /etc/datadog-agent/datadog.yaml <<YAML
api_key: $${DD_API_KEY}
site: $${DD_SITE}
logs_enabled: true
process_config:
  enabled: "true"
logs_config:
  container_collect_all: true
apm_config:
  enabled: true
YAML

    systemctl restart datadog-agent 2>/dev/null || true
    echo "Datadog agent configured"
  ) || echo "WARN: Datadog agent setup skipped"
fi

echo "User-data bootstrap complete."
