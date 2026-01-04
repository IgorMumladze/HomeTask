#!/usr/bin/env bash
set -euo pipefail

# Cleanup for us-east-1 stack remnants
REGION="us-east-1"
VPC_ID="vpc-07ebd4f7da61d551f"
IGW_ID="igw-0e66863081ce5b4e1"
SUBNET_PUBLIC_A="subnet-023b12646ced80757"
SUBNET_PUBLIC_B="subnet-00efa32f01dcbc9e2"
SG_ALB="sg-07ceaefda8ace4e1b"
NAT_IDS=("nat-03b90bcf4443c0989" "nat-09e426a5416bb8e23")
EIP_IDS=("eipalloc-0c3aaf65c4f52efce" "eipalloc-0610978eb8e4a8d0e")

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "Delete ALBs in VPC (if any)..."
LB_ARNS=($(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[?VpcId==`'"$VPC_ID"'`].LoadBalancerArn' --output text))
for lb in "${LB_ARNS[@]:-}"; do
  [[ -z "$lb" ]] && continue
  log "Deleting ALB $lb"
  aws elbv2 delete-load-balancer --load-balancer-arn "$lb" --region "$REGION"
done
if [[ ${#LB_ARNS[@]} -gt 0 && -n "${LB_ARNS[0]:-}" ]]; then
  log "Waiting for ALBs to delete..."
  for lb in "${LB_ARNS[@]}"; do
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$lb" --region "$REGION"
  done
fi

log "Delete NAT gateways..."
for nat in "${NAT_IDS[@]}"; do
  [[ -z "$nat" ]] && continue
  log "Deleting NAT GW $nat"
  aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region "$REGION" || true
done
if [[ ${#NAT_IDS[@]} -gt 0 && -n "${NAT_IDS[0]:-}" ]]; then
  log "Waiting for NAT GWs to delete..."
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "${NAT_IDS[@]}" --region "$REGION" || true
fi

log "Release EIPs..."
for eip in "${EIP_IDS[@]}"; do
  [[ -z "$eip" ]] && continue
  aws ec2 release-address --allocation-id "$eip" --region "$REGION" || true
done

log "Delete stray ENIs in VPC..."
while true; do
  ENI_IDS=($(aws ec2 describe-network-interfaces \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' --output text --region "$REGION"))
  if [[ ${#ENI_IDS[@]} -eq 0 || ( ${#ENI_IDS[@]} -eq 1 && -z "${ENI_IDS[0]}" ) ]]; then
    log "No ENIs remain."
    break
  fi
  for eni in "${ENI_IDS[@]}"; do
    [[ -z "$eni" ]] && continue
    log "Deleting ENI $eni"
    aws ec2 delete-network-interface --network-interface-id "$eni" --region "$REGION" || true
  done
  sleep 5
  log "Rechecking ENIs..."
done

log "Detach and delete IGW..."
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION" || true
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION" || true

log "Delete ALB security group..."
aws ec2 delete-security-group --group-id "$SG_ALB" --region "$REGION" || true

log "Delete subnets..."
aws ec2 delete-subnet --subnet-id "$SUBNET_PUBLIC_A" --region "$REGION" || true
aws ec2 delete-subnet --subnet-id "$SUBNET_PUBLIC_B" --region "$REGION" || true

log "Delete VPC..."
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" || true

log "Cleanup finished."

