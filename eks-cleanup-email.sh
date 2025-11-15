#!/bin/bash
REGION="eu-west-1"
DRYRUN=true   # set to false to actually delete resources
LOGFILE="eks-cleanup.log"
EMAIL_FROM="your-verified-sender@example.com"
EMAIL_TO="your-email@example.com"
EMAIL_SUBJECT="EKS Cleanup Report for Cluster"

# Detect cluster name from current kubeconfig context
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')
CLUSTER_NAME=${CLUSTER_NAME##*/}  # strip prefix if present

# Function to log with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}

log "Starting cleanup in $REGION for cluster: $CLUSTER_NAME"
log "Dry-run mode: $DRYRUN"

# Counters for summary
DELETED=0
SKIPPED=0
WOULD_DELETE=0

delete_or_preview() {
  local resource_type=$1
  local delete_cmd=$2
  local items=$3

  if [ -n "$items" ]; then
    log "$resource_type found: $items"
    for item in $items; do
      if [ "$DRYRUN" = true ]; then
        log "Would delete $resource_type: $item"
        WOULD_DELETE=$((WOULD_DELETE+1))
      else
        read -p "Delete $resource_type: $item ? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          eval "$delete_cmd $item"
          log "Deleted $resource_type: $item"
          DELETED=$((DELETED+1))
        else
          log "Skipped $resource_type: $item"
          SKIPPED=$((SKIPPED+1))
        fi
      fi
    done
  else
    log "No $resource_type found."
  fi
}

# Example cleanup checks (EBS volumes shown, repeat for other resources)
VOLUMES=$(aws ec2 describe-volumes --region $REGION \
  --filters Name=status,Values=available Name=tag:eksctl.cluster.name,Values=$CLUSTER_NAME \
  --query "Volumes[].VolumeId" --output text)
delete_or_preview "EBS Volume" "aws ec2 delete-volume --region $REGION --volume-id" "$VOLUMES"

# Final summary
log "-----------------------------------"
log "Cleanup Summary:"
log "Would delete (dry-run): $WOULD_DELETE"
log "Deleted: $DELETED"
log "Skipped: $SKIPPED"
log "-----------------------------------"
log "Cleanup check complete ✅"

# Email the log file via AWS SES
if [ "$DRYRUN" = false ]; then
  log "Sending cleanup report via SES..."
  aws ses send-email \
    --region $REGION \
    --from "$EMAIL_FROM" \
    --destination "ToAddresses=$EMAIL_TO" \
    --message "Subject={Data=$EMAIL_SUBJECT},Body={Text={Data=$(cat $LOGFILE)}}"
fi
