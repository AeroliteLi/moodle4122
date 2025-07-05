#!/bin/bash
set -e

CLUSTER_NAME="moodleEKS"
REGION="us-east-1"
DB_INSTANCE_ID="moodledb"

# 1. 安裝 kubectl（如已安裝可略過）
if ! command -v kubectl &> /dev/null; then
  curl -LO https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
fi

# 2. 下載 GitHub 專案（如已 clone 可略過）
if [ ! -d "moodle4122" ]; then
  git clone https://github.com/AeroliteLi/moodle4122.git
fi
cd moodle4122

# 3. 取得 AWS 認證（需先 export 這三個變數於 shell 或 CI/CD）
kubectl delete secret aws-credentials --ignore-not-found
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"

# 4. 取得 kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# 5. 安裝 jq（如已安裝可略過）
if ! command -v jq &> /dev/null; then
  sudo yum install -y jq
fi

sleep 3
# 6. 查詢 RDS endpoint 與 Subnet ID
export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --region $REGION \
  --db-instance-identifier $DB_INSTANCE_ID \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

export PublicSubnet1=$(aws ec2 describe-subnets \
  --region $REGION \
  --filters "Name=tag:Name,Values=PublicSubnet1" \
  --query "Subnets[0].SubnetId" \
  --output text)

export PublicSubnet2=$(aws ec2 describe-subnets \
  --region $REGION \
  --filters "Name=tag:Name,Values=PublicSubnet2" \
  --query "Subnets[0].SubnetId" \
  --output text)

sleep 3
# 7. 部署 K8s 資源（自動帶入變數）
envsubst < moodle-svc.yaml | kubectl apply -f -
envsubst < moodle-config.yaml | kubectl apply -f -

sleep 100
envsubst < moodle-deployment.yaml | kubectl apply -f -

echo "✅ Moodle 一鍵部署完成！"
