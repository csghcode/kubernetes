#!/bin/bash
REGION="eu-west-1"

echo "Checking for leftover resources in $REGION..."

# 1. EC2 Instances (should be none)
echo "EC2 Instances:"
aws ec2 describe-instances --region $REGION --query "Reservations[].Instances[].InstanceId" --output text

# 2. Load Balancers (Classic ELB + ALB/NLB)
echo "Classic Load Balancers:"
aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[].LoadBalancerName" --output text

echo "Application/Network Load Balancers:"
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].LoadBalancerName" --output text

# 3. EBS Volumes (look for unattached volumes)
echo "Unattached EBS Volumes:"
aws ec2 describe-volumes --region $REGION --filters Name=status,Values=available --query "Volumes[].VolumeId" --output text

# 4. IAM Roles (look for eks-related roles)
echo "IAM Roles (eks-related):"
aws iam list-roles --query "Roles[?contains(RoleName, 'eks')].RoleName" --output text

# 5. IAM Policies (look for eks-related policies)
echo "IAM Policies (eks-related):"
aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'eks')].PolicyName" --output text

# 6. CloudWatch Log Groups (look for eks-related logs)
echo "CloudWatch Log Groups (eks-related):"
aws logs describe-log-groups --region $REGION --query "logGroups[?contains(logGroupName, 'eks')].logGroupName" --output text

echo "Cleanup check complete."
