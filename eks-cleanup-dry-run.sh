#!/bin/bash
REGION="eu-west-1"
DRYRUN=true   # set to false to actually delete resources

echo "Starting cleanup in $REGION..."
echo "Dry-run mode: $DRYRUN"

# Function to delete or preview
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
        eval "$delete_cmd $item"
        echo "Deleted $resource_type: $item"
      fi
    done
  else
    echo "No $resource_type found."
  fi
}

# 1. Unattached EBS volumes
VOLUMES=$(aws ec2 describe-volumes --region $REGION --filters Name=status,Values=available --query "Volumes[].VolumeId" --output text)
delete_or_preview "EBS Volume" "aws ec2 delete-volume --region $REGION --volume-id" "$VOLUMES"

# 2. Classic Load Balancers
CLBS=$(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[].LoadBalancerName" --output text)
delete_or_preview "Classic Load Balancer" "aws elb delete-load-balancer --region $REGION --load-balancer-name" "$CLBS"

# 3. ALBs/NLBs
ALBS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].LoadBalancerArn" --output text)
delete_or_preview "ALB/NLB" "aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn" "$ALBS"

# 4. IAM Roles
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eks')].RoleName" --output text)
delete_or_preview "IAM Role" "aws iam delete-role --role-name" "$ROLES"

# 5. IAM Policies
POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'eks')].Arn" --output text)
delete_or_preview "IAM Policy" "aws iam delete-policy --policy-arn" "$POLICIES"

# 6. CloudWatch Log Groups
LOGS=$(aws logs describe-log-groups --region $REGION --query "logGroups[?contains(logGroupName, 'eks')].logGroupName" --output text)
delete_or_preview "CloudWatch Log Group" "aws logs delete-log-group --region $REGION --log-group-name" "$LOGS"

echo "Cleanup check complete ✅"
