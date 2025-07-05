#!/bin/bash
set -e

CLUSTER_NAME="moodleEKS"
REGION="us-east-1"
DB_INSTANCE_ID="moodledb"

kubectl delete secret aws-credentials
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  --from-literal=aws_session_token=$AWS_SESSION_TOKEN


aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
sudo yum install -y jq
curl -LO "https://dl.k8s.io/release/v1.32/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

sleep 3

export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --region us-east-1 \
  --db-instance-identifier moodledb \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

export PublicSubnet1=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=PublicSubnet1" \
  --query "Subnets[0].SubnetId" \
  --output text)

export PublicSubnet2=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=PublicSubnet2" \
  --query "Subnets[0].SubnetId" \
  --output text)
  
sleep 3
  
envsubst < moodle-svc.yaml | kubectl apply -f -
envsubst < moodle-config.yaml | kubectl apply -f -

sleep 100

envsubst < moodle-deployment.yaml | kubectl apply -f -

 