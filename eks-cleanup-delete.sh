#!/bin/bash
REGION="eu-west-1"

echo "Starting cleanup in $REGION..."

# 1. Delete unattached EBS volumes
VOLUMES=$(aws ec2 describe-volumes --region $REGION --filters Name=status,Values=available --query "Volumes[].VolumeId" --output text)
if [ -n "$VOLUMES" ]; then
  echo "Deleting EBS volumes: $VOLUMES"
  for vol in $VOLUMES; do
    aws ec2 delete-volume --region $REGION --volume-id $vol
  done
else
  echo "No unattached EBS volumes found."
fi

# 2. Delete Classic Load Balancers
CLBS=$(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[].LoadBalancerName" --output text)
if [ -n "$CLBS" ]; then
  echo "Deleting Classic Load Balancers: $CLBS"
  for lb in $CLBS; do
    aws elb delete-load-balancer --region $REGION --load-balancer-name $lb
  done
else
  echo "No Classic Load Balancers found."
fi

# 3. Delete Application/Network Load Balancers
ALBS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].LoadBalancerArn" --output text)
if [ -n "$ALBS" ]; then
  echo "Deleting ALBs/NLBs: $ALBS"
  for lb in $ALBS; do
    aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn $lb
  done
else
  echo "No ALBs/NLBs found."
fi

# 4. Delete IAM Roles related to EKS
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eks')].RoleName" --output text)
if [ -n "$ROLES" ]; then
  echo "Deleting IAM Roles: $ROLES"
  for role in $ROLES; do
    aws iam delete-role --role-name $role
  done
else
  echo "No EKS-related IAM roles found."
fi

# 5. Delete IAM Policies related to EKS
POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'eks')].Arn" --output text)
if [ -n "$POLICIES" ]; then
  echo "Deleting IAM Policies: $POLICIES"
  for policy in $POLICIES; do
    aws iam delete-policy --policy-arn $policy
  done
else
  echo "No EKS-related IAM policies found."
fi

# 6. Delete CloudWatch Log Groups related to EKS
LOGS=$(aws logs describe-log-groups --region $REGION --query "logGroups[?contains(logGroupName, 'eks')].logGroupName" --output text)
if [ -n "$LOGS" ]; then
  echo "Deleting CloudWatch Log Groups: $LOGS"
  for log in $LOGS; do
    aws logs delete-log-group --region $REGION --log-group-name $log
  done
else
  echo "No EKS-related CloudWatch log groups found."
fi

echo "Cleanup complete ✅"
