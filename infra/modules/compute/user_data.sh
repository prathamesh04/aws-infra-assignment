#!/bin/bash
set -e

REGION="${region}"
APP_IMAGE="${app_image}"
APP_LOG_GROUP="${app_log_group}"
SYSTEM_LOG_GROUP="${system_log_group}"

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

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$(echo $APP_IMAGE | cut -d/ -f1)"

docker pull "$APP_IMAGE"

docker run -d --name app \
  --log-driver awslogs \
  --log-opt awslogs-region="$REGION" \
  --log-opt awslogs-group="$APP_LOG_GROUP" \
  --log-opt awslogs-stream-prefix="app" \
  --restart always -p 80:8080 \
  -e AWS_REGION="$REGION" \
  -e LOG_LEVEL=info \
  "$APP_IMAGE"

echo "Application container started successfully."
