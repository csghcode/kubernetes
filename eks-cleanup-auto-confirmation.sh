#!/bin/bash
REGION="eu-west-1"
DRYRUN=true   # set to false to actually delete resources

# Detect cluster name from current kubeconfig context
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')
CLUSTER_NAME=${CLUSTER_NAME##*/}  # strip prefix if present

echo "Starting cleanup in $REGION for cluster: $CLUSTER_NAME"
echo "Dry-run mode: $DRYRUN"

delete_or_preview() {
  local resource_type=$1
  local delete_cmd=$2
  local items=$3

  if [ -n "$items" ]; then
    echo "$resource_type found: $items"
    for item in $items; do
      if [ "$DRYRUN" = true ]; then
        echo "Would delete $resource_type: $item"
      else
        # Ask for confirmation before deletion
        read -p "Delete $resource_type: $item ? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          eval "$delete_cmd $item"
          echo "Deleted $resource_type: $item"
        else
          echo "Skipped $resource_type: $item"
        fi
      fi
    done
  else
    echo "No $resource_type found."
  fi
}

# 1. Unattached EBS volumes tagged with cluster
VOLUMES=$(aws ec2 describe-volumes --region $REGION \
  --filters Name=status,Values=available Name=tag:eksctl.cluster.name,Values=$CLUSTER_NAME \
  --query "Volumes[].VolumeId" --output text)
delete_or_preview "EBS Volume" "aws ec2 delete-volume --region $REGION --volume-id" "$VOLUMES"

# 2. Classic Load Balancers
CLBS=$(aws elb describe-load-balancers --region $REGION \
  --query "LoadBalancerDescriptions[].LoadBalancerName" --output text)
delete_or_preview "Classic Load Balancer" "aws elb delete-load-balancer --region $REGION --load-balancer-name" "$CLBS"

# 3. ALBs/NLBs
ALBS=$(aws elbv2 describe-load-balancers --region $REGION \
  --query "LoadBalancers[].LoadBalancerArn" --output text)
delete_or_preview "ALB/NLB" "aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn" "$ALBS"

# 4. IAM Roles
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, '$CLUSTER_NAME')].RoleName" --output text)
delete_or_preview "IAM Role" "aws iam delete-role --role-name" "$ROLES"

# 5. IAM Policies
POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, '$CLUSTER_NAME')].Arn" --output text)
delete_or_preview "IAM Policy" "aws iam delete-policy --policy-arn" "$POLICIES"

# 6. CloudWatch Log Groups
LOGS=$(aws logs describe-log-groups --region $REGION \
  --query "logGroups[?contains(logGroupName, '$CLUSTER_NAME')].logGroupName" --output text)
delete_or_preview "CloudWatch Log Group" "aws logs delete-log-group --region $REGION --log-group-name" "$LOGS"

echo "Cleanup check complete ✅"
