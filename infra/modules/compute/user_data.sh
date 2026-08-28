#!/bin/bash
set -e

REGION="${region}"
APP_IMAGE="${app_image}"
APP_LOG_GROUP="${app_log_group}"
SYSTEM_LOG_GROUP="${system_log_group}"
DD_ENABLED="${dd_enabled}"
DD_API_KEY_SECRET_ARN="${dd_api_key_secret_arn}"
DD_SITE="${dd_site}"

apt-get update -y
apt-get install -y ca-certificates curl gnupg amazon-cloudwatch-agent

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io jq unzip

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

CONFIG_JSON=$(cat <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPUUtilization"},
          {"name": "cpu_usage_user", "rename": "CPUUser"}
        ],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MemoryUtilization"}
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DiskSpaceUtilization"}
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "$SYSTEM_LOG_GROUP",
            "log_stream_name": "ec2-{instance_id}-syslog"
          }
        ]
      }
    }
  }
}
EOF
)

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
echo "$CONFIG_JSON" > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# --- Datadog agent (system metrics + logs) -------------------------------
if [ "$DD_ENABLED" = "true" ]; then
  echo "Installing Datadog agent..."
  DD_AGENT_MAJOR_VERSION=7 \
  DD_API_KEY=dummy \
  bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)" || true

  # Fetch real API key from AWS Secrets Manager using the instance role
  DD_API_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "$DD_API_KEY_SECRET_ARN" \
    --region "$REGION" \
    --query SecretString --output text \
    | jq -r .DD_API_KEY)

  cat > /etc/datadog-agent/datadog.yaml <<YAML
api_key: $${DD_API_KEY}
site: $${DD_SITE}
logs_enabled: true
process_config:
  enabled: "true"
logs_config:
  container_collect_all: true
YAML

  systemctl restart datadog-agent || true
fi

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$(echo $APP_IMAGE | cut -d/ -f1)"

docker pull "$APP_IMAGE"

DD_RUN_ARGS=()
if [ "$DD_ENABLED" = "true" ]; then
  DD_API_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "$DD_API_KEY_SECRET_ARN" \
    --region "$REGION" \
    --query SecretString --output text \
    | jq -r .DD_API_KEY)
  DD_RUN_ARGS=(
    -e DD_API_KEY="$DD_API_KEY"
    -e DD_SITE="$DD_SITE"
    -e DD_AGENT_HOST="host.docker.internal"
    -e DD_TRACE_ENABLED=true
    -e DD_LOGS_INJECTION=true
    -e DD_APM_ENABLED=true
    -e DD_DOGSTATSD_PORT=8125
    -e DD_ENV="staging"
  )
fi

docker run -d --name app \
  --add-host=host.docker.internal:host-gateway \
  --log-driver awslogs \
  --log-opt awslogs-region="$REGION" \
  --log-opt awslogs-group="$APP_LOG_GROUP" \
  --log-opt awslogs-stream-prefix="app" \
  --restart always -p 80:8080 \
  "$${DD_RUN_ARGS[@]}" \
  -e AWS_REGION="$REGION" \
  -e LOG_LEVEL=info \
  "$APP_IMAGE"

echo "Application container started successfully."
